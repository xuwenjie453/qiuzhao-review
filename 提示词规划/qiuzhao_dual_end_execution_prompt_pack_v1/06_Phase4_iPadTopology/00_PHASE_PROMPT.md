# Phase 4 — QuestionGraph Topology — Phase 总控 Prompt

## 目标
实现真正可交互的问题图高层视图，包括三类节点形状、稳定布局、手势、标题/删除、离线 optimistic 操作与 active graph 自动切换。

## 开始前必须阅读
- `90_设计稿基线/04_iPad端/02_问题图Topology设计.md`
- `90_设计稿基线/03_协议与同步/04_ClientCommand与冲突处理.md`

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- 三种 shape 正确。
- deterministic initial layout。
- user pinned layout 持久化。
- single/double/long press 手势不串扰。
- rename/delete/move local-first + outbox。
- CENTER 无删除 UI 且服务端仍守卫。
