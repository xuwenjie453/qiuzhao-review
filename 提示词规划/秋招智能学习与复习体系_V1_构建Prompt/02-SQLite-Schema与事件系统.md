# SQLite Schema 与 Event System 构建 Prompt

请为 V1 创建简洁、可重放、带时间戳、职责分离的 SQLite Schema。

核心哲学：

> Events are facts. States are projections.

## scheduler.sqlite3

至少包含：

### goals
- goal_id PK
- parent_goal_id nullable
- name
- goal_type
- strategy
- intent
- start_date
- end_date nullable
- priority
- status
- created_at
- completed_at nullable

### goal_scopes
- scope_id PK
- goal_id FK
- engine_type
- target_pattern
- weight

### goal_policies
- goal_id PK/FK
- policy_json

### goal_events
- event_id PK
- goal_id FK
- occurred_at
- event_type
- payload_json

### study_sessions
- session_id PK
- started_at
- ended_at nullable
- active_goal_id nullable
- status

### review_schedule
只保存跨引擎时序状态：
- capsule_id PK
- engine_type
- target_id
- stability
- difficulty
- last_review_at nullable
- next_due_at nullable
- last_grade nullable
- review_count
- lapse_count
- active
- scheduling_version
- updated_at

`retrievability` 不永久存储，运行时计算。

## Knowledge/knowledge.sqlite3

至少：
- knowledge_nodes
- node_relations
- learning_events
- knowledge_states
- review_capsules

## Algorithms/algorithms.sqlite3

至少：
- skill_nodes
- skill_relations
- learning_events
- skill_states
- review_capsules

skill_nodes 支持 `TEMPORARY` / `PERSISTENT`，并区分 Component / Integration。

## Projects/projects.sqlite3

至少：
- engineering_nodes
- node_relations
- learning_events
- engineering_states
- review_capsules

## 资料库/materials.sqlite3

至少：

### documents
- document_id
- path
- title
- content_hash
- file_type
- indexed_at
- updated_at

### chunks
- chunk_id
- document_id
- parent_chunk_id
- level
- heading_path
- content
- start_offset
- end_offset
- content_hash

### chunk_embeddings
- chunk_id
- embedding_model
- vector_ref
- generated_at

并建立 FTS5 虚拟表。

## learning_events 通用字段

至少：
- event_id
- occurred_at
- session_id
- target_id
- event_type
- question_id nullable
- result nullable
- evidence_json nullable
- prompt_version
- created_at

典型 Knowledge event：
- LEARNING_STARTED
- BLOCK_PRESENTED
- RETRIEVAL_SUCCESS
- RETRIEVAL_PARTIAL
- RETRIEVAL_FAILURE
- REPAIR_SUCCESS
- TRANSFER_SUCCESS
- LEARNING_VERIFIED

Algorithms：
- SKILL_IDENTIFIED
- SKILL_REPAIR
- PATTERN_RECOGNIZED
- INDEPENDENT_IMPLEMENTATION
- TEST_PASS
- TRANSFER_PASS
- LEARNING_VERIFIED

Projects：
- CASE_ATTEMPT
- REASONING_SUCCESS
- TRADEOFF_SUCCESS
- FAILURE_MODE_SUCCESS
- TRANSFER_CASE_SUCCESS
- LEARNING_VERIFIED

Review：
- REVIEW_PROBE_SHOWN
- REVIEW_SUCCESS
- REVIEW_PARTIAL
- REVIEW_FAILURE
- REPAIR_SUCCESS

## 强规则

Repair 后答对不能覆盖初始失败。必须同时保留：
- REVIEW_FAILURE
- REPAIR_SUCCESS

## State Rebuilder

必须实现：

```text
events → replay → current state
```

Current State 可以删除并重建。

## Schema Version

每个数据库建立 `schema_meta(key,value)`，至少保存：
- schema_version
- created_at
- updated_at

## Integrity

初始化：

```sql
PRAGMA foreign_keys = ON;
```

QA：

```sql
PRAGMA integrity_check;
PRAGMA foreign_key_check;
```

输出：完整建表 SQL、索引、主外键说明、Replay 规则、migration/version 策略。不要增加无明确场景的表。
