# Recovery Master Prompt

当 inheritance 更新出现故障时，目标是**保留现场并恢复事实一致性**，不是通过清库让应用重新工作。

## 首先禁止

- 不删除 Mac `dual-end.db`；
- 不删除 iPad `client-store.sqlite`；
- 不清空 outbox/inbox；
- 不手动改 schema_version 假装 migration 完成；
- 不批量复制 node 修补 membership；
- 不 force reset branch 覆盖用户修改。

## 收集证据

- 当前 commit/schema/wire version；
- PR/diff；
- Mac integrity + foreign_key_check；
- `graphs/nodes/graph_inheritance/layouts/ink` 相关行；
- iPad graphs_cache/nodes_cache/membership/outbox 状态；
- daemon log 与 command/message IDs；
- 失败测试最小复现。

先判断问题属于：migration / canonical relation / revision fan-out / wire decode / iPad membership / outbox conflict / Review source integration，再使用对应修复 Prompt。
