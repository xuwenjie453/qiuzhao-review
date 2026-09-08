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
  journal(message_id, kind, graphId, payloadObj) {
    const r = this.db.prepare(
      'INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at) VALUES (?,?,?,?,?)'
    ).run(message_id, kind, graphId ?? null, JSON.stringify(payloadObj), nowIso());
    return Number(r.lastInsertRowid);   // server_seq
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
