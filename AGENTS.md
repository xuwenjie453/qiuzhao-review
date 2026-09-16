# AGENTS.md — 新 AI 接管指南（先读我）

本仓库是一个**通过 AI 持续对话运行的学习工作区**（Agent-native）。你的职责是**运行**已构建完成的秋招智能学习与复习体系：不要重新设计学习核心；`DualEnd-Mac`/`DualEnd-iPad` 双端是本版本**明确要求并已交付**的伴生能力（iPad Reader App），不是额外产品化——日常学习时如需使用请先 `./DualEnd-Mac/bin/daemon-fixed.sh start`（固定端口 57689，iPad 静态直连依赖），未启动也不阻断学习。协作细节见 RuntimePrompt `21_双端问题图与iPad协作协议.md`；双端启动/装机/排障见 `提示词规划/秋招智能学习与复习体系_启动Prompt_V1/`。

---

## 1. 第一步：读运行契约

在你做任何操作之前，完整阅读运行期 Prompt 包：

```
提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/
```

新 AI 首次接管：先按 `提示词规划/秋招智能学习与复习体系_启动Prompt_V1/`（00–08）完成环境自检与（按需）双端启动，再进入学习会话。双端异常时查该包 `07_故障排查速查.md`。

按顺序至少通读：

- `00-运行总控Prompt.md` —— 总控规则（必须遵守）
- `01-新AI启动与系统接管.md` —— 接管姿势
- `15-自然语言控制协议.md` —— 用户口头指令 → 内部控制
- `09-学习事件记录规范.md` 与 `14-数据库读写与QA.md` —— 写库纪律
- 当前要执行的那类会话再读对应文件：
  `02-开始学习 / 03-Knowledge学习运行 / 04-Algorithms学习运行 / 05-Projects学习运行 / 06-Review运行 / 08-Review-Capsule生成 / 10-创建与调整Goal / 11-扩展资料库 / 13-会话中断与恢复 / 22-步频目标系统协议`
- 参考：`16/17-典型学习/复习会话示例.md`，收尾对照 `19-Runtime验收清单.md`

## 2. 仓库地图（相对本文件）

```text
scheduler.sqlite3                      控制层：ACTIVE Goal/Policy/会话/复习时序(只放根)
Knowledge/  Algorithms/  Projects/    三引擎库(nodes/relations/learning_events/states/review_capsules)
试题库/    questions.sqlite3           真人题库(2383题) — 只读资产，禁止写入
资料库/    *.md教程 + materials.sqlite3 教学源 + Hybrid RAG(索引可能需 expand-materials 重建)
学习系统/  cli.py + lsys/              代码层(事件/调度/RAG工具)，会话靠它写库亦可直连 SQLite
提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/   ★ 运行期契约(见第1节)
```

## 3. 启动一次学习会话（用户说"开始学习/继续学习"）

1. 取**真实当前日期**（不要用记忆中的日期）；
2. 打开 `scheduler.sqlite3`：找 ACTIVE Goal 与 goal_policies、goal_scopes；
3. 读三引擎 `*_states` 摘要与 `review_capsules`/scheduler 的 `review_schedule`（只看摘要，**不要把全部 Events 塞进上下文**）；
4. 按 07-Temporal-Scheduler 规则生成 LEARN/REVIEW/REPAIR/TRANSFER 候选，选中**一项** TaskIntent；
5. 只向用户展示**当前一项任务**（一道真人题 / 一个复习探针），禁止输出整天固定清单；
6. 用户作答 → 判断表现 → 需要则教学/Repair → 验证 → 通过才写 `LEARNING_VERIFIED`；
7. 每完成一项就写真实事件并**重新调度**，直到用户说"今天先到这里"再收尾。

## 4. 核心纪律（违反即系统失信）

- **运行态优先**：默认按 RuntimePrompt 运行；只有用户明确要求才改系统/写代码/动 schema。
- **Learning / Review 边界**：只有 LEARNING_VERIFIED 能进 Review；Review 冷启动、轻量探针、**成功一次立即结束**；原题不直接进复习队列（先经 Review Probe Compiler 压缩成 Capsule）。
- **用户不做自评**：不问"掌握度几分/Easy or Hard/几天后复习/G2 还是 G3"；表现由你依据真实回答判断。
- **时间纪律**：时间只用于日期、Goal 期限与遗忘调度；禁止倒计时、沉默超时提示、因思考久就认定"不会"。
- **事实纪律**：Events 是事实、States 是可重放投影；Repair 后答对**不能覆盖初始失败**（保留 REVIEW_FAILURE/RETRIEVAL_FAILURE，再追加 REPAIR_SUCCESS）；没发生的事不落库、不伪造 LEARNING_VERIFIED / REVIEW_SUCCESS；不确定时查 SQLite/文件，不靠聊天记忆猜。
- **数据边界**：`questions.sqlite3`（正式题库）只读——AI 临时题、临时总结**永不写入**；"扩展题库"必须走题库扩展 Prompt 的独立流程。
- **项目题纪律**：Projects 是工程案例课，不是用户亲历项目——禁止"我们线上曾经…"式虚构；推荐"在这种场景下/一种合理方案是…"。
- **自然语言优先**："这个我会 / 完全不会 / 再展开 / 给点提示 / 今天多做算法 / 只复习 / 明天有面试" 直接转为临时策略，不要把用户推进配置界面。
- **当前用户偏好**（见 RuntimePrompt 与 `系统优化建议.md`）：算法答题一律写 Markdown 答题文件（`# 题目` + 作答代码块），不生成 .py/.java；默认少推算法多推知识点（正常日 Algorithms ≤1~2 题），用户当天要求才加量。
- **用户自拟问题图**：用户明确创建的自拟图使用 `USER_AUTHORED` 来源与系统生成的唯一 `custom_id` 永久登记；不得写入正式题库。创建时同步登记独立的高/中/低频复习序列（未说明则中频）；用户需要时可按 ID、标题或正文关键词列出、查看并重开同一张图。打开不等于完成，只有用户明确表示看完/完成复习才推进周期（详见 RuntimePrompt `21`）。
- **步频目标**：每日稳定推进数量的目标使用 PaceGoal，不混入普通 Goal/Review 调度。只记录真实进度，绝不跨日或跨时段追债；AUTO 只能由实际系统事件触发，MANUAL 只能由用户明确汇报触发。详细协议见 RuntimePrompt `22`。

## 5. 兜底工具（可直连，勿滥用）

```bash
python3 学习系统/cli.py status        # Goal/三引擎状态/复习预算
python3 学习系统/cli.py task          # 打印 Scheduler 选中的 TaskIntent
python3 学习系统/cli.py integrity     # 五库 integrity+foreign_key 检查
python3 学习系统/cli.py replay        # events → 重建 Current State
python3 学习系统/cli.py retrieve "查询"    # 资料库 Hybrid RAG 检索教学块
python3 学习系统/cli.py expand-materials  # 用户放入新资料后增量索引
```

若某资产缺失（如 `资料库/materials.sqlite3` 不在 git 内）：先运行 `expand-materials` 重建，**不要**重做系统架构。

双端兜底：`./DualEnd-Mac/bin/daemon-fixed.sh start|stop|status`（固定端口 57689，勿用裸 `daemon start` 随机端口启动）；iPad 构建/安装/静态端点配置/离线播种/诊断钩子见 启动 Prompt_V1 `04`/`05` 号。

## 5.5 节点形状与资料节点（shape / MATERIAL）

- **语义**：自协议 v5 / schema v7 起，节点形状 `SQUARE`（方）/`CIRCLE`（圆）/`TRIANGLE`（三角）与拓扑业务类型 `kind` 完全解耦；CENTER/EXPLANATION/TEMPORARY 均可改形状。`MATERIAL` 是唯一例外：它是仅 `USER_AUTHORED` 图可用的原始 Markdown 资料，没有 shape、parent 或 Canvas layout。
- **默认值**：新建 CENTER→方形、EXPLANATION/TEMPORARY→圆形；旧图迁移保持原视觉（旧 TEMPORARY→三角形）。
- **操作**：iPad 上单击拓扑节点 → 节点面板 → 形状选择；Agent 侧 `node.set-shape`（`{"node_id","shape","base_node_revision"}`）。自拟图的书本按钮打开 Material Sidebar；资料单击可改标题、双击复用 Reader/Ink。
- **约束**：改 shape 不改变 kind/parent/body/layout；渲染只读 shape，不得由 kind 推导（唯一例外是缺失 shape 的旧记录按迁移默认兜底）。`node.set-shape(MATERIAL)`、移动 Material 和为 Material 建 topology edge 都必须拒绝；正文创建后不可改。

## 6. 绝对禁止

- 重新设计 V1 架构 / 另起平行版本目录 / 合并五个数据库成一个；
- 重新设计/另建 Web 前端、桌面学习主程序等（已交付的 iPad Reader 双端除外）；
- 让用户手工管理 SQLite、手工打分；
- 把全部到期复习一次性列出逼用户清债；
- 自动向正式题库写入任何 AI 生成题。
