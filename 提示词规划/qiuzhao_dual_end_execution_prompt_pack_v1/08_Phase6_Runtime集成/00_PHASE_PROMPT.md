# Phase 6 — 现有学习系统 / Runtime Prompt 集成 — Phase 总控 Prompt

## 目标
把双端能力接入现有 Agent 学习会话，同时确保双端失败不阻断原学习闭环。

## 开始前必须阅读
- `90_设计稿基线/05_集成与迁移/*`
- 当前根 AGENTS.md
- 当前 RuntimePrompt V1
- 当前 scheduler/review/probe 代码

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- LEARN/REPAIR/REVIEW 都能正确形成 QuestionRef。
- Agent 在题目开始/切换时 open/close。
- 用户显式选解释才 add。
- AGENTS 旧的“禁止 App”限制被精确修订。
- 原学习测试无 regression。
