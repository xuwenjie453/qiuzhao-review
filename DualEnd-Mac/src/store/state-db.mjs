// QuestionGraph 双端 Store —— 仅该模块可触达 SQLite。
// 冻结契约: Mac canonical; body immutable (API + DB trigger 双保险);
// one center per graph; one active round 全局; command dedup; sync_journal server_seq 单调。
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, existsSync } from 'node:fs';
import { dirname } from 'node:path';
import { nowIso } from '../util.mjs';

export const SCHEMA_VERSION = 1;

export const DDL = `
CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS graphs(
  graph_id TEXT PRIMARY KEY,
  question_key TEXT NOT NULL UNIQUE,
  question_source TEXT NOT NULL CHECK(question_source IN ('QUESTION_BANK','REVIEW_CAPSULE')),
  source_id TEXT NOT NULL,
  probe_key TEXT,
  graph_revision INTEGER NOT NULL DEFAULT 1,
  center_node_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS rounds(
  round_id TEXT PRIMARY KEY,
  graph_id TEXT NOT NULL REFERENCES graphs(graph_id),
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','CLOSED','INTERRUPTED')),
  opened_at TEXT NOT NULL,
  closed_at TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS one_active_round ON rounds(status) WHERE status='ACTIVE';
CREATE TABLE IF NOT EXISTS nodes(
  node_id TEXT PRIMARY KEY,
  graph_id TEXT NOT NULL REFERENCES graphs(graph_id),
  kind TEXT NOT NULL CHECK(kind IN ('CENTER','EXPLANATION','TEMPORARY')),
  title TEXT NOT NULL,
  body_markdown TEXT NOT NULL,
  body_sha256 TEXT NOT NULL,
  round_id TEXT REFERENCES rounds(round_id),
  node_revision INTEGER NOT NULL DEFAULT 1,
  origin_turn_ref TEXT,
  created_at TEXT NOT NULL,
  deleted_at TEXT,
  expired_at TEXT,
  CHECK((kind='TEMPORARY' AND round_id IS NOT NULL) OR (kind!='TEMPORARY' AND round_id IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS one_center_per_graph
  ON nodes(graph_id) WHERE kind='CENTER' AND deleted_at IS NULL;
CREATE TABLE IF NOT EXISTS layouts(
  node_id TEXT PRIMARY KEY REFERENCES nodes(node_id),
  x_norm REAL NOT NULL,
  y_norm REAL NOT NULL,
  layout_revision INTEGER NOT NULL DEFAULT 1,
  pinned_by_user INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS ink(
  node_id TEXT PRIMARY KEY REFERENCES nodes(node_id),
  ink_revision INTEGER NOT NULL,
  format TEXT NOT NULL,
  blob BLOB NOT NULL,
  blob_sha256 TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS command_dedup(
  command_id TEXT PRIMARY KEY,
  result_json TEXT NOT NULL,
  committed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sync_journal(
  server_seq INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL,
  graph_id TEXT,
  payload_json TEXT NOT NULL,
  committed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS device_state(
  device_id TEXT PRIMARY KEY,
  last_seen_at TEXT NOT NULL,
  last_acked_server_seq INTEGER NOT NULL DEFAULT 0
);
CREATE TRIGGER IF NOT EXISTS node_body_immutable
BEFORE UPDATE OF body_markdown, body_sha256 ON nodes
BEGIN
  SELECT RAISE(ABORT, 'NODE_BODY_IMMUTABLE');
END;
`;

const TX = Symbol('tx');

// 语义身份的 canonical 序列化: 键序无关, 重放比较不受对象构造顺序影响。
function stableStringify(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  const keys = Object.keys(value).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(value[k])}`).join(',')}}`;
}

export class StateDb {
  constructor(dbPath) {
    mkdirSync(dirname(dbPath), { recursive: true });
    this.path = dbPath;
    this.db = new DatabaseSync(dbPath);
    this.db.exec('PRAGMA foreign_keys = ON');
    this.db.exec('PRAGMA journal_mode = WAL');
    this.db.exec(DDL);
    const m = this.db.prepare('SELECT value FROM meta WHERE key=?');
    if (!m.get('schema_version')) {
      this.db.prepare('INSERT INTO meta(key,value) VALUES (?,?)').run('schema_version', String(SCHEMA_VERSION));
      this.db.prepare('INSERT INTO meta(key,value) VALUES (?,?)').run('created_at', nowIso());
    }
  }

  integrity() {
    const ic = this.db.prepare('PRAGMA integrity_check').get();
    const fk = this.db.prepare('PRAGMA foreign_key_check').all();
    return { integrity: ic && ic.integrity_check, fk_violations: fk.length };
  }

  // 事务入口: withTx(fn) 内 fn(tx) 使用 tx.prepare; 任何异常回滚
  withTx(fn) {
    if (this[TX]) return fn(this[TX]);       // 嵌套事务复用
    this.db.exec('BEGIN IMMEDIATE');
    const tx = { db: this, prepare: (s) => this.db.prepare(s), exec: (s) => this.db.exec(s) };
    this[TX] = tx;
    try {
      const r = fn(tx);
      this.db.exec('COMMIT');
      return r;
    } catch (e) {
      try { this.db.exec('ROLLBACK'); } catch { /* ignore */ }
      throw e;
    } finally {
      this[TX] = undefined;
    }
  }

  prepare(sql) { return this.db.prepare(sql); }
  exec(sql) { this.db.exec(sql); }

  // ---- journal (durable-before-emit 的依据: 先落 journal 后广播/ACK) ----
  // 两类语义(修复 2026-09-13, dual_end_repair_prompt_pack 02_MAC_FIX):
  // journalUnique     —— 服务端自产生事件(WELCOME/SNAPSHOT/PATCH, UUID message_id)。
  //                      重复仍是 bug, 保持裸 INSERT 的严格性。
  // journalReplayable —— 客户端可重放消息(CLIENT_COMMAND/INK_PUT, at-least-once)。
  //                      语义身份一致的重放复用原 server_seq 供补 ACK;
  //                      不一致抛 MESSAGE_ID_REUSE_CONFLICT(协议违规, 必须拒绝)。
  journalUnique(message_id, kind, graphId, payloadObj) {
    const r = this.db.prepare(
      'INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at) VALUES (?,?,?,?,?)'
    ).run(message_id, kind, graphId ?? null, stableStringify(payloadObj), nowIso());
    return { serverSeq: Number(r.lastInsertRowid), replay: false };
  }

  // Backwards-compatible raw journal API for non-replayable server events.
  journal(message_id, kind, graphId, payloadObj) {
    return this.journalUnique(message_id, kind, graphId, payloadObj).serverSeq;
  }

  // 查询可重放消息。返回 null 表示尚不存在；已存在时严格校验语义。
  // 该查询必须在执行业务副作用前调用，避免 message_id 冲突先落成 CAS/业务错误。
  findReplayable(message_id, kind, graphId, semantic) {
    const row = this.db.prepare(
      'SELECT server_seq, kind, graph_id, payload_json FROM sync_journal WHERE message_id=?'
    ).get(message_id);
    if (!row) return null;
    let stored;
    try { stored = JSON.parse(row.payload_json); } catch { stored = row.payload_json; }
    const storedSemantic = stored && typeof stored === 'object' && stored._semantic
      ? stored._semantic : stored;
    const exact = row.kind === kind
      && (row.graph_id ?? null) === (graphId ?? null)
      && stableStringify(storedSemantic) === stableStringify(semantic);
    // 兼容修复前已存在的 journal 行：旧行没有请求 payload，只能用其可用身份字段校验。
    const legacy = !stored?._semantic && row.kind === kind
      && (row.graph_id ?? null) === (graphId ?? null)
      && stored && semantic
      && (kind === 'INK_PUT'
        ? (stored.node_id === semantic.node_id && stored.ink_revision === semantic.ink_revision)
        : stored.command_id === semantic.command_id);
    if (!exact && !legacy) {
      const e = new Error(
        `MESSAGE_ID_REUSE_CONFLICT message_id=${message_id} kind=${kind} `
        + `command_id=${semantic?.command_id ?? ''} graph_id=${graphId ?? ''}`
      );
      e.code = 'MESSAGE_ID_REUSE_CONFLICT';
      throw e;
    }
    return { serverSeq: Number(row.server_seq), replay: true, payload: stored, legacy };
  }

  journalReplayable(message_id, kind, graphId, payloadObj, semantic = payloadObj) {
    const storedPayload = { ...payloadObj, _semantic: semantic };
    const canonical = stableStringify(storedPayload);
    const r = this.db.prepare(
      `INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at)
       VALUES (?,?,?,?,?)
       ON CONFLICT(message_id) DO NOTHING`
    ).run(message_id, kind, graphId ?? null, canonical, nowIso());
    if (Number(r.changes) === 1) return { serverSeq: Number(r.lastInsertRowid), replay: false };
    return this.findReplayable(message_id, kind, graphId, semantic);
  }

  dedupGet(commandId) {
    const r = this.db.prepare('SELECT result_json FROM command_dedup WHERE command_id=?').get(commandId);
    return r ? JSON.parse(r.result_json) : null;
  }
  dedupPut(commandId, resultJson) {
    this.db.prepare('INSERT INTO command_dedup(command_id,result_json,committed_at) VALUES (?,?,?)')
      .run(commandId, JSON.stringify(resultJson), nowIso());
  }

  close() { try { this.db.close(); } catch { /* noop */ } }
}
