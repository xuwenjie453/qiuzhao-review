# 01 — 总控实现 Prompt

你现在负责在本仓库实现两项 QuestionGraph 功能。你的目标不是提出方案，而是**在现有 V1 架构内完成可审计、可迁移、可测试的实现**。

## 一、开始前必须完成

1. 确认你位于独立 feature branch，**禁止直接在 `main` 上开发**。
2. 完整阅读：
   - `AGENTS.md`
   - `提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/00-运行总控Prompt.md`
   - `提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/15-自然语言控制协议.md`
   - `提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/21_双端问题图与iPad协作协议.md`
3. 阅读本 Prompt 包全部文件。
4. 审计当前实现，至少打开：
   - `DualEnd-Mac/src/store/state-db.mjs`
   - `DualEnd-Mac/src/graph/question-graph-service.mjs`
   - `DualEnd-Mac/src/daemon.mjs`
   - `DualEnd-Mac/test/graph.test.mjs`
   - `DualEnd-iPad/QiuZhaoReader/Domain/Models.swift`
   - `DualEnd-iPad/QiuZhaoReader/Protocol/GraphCodec.swift`
   - `DualEnd-iPad/QiuZhaoReader/Store/ClientStore.swift`
   - `DualEnd-iPad/QiuZhaoReader/Topology/QuestionGraphView.swift`
   - `DualEnd-iPad/QiuZhaoReader/Topology/GraphCanvasGeometry.swift`
   - iPad 现有相关 tests。
5. 在改代码前，用简短内部清单确认当前代码与本包描述的差异；若仅有命名/局部结构漂移，适配当前代码，不另起新架构。

## 二、必须实现的最终用户行为

### A. 空白拖动画布

- 手指/指针从**空白区域**开始拖动：节点 + 连线作为整体在 iPad 本地 viewport 中移动。
- 手势从节点上开始：保持节点自己的点击/双击/拖动语义，不触发画布 pan。
- 边缘节点可以通过 pan 到达屏幕中心附近，且图不能被无限甩到不可恢复区域。
- pan 只是本地观察状态：**不得**修改 canonical node layout、不得发 `MOVE_NODE`、不得改变 graph/node/layout revision、不得写 Mac DB。
- 在已经 pan 过的画布上继续拖节点，写回的 normalized canonical 坐标必须正确，不受 viewport offset 污染。

### B. 解释节点指定父节点

- `graph.add-node` 创建 `EXPLANATION` 时接受可选 `parent_node_id`。
- 未提供：自动使用当前 graph 的 CENTER。
- 明确提供：父节点必须存在、未删除、与当前 canonical graph 相同，且 kind 只能是 `CENTER` 或 `EXPLANATION`。
- `TEMPORARY` 保持旧语义：默认挂 CENTER；V1 不允许为 TEMPORARY 指定自定义 parent，若调用方显式传非空 `parent_node_id` 必须返回 validation error，而不是静默忽略。
- 不允许把 inherited node 当作当前 graph 新 OWN explanation 的 parent，因为其 `graph_id` 不等于当前 graph。
- snapshot、ADD_NODE patch、iPad durable cache 都必须保留 `parent_node_id`。
- UI 连线从“CENTER → 所有非中心节点”改成“resolved parent → child”。
- parent 缺失/不可见时只在 presentation 层 fallback CENTER；不得偷偷修改 canonical parent。

### C. 解析节点

“解析节点”不是新节点 kind，也不是新 GraphService command。

用户明确提出类似：

> 解析这个节点，把其中关于“Chunks 有哪些实现方式”的内容抽出来。

Agent 应：

1. 读取用户指定父节点正文；
2. 围绕目标主题跨段收集相关信息；
3. 允许重新组织、压缩、重写为一个自包含解释；
4. **不修改父节点正文**；
5. 用普通 `graph.add-node` 创建 `EXPLANATION`，并传 `parent_node_id=<被解析节点>`。

普通“把刚才这段解释加入图”的行为仍遵守 RuntimePrompt 21 的“body 使用用户选中 assistant 原文”规则。只有用户明确要求解析/抽取现有节点内容时，才允许上述重新组织例外。

## 三、严格禁止

不要实现以下内容：

- `PARSED_NODE` / `CHILD_EXPLANATION` 等新 kind；
- 通用 edges 表、relation type、多 parent；
- reparent、拖线连接、图编辑器；
- 删除父节点时级联删除 children；
- 抽取后从父节点正文删除对应文本；
- 自动把一个长节点批量拆成若干子节点；
- 将 canvas pan 写入 Mac canonical、SQLite 或同步协议；
- 为完成任务大规模重构 QuestionGraph；
- 修改 `questions.sqlite3` 或正式题库内容。

## 四、实现顺序（不得打乱依赖）

1. 完成 `02_基线审计与不可破坏契约.md`。
2. 独立完成 Canvas Pan（`03`），先保证不触碰 canonical。
3. 实现 Mac parent canonical/schema（`04`）。
4. 实现 iPad parent protocol/cache/render（`05`）。
5. 最小修改 RuntimePrompt/自然语言行为（`06`）。
6. 执行兼容性矩阵、测试和最终审计（`07`）。

## 五、提交纪律

优先按逻辑阶段形成小而可审计的 commits，例如：

```text
feat(iPad): add local question graph canvas pan
feat(graph): persist explanation parent relationships
feat(iPad): render and cache parent-child graph links
docs(runtime): define explicit node parsing behavior
test(graph): cover hierarchy and pan compatibility
```

不要把无关格式化或重构混进功能提交。

## 六、完成定义

只有在 `07` 的 Must 验收项全部满足后才可以声称“实现完成”。如果某测试因环境不可运行，必须写清：

- 哪个测试未运行；
- 原因；
- 做了哪些静态替代检查；
- 仍残留什么风险。

禁止把“代码看起来正确”表述成“已通过真机/Xcode 测试”。
