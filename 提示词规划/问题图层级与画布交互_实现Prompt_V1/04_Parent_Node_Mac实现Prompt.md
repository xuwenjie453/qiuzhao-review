# 04 — Parent Node：Mac canonical + Schema 实现 Prompt

本阶段只建立**持久、可同步、可迁移**的 parent-child 结构。不要引入通用图关系模型。

## 1. Canonical 数据模型

给 `nodes` 增加 nullable：

```sql
parent_node_id TEXT REFERENCES nodes(node_id)
```

语义：

```text
CENTER       → parent_node_id = NULL
EXPLANATION  → parent_node_id = CENTER 或 EXPLANATION
TEMPORARY    → V1 固定 parent = CENTER（仍可在存储中记录 center id）
```

`parent_node_id` 是知识结构字段，不属于 `layouts`。

## 2. Schema migration：预计 v3 → v4

以当前实际 `SCHEMA_VERSION` 为准；若仍为 3，则升级为 4，并同步更新 fresh DDL 与 migration。

迁移必须满足：

1. 保留所有 graph/node/layout/round/ink ID；
2. CENTER 的 parent 保持 NULL；
3. 所有历史非 CENTER 可见/已存在 node 默认 backfill 到其 graph 的 `center_node_id`，从而升级后视觉结构与旧版本相同；
4. migration 可在已有真实 DB 上执行，不要求删库重建；
5. foreign key / immutable trigger / indexes 不被破坏；
6. schema version 只有 migration 成功后才更新。

可优先使用 additive migration：

```sql
ALTER TABLE nodes ADD COLUMN parent_node_id TEXT REFERENCES nodes(node_id);

UPDATE nodes
SET parent_node_id = (
  SELECT g.center_node_id FROM graphs g WHERE g.graph_id = nodes.graph_id
)
WHERE kind <> 'CENTER' AND parent_node_id IS NULL;
```

但不要机械复制；先确认当前 SQLite/Node `DatabaseSync` 行为与表约束。若必须重建表，必须完整复制现有字段、trigger/index，并保持引用有效。

建议增加 parent lookup index（如当前查询需要）：

```sql
CREATE INDEX IF NOT EXISTS idx_nodes_parent_node_id ON nodes(parent_node_id);
```

## 3. `QuestionGraphService.addNode`

扩展签名为可接收：

```text
parent_node_id
```

### EXPLANATION

若 `parent_node_id` 缺失/null：

```text
resolvedParent = currentGraph.center_node_id
```

若显式提供：必须验证：

- parent 存在；
- `deleted_at IS NULL`；
- `parent.graph_id === round.graph_id`；
- `parent.kind` 是 `CENTER` 或 `EXPLANATION`；
- parent 不是 inherited-only external graph node（same graph 校验自然拒绝）。

显式非法 parent 必须抛 validation/node error；**禁止静默 fallback CENTER**。

### TEMPORARY

V1 保留旧行为：parent 固定为 current graph CENTER。

- 未提供 parent → center；
- 调用方显式提供非空 parent → validation error，避免产生“永久/临时层级”的模糊语义。

### CENTER

仍禁止通过 addNode 创建。

## 4. 创建结果

INSERT node 时持久化 resolved parent。

`addNode` result 建议返回：

```json
{
  "node_id": "...",
  "parent_node_id": "...",
  "kind": "EXPLANATION",
  ...
}
```

便于 patch/调试，但 wire 的真实 source of truth 仍是 `nodeGet` / snapshot。

不增加 `node.reparent`。因此 V1 创建时天然无 cycle：新节点尚无 descendants。不要为未来功能加入复杂 DAG 逻辑。

## 5. Snapshot

`QuestionGraphService.snapshotPayload()` 的每个 node 增加：

```json
"parent_node_id": "..." | null
```

CENTER 发送 null。

Inherited explanation：发送其 canonical raw `parent_node_id`。在 Review effective view 中：

- 若 parent explanation 也作为 inherited node 可见，iPad 可以保留继承层级；
- 若 raw parent 指向源 QuestionBank CENTER，而该 CENTER 不在 Review snapshot，则 iPad presentation fallback 当前 Review CENTER。

不要在 server 为不同 consumer 重写 canonical parent。

## 6. ADD_NODE patch

`DualEnd-Mac/src/daemon.mjs` 的 `ADD_NODE` 完整 node payload 必须增加 `parent_node_id`。

特别检查 inheritance fan-out：QuestionBank 新 explanation 可能向 descendant Review graph 发 patch。发送 raw canonical parent；由 consumer 根据当前 visible nodes resolve/fallback。

不要仅修改 snapshot 而漏掉 patch，否则在线新增会暂时显示错误，直到下一次全量 snapshot。

## 7. CLI / command payload

现有 `graph.add-node` command 应透明接受可选 `parent_node_id`，并继续把 `node_kind` 映射到 service `kind`。

如果 CLI 有显式字段白名单/schema，最小扩展它；若 CLI 本来直接传 JSON，则不要多造层。

必须保持旧调用完全有效：

```json
{
  "round_id": "...",
  "node_kind": "EXPLANATION",
  "ai_title": "...",
  "body_markdown": "..."
}
```

其结果应自动 parent=CENTER。

## 8. 删除父节点语义

V1 **不 cascade，不 reparent canonical**。

若 A(parent) 被 tombstone，而 B.parent_node_id 仍=A：

- B 保留；
- DB 关系保留；
- snapshot 不再含已删除 A；
- client 展示 B 时 fallback CENTER。

不要在 deleteNode 中批量更新 descendants。

## 9. Mac tests（MUST）

扩展 `DualEnd-Mac/test/graph.test.mjs` 或等价测试：

1. fresh DB schema version 已升级；
2. legacy schema migration 后：CENTER parent NULL，旧 non-center parent=center；
3. EXPLANATION 不传 parent → center；
4. A explanation，创建 B(parent=A) → DB/snapshot/result 均为 A；
5. CENTER→A→B→C 多级 snapshot 保持；
6. nonexistent parent → reject；
7. deleted parent → reject；
8. TEMPORARY parent → 创建 EXPLANATION 时 reject；
9. other graph parent → reject；
10. TEMPORARY 显式 custom parent → reject；
11. legacy add-node payload 仍成功；
12. body immutable、CENTER delete、round lifecycle、inheritance、dedup 等既有 tests 继续通过；
13. inheritance snapshot/patch 的 raw parent 字段行为符合本文件约定。

## 10. 不做

- edges table；
- relation kind；
- multi-parent；
- reparent；
- cycle UI；
- parse command；
- 自动改 parent body。

本阶段完成条件：Mac canonical 能可靠保存、迁移、返回 parent relationship，且旧调用/旧图不退化。
