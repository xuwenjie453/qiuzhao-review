# -*- coding: utf-8 -*-
"""秋招智能学习与复习体系 V1 — 数据库 Schema
哲学: Events are facts. States are projections.
物理边界(架构冻结): scheduler 在根目录; 三引擎库在各自目录; materials 在资料库; questions 只属于试题库。
"""
SCHEMA_VERSION = "1.0"

# ---------- scheduler.sqlite3 ----------
SCHEDULER_SQL = """
CREATE TABLE IF NOT EXISTS goals (
    goal_id        TEXT PRIMARY KEY,
    parent_goal_id TEXT REFERENCES goals(goal_id),
    name           TEXT NOT NULL,
    goal_type      TEXT NOT NULL,            -- COVERAGE/ACQUISITION/MASTERY/REACTIVATION/SPRINT/MAINTENANCE/SPECIALIZATION
    strategy       TEXT NOT NULL,            -- COVERAGE_FIRST/MASTERY_FIRST/SPRINT/REACTIVATION/BALANCED
    intent         TEXT NOT NULL,
    start_date     TEXT NOT NULL,            -- YYYY-MM-DD (本地日期)
    end_date       TEXT,
    priority       REAL NOT NULL DEFAULT 5.0,
    status         TEXT NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE/PAUSED/COMPLETED/CANCELLED
    created_at     TEXT NOT NULL,
    completed_at   TEXT
);
CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);

CREATE TABLE IF NOT EXISTS goal_scopes (
    scope_id      TEXT PRIMARY KEY,
    goal_id       TEXT NOT NULL REFERENCES goals(goal_id),
    engine_type   TEXT NOT NULL,             -- Knowledge/Algorithms/Projects
    target_pattern TEXT NOT NULL,            -- 子类/节点 glob, 如 'Knowledge/*' 'MySQL'
    weight        REAL NOT NULL DEFAULT 1.0
);

CREATE TABLE IF NOT EXISTS goal_policies (
    goal_id     TEXT PRIMARY KEY REFERENCES goals(goal_id),
    policy_json TEXT NOT NULL               -- 相对权重: coverage/retention/weakness/importance/temporal_urgency/diversity/transfer/new_learning + desired_retention
);

CREATE TABLE IF NOT EXISTS goal_events (
    event_id    TEXT PRIMARY KEY,
    goal_id     TEXT REFERENCES goals(goal_id),
    occurred_at TEXT NOT NULL,
    event_type  TEXT NOT NULL,               -- GOAL_CREATED/GOAL_ACTIVATED/GOAL_PAUSED/GOAL_COMPLETED/GOAL_CANCELLED/GOAL_NOTE
    payload_json TEXT
);

CREATE TABLE IF NOT EXISTS study_sessions (
    session_id     TEXT PRIMARY KEY,
    started_at     TEXT NOT NULL,
    ended_at       TEXT,
    active_goal_id TEXT REFERENCES goals(goal_id),
    status         TEXT NOT NULL DEFAULT 'OPEN'      -- OPEN/CLOSED
);

CREATE TABLE IF NOT EXISTS review_schedule (
    capsule_id        TEXT PRIMARY KEY,      -- = 各引擎 review_capsules.capsule_id
    engine_type       TEXT NOT NULL,
    target_id         TEXT NOT NULL,
    stability         REAL NOT NULL DEFAULT 2.0,     -- 天
    difficulty        REAL NOT NULL DEFAULT 4.0,     -- 1..10, 越高越难
    last_review_at    TEXT,
    next_due_at       TEXT,                  -- 缓存/候选时点, 不是 Due Queue
    last_grade        TEXT,
    review_count      INTEGER NOT NULL DEFAULT 0,
    lapse_count       INTEGER NOT NULL DEFAULT 0,
    active            INTEGER NOT NULL DEFAULT 1,
    scheduling_version TEXT NOT NULL,
    updated_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rs_active ON review_schedule(active, next_due_at);
CREATE INDEX IF NOT EXISTS idx_rs_engine ON review_schedule(engine_type, target_id);
"""

# ---------- 三引擎共用形态 ----------
# knowledge: knowledge_nodes/node_relations/learning_events/knowledge_states/review_capsules
# algorithms: skill_nodes(...)/skill_relations/learning_events/skill_states/review_capsules
# projects: engineering_nodes/node_relations/learning_events/engineering_states/review_capsules

def engine_sql(nodes_table, relations_table, states_table,
               node_extra="", node_extra_ddl=""):
    return f"""
CREATE TABLE IF NOT EXISTS {nodes_table} (
    node_id      TEXT PRIMARY KEY,
    node_type    TEXT NOT NULL,              -- G1..G6 / Component / Integration / PSB 等
    parent_id    TEXT REFERENCES {nodes_table}(node_id),
    name         TEXT NOT NULL,
    engine_type  TEXT NOT NULL,
    lifecycle    TEXT NOT NULL DEFAULT 'PERSISTENT',  -- PERSISTENT/TEMPORARY (Algorithms 技能)
    importance   REAL NOT NULL DEFAULT 3.0,  -- 1..5, 来自题库星级投影
    subcategory  TEXT,                       -- 试题库子类投影, 供 Goal Scope 匹配
    summary      TEXT,
    {node_extra}
    created_at   TEXT NOT NULL,
    updated_at   TEXT NOT NULL
);
{node_extra_ddl}
CREATE INDEX IF NOT EXISTS idx_{nodes_table}_sub ON {nodes_table}(subcategory);

CREATE TABLE IF NOT EXISTS {relations_table} (
    relation_id  TEXT PRIMARY KEY,
    from_node    TEXT NOT NULL REFERENCES {nodes_table}(node_id),
    to_node      TEXT NOT NULL REFERENCES {nodes_table}(node_id),
    relation     TEXT NOT NULL,              -- prerequisite/related/composes
    created_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS learning_events (
    event_id       TEXT PRIMARY KEY,
    occurred_at    TEXT NOT NULL,            -- 事件事实时间(本地, 秒级 ISO)
    session_id     TEXT,
    target_id      TEXT NOT NULL,            -- node_id
    event_type     TEXT NOT NULL,
    question_id    TEXT,
    result         TEXT,                     -- success/partial/failure/na
    evidence_json  TEXT,
    prompt_version TEXT,
    created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_le_target ON learning_events(target_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_le_type ON learning_events(event_type);

CREATE TABLE IF NOT EXISTS {states_table} (
    target_id        TEXT PRIMARY KEY,
    engine_type      TEXT NOT NULL,
    status           TEXT NOT NULL DEFAULT 'UNSEEN', -- UNSEEN/LEARNING/LEARNING_VERIFIED/REPAIR/REACTIVATED
    first_learned_at TEXT,
    last_event_at    TEXT,
    event_count      INTEGER NOT NULL DEFAULT 0,
    failure_count    INTEGER NOT NULL DEFAULT 0,
    repair_count     INTEGER NOT NULL DEFAULT 0,
    g_level          TEXT,                   -- 最近一次学习粒度(Knowledge)
    coverage_weight  REAL NOT NULL DEFAULT 1.0,
    updated_at       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS review_capsules (
    capsule_id          TEXT PRIMARY KEY,
    target_id           TEXT NOT NULL REFERENCES {nodes_table}(node_id),
    engine_type         TEXT NOT NULL,
    must_retrieve       TEXT NOT NULL,       -- 压缩后的最小可检索要点(JSON数组)
    known_failure_modes TEXT,                -- JSON数组
    allowed_probe_types TEXT,                -- JSON数组
    required_context    TEXT,                -- JSON
    response_budget     TEXT,                -- sentence/short_para/small_code/medium_code/short_decision
    source_questions    TEXT,                -- JSON数组(question_id)
    eligibility_evidence TEXT NOT NULL,      -- 为何值得长期复习
    compiler_version    TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'REVIEW_ELIGIBLE',
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL
);
"""

KNOWLEDGE_SQL = engine_sql(
    'knowledge_nodes', 'node_relations', 'knowledge_states',
    node_extra="g_level TEXT,",  # 节点生成粒度 G1..G6
    node_extra_ddl="")

ALGORITHMS_SQL = engine_sql(
    'skill_nodes', 'skill_relations', 'skill_states',
    node_extra="skill_class TEXT,",  # Component/Integration
    node_extra_ddl="")

PROJECTS_SQL = engine_sql(
    'engineering_nodes', 'node_relations', 'engineering_states',
    node_extra="psb_json TEXT,",  # Project Solution Block
    node_extra_ddl="""CREATE INDEX IF NOT EXISTS idx_engines_psb ON engineering_nodes(psb_json);""")

# ---------- 资料库/materials.sqlite3 ----------
MATERIALS_SQL = """
CREATE TABLE IF NOT EXISTS documents (
    document_id  TEXT PRIMARY KEY,
    path         TEXT NOT NULL UNIQUE,
    title        TEXT,
    content_hash TEXT NOT NULL,
    file_type    TEXT,
    chunk_count  INTEGER NOT NULL DEFAULT 0,
    indexed_at   TEXT NOT NULL,
    updated_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS chunks (
    chunk_id       TEXT PRIMARY KEY,
    document_id    TEXT NOT NULL REFERENCES documents(document_id) ON DELETE CASCADE,
    parent_chunk_id TEXT REFERENCES chunks(chunk_id),
    level          INTEGER NOT NULL,          -- 0=Document 1=Section 2=Concept
    heading_path   TEXT,
    content        TEXT NOT NULL,
    start_offset   INTEGER,
    end_offset     INTEGER,
    content_hash   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(document_id, level);

CREATE TABLE IF NOT EXISTS chunk_embeddings (
    chunk_id        TEXT NOT NULL REFERENCES chunks(chunk_id) ON DELETE CASCADE,
    embedding_model TEXT NOT NULL,
    vector_ref      TEXT NOT NULL,             -- 'db:embedding_vec:<chunk_id>'
    generated_at    TEXT NOT NULL,
    PRIMARY KEY (chunk_id, embedding_model)
);

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
    content, heading_path, chunk_id UNINDEXED, tokenize='trigram'
);

-- 语义向量本体(spec 表 vector_ref 指向此处; 模型可替换)
CREATE TABLE IF NOT EXISTS embedding_vec (
    chunk_id TEXT PRIMARY KEY REFERENCES chunks(chunk_id) ON DELETE CASCADE,
    model    TEXT NOT NULL,
    dim      INTEGER NOT NULL,
    vec      BLOB NOT NULL
);
"""

ALL = {
    'scheduler.sqlite3': SCHEDULER_SQL,
    'Knowledge/knowledge.sqlite3': KNOWLEDGE_SQL,
    'Algorithms/algorithms.sqlite3': ALGORITHMS_SQL,
    'Projects/projects.sqlite3': PROJECTS_SQL,
    '资料库/materials.sqlite3': MATERIALS_SQL,
}
