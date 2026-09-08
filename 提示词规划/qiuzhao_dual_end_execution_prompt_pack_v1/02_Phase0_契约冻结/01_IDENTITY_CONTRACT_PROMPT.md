# Question / Graph / Round 身份契约

## 任务目标
把设计中的身份规则落成一个可由 Mac 与 iPad 共享理解的规范和 fixture。

## 必读设计稿
- `90_设计稿基线/01_产品与领域/05_问题身份与轮次生命周期.md`

## 必须满足
- `question_key` 试题库使用 `qb:<permanent_question_id>`。
- Review 使用 `capsule:<capsule_id>:<probe_key>`，不能用每轮自然语言题干 hash。
- `graph_id` 对 question_key 稳定；同题重开不得新建图。
- round 每次 open 新 UUID；temporary 必须携带 round_id。
- node_id 永久 UUID；title/body 变化不能改变 node_id。

## 实施步骤
1. 检查现有 review capsule/probe 是否已有稳定 probe identity。
2. 若没有 stable probe_key，只新增双端身份所需字段/推导规则，不能改 Review 调度数学。
3. 定义 canonical normalization 函数及测试 vectors。
4. 将 identity vectors 写入共享 fixtures。

## 测试要求
- 同永久题号多次 normalize 得到同 question_key。
- 同 capsule+probe 得到同 key。
- 不同 probe 不碰撞。
- 题干措辞变化不改变 stable identity。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
