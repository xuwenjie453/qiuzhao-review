# Phase 1 — Mac Graph Core — Phase 总控 Prompt

## 目标
实现完全不依赖 iPad 网络也能工作的 QuestionGraph canonical core、SQLite、daemon skeleton、localhost API 与 CLI。

## 开始前必须阅读
- `90_设计稿基线/02_Mac端/*`
- `90_设计稿基线/01_产品与领域/04_问题图领域模型.md`
- `90_设计稿基线/01_产品与领域/05_问题身份与轮次生命周期.md`
- Phase 0 契约/fixtures

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- CLI 能 init/status/open/add/close/query。
- temp 生命周期、body immutable、center guard、dedup 有自动化测试。
- daemon 单实例/SAFE_MODE 基础存在。
- 还不要求 iPad 连接。
