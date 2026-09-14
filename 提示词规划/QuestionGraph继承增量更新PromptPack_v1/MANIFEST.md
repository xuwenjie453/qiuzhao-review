# Manifest

本包所有 Prompt 都以“增量更新”为前提。每个 Phase 可以单独运行，但必须继承 `00_总控` 的约束。

## 目录职责

- `00_总控/`：总执行规则、权威顺序、不可违反产品规则、增量修改协议。
- `01_基线侦察/`：仓库侦察、测试基线、变更面映射。
- `02_PhaseA_契约冻结/`：把设计稿冻结成实现前检查表。
- `03_PhaseB_MacCanonical/`：Mac canonical schema、migration、QuestionGraphService、revision fan-out。
- `04_PhaseC_WireProtocol/`：wire DTO、fixtures、Snapshot/Patch/version。
- `05_PhaseD_iPadStore/`：iPad domain/cache/membership/outbox。
- `06_PhaseE_iPadUI/`：Topology/Reader/Ink/共享删除提示。
- `07_PhaseF_ReviewIntegration/`：review_capsules、compiler、Review open、RuntimePrompt。
- `08_PhaseG_Testing/`：Mac/Bridge/iPad/Learning 全层测试。
- `09_PhaseH_Release/`：Release Gate 与真机验收。
- `10_代码审查/`：独立审查提示词。
- `11_故障处理/`：迁移失败、revision 错乱、缓存错乱等恢复提示词。
- `12_执行与交付/`：一键启动、commit/PR、最终报告、停止条件。

## 权威优先级

发生冲突时：

1. 用户当前明确指令；
2. 已合并的 QuestionGraph 继承设计稿；
3. `AGENTS.md` 与 Runtime 双端协议；
4. 本 Prompt Pack；
5. 当前代码实现；
6. AI 自己的偏好。

当前代码若与冻结设计冲突，应该修改代码；本 Prompt Pack 若与冻结设计冲突，应该修改 Prompt Pack，而不是重新解释设计。
