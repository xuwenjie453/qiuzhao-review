// QuestionGraph 双端 Store —— 仅该模块可触达 SQLite。
// 冻结契约: Mac canonical; body immutable (API + DB trigger 双保险);
// one center per graph; one active round 全局; command dedup; sync_journal server_seq 单调。
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, existsSync } from 'node:fs';
import { dirname } from 'node:path';
import { nowIso } from '../util.mjs';
import { LEGACY_WORLD_HEIGHT, LEGACY_WORLD_WIDTH } from '../graph/world-layout.mjs';

export const SCHEMA_VERSION = 5;

export const DDL = `
CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS graphs(
  graph_id TEXT PRIMARY KEY,
  question_key TEXT NOT NULL UNIQUE,
  question_source TEXT NOT NULL CHECK(question_source IN ('QUESTION_BANK','REVIEW_CAPSULE','USER_AUTHORED')),
  source_id TEXT NOT NULL,
  probe_key TEXT,
  graph_revision INTEGER NOT NULL DEFAULT 1,
  center_node_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_graphs_user_source_id
  ON graphs(source_id) WHERE question_source='USER_AUTHORED';
CREATE TABLE IF NOT EXISTS graph_inheritance(
  child_graph_id TEXT NOT NULL REFERENCES graphs(graph_id) ON DELETE CASCADE,
  parent_graph_id TEXT NOT NULL REFERENCES graphs(graph_id) ON DELETE CASCADE,
  inheritance_kind TEXT NOT NULL DEFAULT 'SHARED_EXPLANATIONS'
    CHECK(inheritance_kind IN ('SHARED_EXPLANATIONS')),
  created_at TEXT NOT NULL,
  PRIMARY KEY(child_graph_id, parent_graph_id),
  CHECK(child_graph_id <> parent_graph_id)
);
CREATE INDEX IF NOT EXISTS idx_graph_inheritance_parent ON graph_inheritance(parent_graph_id);
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
  parent_node_id TEXT REFERENCES nodes(node_id),
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
  x_world REAL NOT NULL,
  y_world REAL NOT NULL,
  -- 保留可空镜像列，使 v4 原地升级库的 NOT NULL 历史列也能继续写入。
  -- canonical 代码从不读取它们。
  x_norm REAL,
  y_norm REAL,
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
    this._migrate();
    // 旧 v3 库在 migration 前没有 parent column，故不能放进上面的通用 DDL。
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_nodes_parent_node_id ON nodes(parent_node_id)');
  }

  _migrate() {
    const row = this.db.prepare('SELECT value FROM meta WHERE key=?').get('schema_version');
    if (!row) {
      this.db.prepare('INSERT INTO meta(key,value) VALUES (?,?)').run('schema_version', String(SCHEMA_VERSION));
      this.db.prepare('INSERT INTO meta(key,value) VALUES (?,?)').run('created_at', nowIso());
      return;
    }
    let current = Number(row.value);
    if (!Number.isInteger(current) || current > SCHEMA_VERSION) {
      throw new Error(`UNSUPPORTED_SCHEMA_VERSION ${row.value}`);
    }
    if (current < 2) {
      this.db.exec('BEGIN IMMEDIATE');
      try {
        this.db.exec(`CREATE TABLE IF NOT EXISTS graph_inheritance(
          child_graph_id TEXT NOT NULL REFERENCES graphs(graph_id) ON DELETE CASCADE,
          parent_graph_id TEXT NOT NULL REFERENCES graphs(graph_id) ON DELETE CASCADE,
          inheritance_kind TEXT NOT NULL DEFAULT 'SHARED_EXPLANATIONS'
            CHECK(inheritance_kind IN ('SHARED_EXPLANATIONS')),
          created_at TEXT NOT NULL,
          PRIMARY KEY(child_graph_id,parent_graph_id),
          CHECK(child_graph_id <> parent_graph_id)
        );`);
        this.db.exec('CREATE INDEX IF NOT EXISTS idx_graph_inheritance_parent ON graph_inheritance(parent_graph_id)');
        this.db.prepare('UPDATE meta SET value=? WHERE key=?').run('2', 'schema_version');
        this.db.exec('COMMIT');
        current = 2;
      } catch (e) {
        try { this.db.exec('ROLLBACK'); } catch {}
        throw e;
      }
    }
    if (current < 3) {
      // SQLite 不能直接修改 CHECK；在关闭外键检查后原位重建父表。
      // graph_id/center_node_id 原值全部保留，因此 rounds/nodes/inheritance 引用保持有效。
      this.db.exec('PRAGMA foreign_keys = OFF');
      this.db.exec('BEGIN IMMEDIATE');
      try {
        this.db.exec(`CREATE TABLE graphs_v3(
          graph_id TEXT PRIMARY KEY,
          question_key TEXT NOT NULL UNIQUE,
          question_source TEXT NOT NULL CHECK(question_source IN ('QUESTION_BANK','REVIEW_CAPSULE','USER_AUTHORED')),
          source_id TEXT NOT NULL,
          probe_key TEXT,
          graph_revision INTEGER NOT NULL DEFAULT 1,
          center_node_id TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );`);
        this.db.exec(`INSERT INTO graphs_v3(
          graph_id,question_key,question_source,source_id,probe_key,graph_revision,center_node_id,created_at,updated_at
        ) SELECT graph_id,question_key,question_source,source_id,probe_key,graph_revision,center_node_id,created_at,updated_at FROM graphs;`);
        this.db.exec('DROP TABLE graphs');
        this.db.exec('ALTER TABLE graphs_v3 RENAME TO graphs');
        this.db.exec(`CREATE UNIQUE INDEX idx_graphs_user_source_id
          ON graphs(source_id) WHERE question_source='USER_AUTHORED';`);
        this.db.prepare('UPDATE meta SET value=? WHERE key=?').run('3', 'schema_version');
        this.db.exec('COMMIT');
      } catch (e) {
        try { this.db.exec('ROLLBACK'); } catch {}
        throw e;
      } finally {
        this.db.exec('PRAGMA foreign_keys = ON');
      }
    }
    if (current < 4) {
      this.db.exec('BEGIN IMMEDIATE');
      try {
        const columns = this.db.prepare('PRAGMA table_info(nodes)').all().map((c) => c.name);
        if (!columns.includes('parent_node_id')) {
          this.db.exec('ALTER TABLE nodes ADD COLUMN parent_node_id TEXT REFERENCES nodes(node_id)');
        }
        // 旧图一直按 CENTER → child 渲染。回填后视觉结构不变，且不会丢失历史 node/layout/ink ID。
        this.db.exec(`UPDATE nodes
          SET parent_node_id=(SELECT center_node_id FROM graphs g WHERE g.graph_id=nodes.graph_id)
          WHERE kind<>'CENTER' AND parent_node_id IS NULL`);
        this.db.exec('CREATE INDEX IF NOT EXISTS idx_nodes_parent_node_id ON nodes(parent_node_id)');
        this.db.prepare('UPDATE meta SET value=? WHERE key=?').run('4', 'schema_version');
        this.db.exec('COMMIT');
        current = 4;
      } catch (e) {
        try { this.db.exec('ROLLBACK'); } catch {}
        throw e;
      }
    }
    if (current < 5) {
      // v4 及之前用 [0,1] 归一化坐标。保留旧列以保证 SQLite 的加列迁移可逆，
      // 但从本版本起所有 canonical 读写只走无边界的 world 字段。
      this.db.exec('BEGIN IMMEDIATE');
      try {
        const columns = this.db.prepare('PRAGMA table_info(layouts)').all().map((c) => c.name);
        if (!columns.includes('x_world')) this.db.exec('ALTER TABLE layouts ADD COLUMN x_world REAL');
        if (!columns.includes('y_world')) this.db.exec('ALTER TABLE layouts ADD COLUMN y_world REAL');
        const after = this.db.prepare('PRAGMA table_info(layouts)').all().map((c) => c.name);
        if (after.includes('x_norm') && after.includes('y_norm')) {
          this.db.exec(`UPDATE layouts
            SET x_world=(x_norm - 0.5) * ${LEGACY_WORLD_WIDTH},
                y_world=(y_norm - 0.5) * ${LEGACY_WORLD_HEIGHT}
            WHERE x_world IS NULL OR y_world IS NULL`);
        } else {
          // 仅作为异常库的安全兜底；正常 v1-v4 库必然带有 normalized 列。
          this.db.exec('UPDATE layouts SET x_world=COALESCE(x_world,0), y_world=COALESCE(y_world,0)');
        }
        const incomplete = this.db.prepare('SELECT count(*) AS c FROM layouts WHERE x_world IS NULL OR y_world IS NULL').get().c;
        if (Number(incomplete) !== 0) throw new Error('WORLD_LAYOUT_MIGRATION_INCOMPLETE');
        this.db.prepare('UPDATE meta SET value=? WHERE key=?').run('5', 'schema_version');
        this.db.exec('COMMIT');
        current = 5;
      } catch (e) {
        try { this.db.exec('ROLLBACK'); } catch {}
        throw e;
      }
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
