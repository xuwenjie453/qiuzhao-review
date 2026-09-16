// QuestionGraph 双端 Store —— 仅该模块可触达 SQLite。
// 冻结契约: Mac canonical; body immutable (API + DB trigger 双保险);
// one center per graph; one active round 全局; command dedup; sync_journal server_seq 单调。
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { nowIso } from '../util.mjs';

export const SCHEMA_VERSION = 4;

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
  kind TEXT NOT NULL CHECK(kind IN ('CENTER','EXPLANATION','TEMPORARY')),
  title TEXT NOT NULL,
  body_markdown TEXT NOT NULL,
  body_sha256 TEXT NOT NULL,
  round_id TEXT REFERENCES rounds(round_id),
  parent_node_id TEXT REFERENCES nodes(node_id),
  node_revision INTEGER NOT NULL DEFAULT 1,
  origin_turn_ref TEXT,
  created_at TEXT NOT NULL,
  deleted_at TEXT,
  expired_at TEXT,
  CHECK((kind='TEMPORARY' AND round_id IS NOT NULL) OR (kind!='TEMPORARY' AND round_id IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS one_center_per_graph
  ON nodes(graph_id) WHERE kind='CENTER' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_nodes_parent_node_id ON nodes(parent_node_id);
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
        current = 3;
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
        const cols = this.db.prepare('PRAGMA table_info(nodes)').all().map((c) => c.name);
        if (!cols.includes('parent_node_id')) {
          this.db.exec('ALTER TABLE nodes ADD COLUMN parent_node_id TEXT REFERENCES nodes(node_id)');
        }
        this.db.exec(`UPDATE nodes
          SET parent_node_id=(SELECT g.center_node_id FROM graphs g WHERE g.graph_id=nodes.graph_id)
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
  }

  integrity() {
    const ic = this.db.prepare('PRAGMA integrity_check').get();
    const fk = this.db.prepare('PRAGMA foreign_key_check').all();
    return { integrity: ic && ic.integrity_check, fk_violations: fk.length };
  }

  withTx(fn) {
    if (this[TX]) return fn(this[TX]);
    this.db.exec('BEGIN IMMEDIATE');
    const tx = { db: this, prepare: (s) => this.db.prepare(s), exec: (s) => this.db.exec(s) };
    this[TX] = tx;
    try {
      const r = fn(tx);
      this.db.exec('COMMIT');
      return r;
    } catch (e) {
      try { this.db.exec('ROLLBACK'); } catch {}
      throw e;
    } finally {
      this[TX] = undefined;
    }
  }

  prepare(sql) { return this.db.prepare(sql); }
  exec(sql) { this.db.exec(sql); }

  journalUnique(message_id, kind, graphId, payloadObj) {
    const r = this.db.prepare(
      'INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at) VALUES (?,?,?,?,?)'
    ).run(message_id, kind, graphId ?? null, stableStringify(payloadObj), nowIso());
    return { serverSeq: Number(r.lastInsertRowid), replay: false };
  }

  journal(message_id, kind, graphId, payloadObj) {
    return this.journalUnique(message_id, kind, graphId, payloadObj).serverSeq;
  }

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
