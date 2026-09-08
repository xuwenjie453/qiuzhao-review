# SQL Schema v1（Mac）

```sql
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE graphs(
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

CREATE TABLE rounds(
  round_id TEXT PRIMARY KEY,
  graph_id TEXT NOT NULL REFERENCES graphs(graph_id),
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','CLOSED','INTERRUPTED')),
  opened_at TEXT NOT NULL,
  closed_at TEXT
);
CREATE UNIQUE INDEX one_active_round ON rounds(status) WHERE status='ACTIVE';

CREATE TABLE nodes(
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

CREATE UNIQUE INDEX one_center_per_graph
ON nodes(graph_id) WHERE kind='CENTER' AND deleted_at IS NULL;

CREATE TABLE layouts(
  node_id TEXT PRIMARY KEY REFERENCES nodes(node_id),
  x_norm REAL NOT NULL,
  y_norm REAL NOT NULL,
  layout_revision INTEGER NOT NULL DEFAULT 1,
  pinned_by_user INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);

CREATE TABLE ink(
  node_id TEXT PRIMARY KEY REFERENCES nodes(node_id),
  ink_revision INTEGER NOT NULL,
  format TEXT NOT NULL,
  blob BLOB NOT NULL,
  blob_sha256 TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE command_dedup(
  command_id TEXT PRIMARY KEY,
  result_json TEXT NOT NULL,
  committed_at TEXT NOT NULL
);

CREATE TABLE sync_journal(
  server_seq INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL,
  graph_id TEXT,
  payload_json TEXT NOT NULL,
  committed_at TEXT NOT NULL
);

CREATE TABLE device_state(
  device_id TEXT PRIMARY KEY,
  last_seen_at TEXT NOT NULL,
  last_acked_server_seq INTEGER NOT NULL DEFAULT 0
);

CREATE TRIGGER node_body_immutable
BEFORE UPDATE OF body_markdown, body_sha256 ON nodes
BEGIN
  SELECT RAISE(ABORT, 'NODE_BODY_IMMUTABLE');
END;
```

实现时 schema migration 必须有版本号和自动化测试；上面是语义基线，可按 node:sqlite 具体限制调整语法。
