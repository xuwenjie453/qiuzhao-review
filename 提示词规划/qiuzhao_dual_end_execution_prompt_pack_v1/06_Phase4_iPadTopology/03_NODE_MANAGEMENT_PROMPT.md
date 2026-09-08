# 标题编辑与删除

## 任务目标
实现 single tap management sheet 的 local-first mutation。

## 必读设计稿
- `90_设计稿基线/04_iPad端/02_问题图Topology设计.md`
- `90_设计稿基线/03_协议与同步/04_ClientCommand与冲突处理.md`

## 必须满足
- CENTER 可 rename 不可 delete。
- title 1..80。
- offline rename/delete 进入 outbox。
- server reject rollback/reconcile。

## 实施步骤
1. 实现 sheet。
2. 保存先 store 后 dismiss。
3. 保留 rename conflict draft。

## 测试要求
- center no delete action
- offline rename survives
- delete tombstone reconcile

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
