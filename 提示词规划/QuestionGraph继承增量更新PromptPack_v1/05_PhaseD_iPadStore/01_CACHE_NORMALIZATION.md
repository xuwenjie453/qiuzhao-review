# iPad Cache Normalization Prompt

修改 `ClientStore.swift` schema 时目标是分离 canonical identity 与 view membership。

## 目标 schema

概念上：

```sql
nodes_cache(
  node_id PRIMARY KEY,
  owner_graph_id NOT NULL,
  kind,title,body_markdown,node_revision,
  x_norm,y_norm,layout_revision,
  locally_deleted,...
);

graph_node_membership_cache(
  graph_id NOT NULL,
  node_id NOT NULL,
  visibility NOT NULL CHECK(visibility IN ('OWN','INHERITED')),
  PRIMARY KEY(graph_id,node_id)
);
```

字段可依当前实现调整，但语义不可合并回单一 graph_id。

## Migration

旧 `nodes_cache.graph_id` 行迁移规则：
- 原 graph_id -> owner_graph_id；
- 为每行创建 `(graph_id,node_id,'OWN')` membership；
- ink_cache 不复制；
- outbox/inbox/active state 不清空。

迁移必须事务化、可重启、版本化。

## Read path

`loadSnapshot(graphId)` 改为 membership JOIN canonical nodes，而不是 `WHERE nodes_cache.graph_id=?`。

一个 node 被多个 graph load 时返回相同 canonical title/body/revisions/layout。
