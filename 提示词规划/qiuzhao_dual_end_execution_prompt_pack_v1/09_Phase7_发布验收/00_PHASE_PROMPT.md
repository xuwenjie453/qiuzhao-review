# Phase 7 — Release / Recovery / Delivery — Phase 总控 Prompt

## 目标
对完整版本做跨端、断网、崩溃、权限、兼容性、真机与原系统 regression 验收，并生成最终交付报告。

## 开始前必须阅读
- `90_设计稿基线/06_质量与交付/*`
- `90_设计稿基线/08_附录/03_需求到设计追踪矩阵.md`
- 本包 `10_代码审查/*`
- 本包 `12_交付模板/*`

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- Release Acceptance Criteria 每项有明确状态。
- 不存在“看起来能用”但未测的 PASS。
- blocked 项写真实 blocker。
- 仓库 clean/可理解/可启动。
