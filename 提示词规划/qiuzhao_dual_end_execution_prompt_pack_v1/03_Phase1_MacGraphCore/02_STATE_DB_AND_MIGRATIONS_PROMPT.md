# Dual-End State DB 与 migration

## 任务目标
实现 schema v1 与数据库访问层。

## 必读设计稿
- `90_设计稿基线/02_Mac端/04_存储与数据库.md`
- `90_设计稿基线/08_附录/01_SQL_Schema_v1.md`

## 必须满足
- 所有写事务串过 Store API。
- WAL/FULL/FK/busy_timeout。
- migration 可重入。
- immutable trigger。

## 实施步骤
1. 实现 open/close/transaction helper。
2. 实现 migration version。
3. 实现 integrity_check。
4. 实现测试临时 DB。

## 测试要求
- fresh init
- reopen
- trigger
- constraints
- integrity

## 禁止捷径
- 不要把业务 command 逻辑塞进 generic DB helper。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
