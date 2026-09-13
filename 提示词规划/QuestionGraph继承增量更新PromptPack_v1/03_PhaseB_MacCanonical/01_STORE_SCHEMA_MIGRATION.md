# Mac Store Schema & Migration Prompt

修改 `DualEnd-Mac/src/store/state-db.mjs` 时，不要把“新 DDL 能创建空库”误当 migration 完成。

## 必须实现

1. 读取 `meta.schema_version`。
2. 新空库直接创建目标 schema v2。
3. existing v1 DB 运行事务化 `1 -> 2` migration。
4. migration 新增：

```sql
CREATE TABLE graph_inheritance(
  child_graph_id TEXT NOT NULL REFERENCES graphs(graph_id) ON DELETE CASCADE,
  parent_graph_id TEXT NOT NULL REFERENCES graphs(graph_id) ON DELETE CASCADE,
  inheritance_kind TEXT NOT NULL DEFAULT 'SHARED_EXPLANATIONS',
  created_at TEXT NOT NULL,
  PRIMARY KEY(child_graph_id,parent_graph_id),
  CHECK(child_graph_id <> parent_graph_id)
);
CREATE INDEX idx_graph_inheritance_parent ON graph_inheritance(parent_graph_id);
```

按 SQLite 实际能力补 CHECK kind 约束。

## 不得破坏

- graphs/nodes/layouts/ink 已有 row identity。
- command_dedup 与 sync_journal。
- body immutable trigger。
- existing graph_revision/node_revision/layout_revision/ink_revision。
- foreign_keys/WAL。

## Migration 测试

程序化创建 v1 fixture DB：含 QB graph、Review graph、Explanation、layout、ink、round、dedup/journal。启动 v2 store 后断言：

- schema_version=2；
- 原数据 byte/semantic 等价存在；
- `graph_inheritance` 空；
- foreign_key_check=0；
- integrity_check=ok；
- 重启 migration 不重复执行、不损坏数据。

禁止通过删除 DB 或重新 seed 来让测试通过。
