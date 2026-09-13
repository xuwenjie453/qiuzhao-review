# 修复前现场保护

执行任何修复前：

1. `git status`、当前 branch、HEAD SHA。
2. 复制 Mac `dual-end.db`。
3. 复制 daemon logs。
4. 复制 iPad `client-store.sqlite`（只读备份）。
5. 查询并导出 pending/inflight outbox 行。
6. 导出 Mac `sync_journal` 中对应 message_id 行。
7. 不清 App 数据，不删 outbox。

目的：保留真实 poison message，用它做 Mac 幂等修复的因果验证。
