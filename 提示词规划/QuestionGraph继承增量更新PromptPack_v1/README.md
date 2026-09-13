# QuestionGraph 继承增量更新 AI Prompt Pack V1

本提示词包用于指导具备仓库读取、代码修改、测试执行与 Git 操作能力的 AI，在 `xuwenjie453/qiuzhao-review` 中**增量实现 QuestionGraph 继承与共享解释节点**。

本包不是新的架构提案。架构已经冻结，权威设计位于：

- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/01_产品与领域/04_问题图领域模型.md`
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/01_产品与领域/05_问题图继承与共享解释节点.md`
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/03_协议与同步/03_GraphSnapshot与Patch.md`
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/04_iPad端/02_问题图Topology设计.md`
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/05_集成与迁移/04_迁移与兼容策略.md`
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/05_集成与迁移/06_问题图继承实施清单.md`

## 使用方式

推荐按编号顺序执行，不要一次性把全部代码改完：

1. `00_总控`：建立执行纪律、权威顺序和红线。
2. `01_基线侦察`：确认当前代码与测试真实状态。
3. `02_PhaseA_契约冻结`：把设计翻译成机器可验证的不变量。
4. `03_PhaseB_MacCanonical`：先完成 canonical store、effective view 与 revision fan-out。
5. `04_PhaseC_WireProtocol`：更新 Snapshot/Patch/fixtures/version。
6. `05_PhaseD_iPadStore`：正规化缓存并保持 durable/outbox 语义。
7. `06_PhaseE_iPadUI`：最后再接入 inherited UX。
8. `07_PhaseF_ReviewIntegration`：让 Capsule/Review open 自动建立 inheritance。
9. `08_PhaseG_Testing`：补齐跨层测试。
10. `09_PhaseH_Release`：执行 Release Gate。
11. `10_代码审查`、`11_故障处理`、`12_执行与交付`：用于审查、恢复与最终交付。

## 核心目标

```text
QuestionGraph View
= Owned Nodes
+ Inherited Shared EXPLANATION Nodes
```

继承是 live shared reference，不是 copy。Review graph 有自己的 CENTER，只共享来源 Question Bank graph 的 EXPLANATION。共享节点保留同一个 `node_id`，标题、布局、Ink 均 write-through。

## 首要红线

- 禁止复制 parent EXPLANATION 生成 child node。
- 禁止继承 CENTER/TEMPORARY。
- 禁止为 inherited node 创建 per-graph title/layout/ink override。
- 禁止用 `source_questions[0]` 猜 inheritance parent。
- 禁止先做 UI mock 再补 canonical identity。
- 禁止破坏现有 command dedup、CAS、durable-before-ACK、body immutable、CENTER guard。
- 禁止为了迁移清空现有双端数据库或 iPad cache。
- 禁止在测试未通过时宣称完成。
