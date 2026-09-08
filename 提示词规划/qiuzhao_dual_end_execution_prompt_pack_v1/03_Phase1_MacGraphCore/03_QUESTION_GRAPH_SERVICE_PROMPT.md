# QuestionGraphService

## 任务目标
实现 graph/node/layout/round 的确定性领域服务。

## 必读设计稿
- `90_设计稿基线/02_Mac端/03_问题图命令服务.md`
- `90_设计稿基线/01_产品与领域/04_问题图领域模型.md`

## 必须满足
- Query/Command 分离。
- 每 command 一个 transaction。
- 每图一 CENTER。
- body INSERT 后不可更新。
- graph_revision 单调。

## 实施步骤
1. 实现 ensureGraph/open/close/add/rename/move/delete/query。
2. 把不变量放 service+DB 双层可适用处。
3. 统一 domain error codes。

## 测试要求
- same question same graph
- center delete rejected
- body immutable
- rename/move revision
- delete tombstone

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
