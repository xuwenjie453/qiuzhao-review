# ClientStore actor + SQLite

## 任务目标
实现 iPad local durable cache/outbox/inbox。

## 必读设计稿
- `90_设计稿基线/04_iPad端/06_iPad本地数据库.md`

## 必须满足
- 单 actor 串行 DB。
- cache/outbox/inbox 同 transaction。
- INFLIGHT disconnect→PENDING。
- 不主动清除有 pending outbox 的 graph。

## 实施步骤
1. 实现 schema/migration。
2. 实现 snapshot replace、patch apply primitives、local mutations。
3. BLOB Ink 与 JSON payload 分离适当。

## 测试要求
- reopen persistence
- outbox durability
- inbox dedup
- snapshot transaction rollback

## 禁止捷径
- 网络层不得直接 sqlite3_exec。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
