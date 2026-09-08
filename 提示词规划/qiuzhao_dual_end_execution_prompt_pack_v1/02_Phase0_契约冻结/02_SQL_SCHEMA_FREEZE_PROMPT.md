# Mac Dual-End SQL Schema 冻结

## 任务目标
把 schema v1 变成可迁移、可测试的数据库契约。

## 必读设计稿
- `90_设计稿基线/02_Mac端/04_存储与数据库.md`
- `90_设计稿基线/08_附录/01_SQL_Schema_v1.md`

## 必须满足
- 新库独立于 scheduler / engine DB。
- WAL + synchronous FULL + foreign_keys ON + busy_timeout。
- DB-level body immutable trigger。
- one center per graph；one active round。
- command_dedup、sync_journal、device_state。
- schema version / migration table 必须存在。

## 实施步骤
1. 根据实际 Node `node:sqlite` 支持调整 SQL 语法，但保留语义。
2. 为 migration v1 编写 up/down 或 forward-only 可重复初始化逻辑。
3. 写 fresh DB、reopen DB、partial migration failure 测试。
4. integrity failure 不得自动新建空库覆盖。

## 测试要求
- fresh init
- double init idempotent
- body update abort
- one center guard
- active round guard
- foreign key check

## 禁止捷径
- 不得把表塞进 scheduler.sqlite3。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
