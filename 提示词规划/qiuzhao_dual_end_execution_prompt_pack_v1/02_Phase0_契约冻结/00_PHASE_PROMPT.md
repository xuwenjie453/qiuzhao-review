# Phase 0 — Contract Freeze — Phase 总控 Prompt

## 目标
在写大块实现前冻结跨端身份、SQL 语义、wire envelope、JSON fixtures、Agent runtime contract。目的是防止 Mac 和 iPad 分头开发后协议漂移。

## 开始前必须阅读
- `90_设计稿基线/01_产品与领域/04_问题图领域模型.md`
- `90_设计稿基线/01_产品与领域/05_问题身份与轮次生命周期.md`
- `90_设计稿基线/08_附录/01_SQL_Schema_v1.md`
- `90_设计稿基线/08_附录/02_协议样例.md`
- `90_设计稿基线/05_集成与迁移/02_RuntimePrompt改造.md`

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- 创建跨端 protocol fixtures。
- 冻结 `question_key/graph_id/round_id/node_id/session_epoch/message_id` 语义。
- 冻结 schema v1 与 migration strategy。
- 冻结 Agent open/add/close command contract。
- fixtures 可被 Node 和 Swift 后续测试共同使用。
