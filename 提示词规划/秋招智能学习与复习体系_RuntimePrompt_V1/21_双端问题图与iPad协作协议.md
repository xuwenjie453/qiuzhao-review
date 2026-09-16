# 双端问题图与 iPad 协作协议（Dual-End Contract）

本文件定义 Runtime Agent 与 `DualEnd-Mac` 守护进程的协作边界。Mac 仍是学习会话发生地；iPad 是**只读正文 + 手写批注**终端。问题图（QuestionGraph）是双端唯一业务对象。

## 一、何时发命令（MUST 时机）

| 时机 | 命令 |
|---|---|
| TaskIntent 选中正式题并开始教学/诊断（LEARN/REPAIR） | `question.open` |
| Review Capsule 生成具体 retrieval probe 并开始作答 | `question.open`（以 capsule/probe identity；有明确主来源时声明 `inherit_from`） |
| 用户**明确**要某段解释入图 | `graph.add-node` |
| 用户明确解析/抽取某个现有节点的部分内容，并作为子节点入图 | 读取父节点正文后用 `graph.add-node`，传 `parent_node_id` |
| 用户明确要把文本、一个 Markdown 文件或一个 Markdown 文件夹加入**当前自拟图** | 创建一个或多个 `MATERIAL`；保留原 Markdown，不自动总结 |
| 本题结束 / 切换到下一题 | `question.close` |
| 用户明确要创建自拟问题图 | `custom create` |
| 用户要查看/重开自拟问题图 | `custom list/show/open` |

## 二、硬性规则（违反即失信）

1. **解释不自动入图**：Agent 的普通回答不产生任何节点。只有用户明确表达"把刚才这段/这个解释加入问题图"时才能调用 `graph.add-node`。
2. **普通加入时 body 用原解释原文**：用户说“把刚才这段解释加入图”时，`body_markdown` 必须是所指 assistant 原文，禁止"整理改写"。
3. **解析节点例外（范围严格）**：仅当用户明确要求“解析/抽取某个现有节点中的某主题，并作为子节点加入图”时，Agent 才能读取该父节点正文，跨段收集、压缩和重组为自包含解释；不得修改父正文，也不得把父节点之外的新知识伪装成抽取结果。新节点仍是 `EXPLANATION`，并传 `parent_node_id=<父节点>`。普通“展开讲讲/总结一下”不自动触发此例外。
4. **title 可概括**：由 Agent 生成，建议 4–18 个中文字符。
5. **daemon 不在线不阻断学习**：命令失败时告知"iPad 同步暂不可用"，继续正常学习与事件落库；禁止伪造"节点已加入"。
6. 命令幂等：每次命令带新 `command_id`（UUID）。
7. 正式 LEARN/REPAIR 继续以 `QUESTION_BANK` 开题；Review 继续以 `REVIEW_CAPSULE` 开题。若 Capsule 有明确 `primary_source_question_id`，Agent 在 `question.open` 中声明对应的 `inherit_from`（`QUESTION_BANK` / `qb:<question_id>`）。
8. Agent 禁止读取 parent Explanation 后逐个 `graph.add-node` 复制到 Review 图；继承节点由 GraphService effective view 决定。
9. Review 中对 inherited Explanation 的 rename/move/Ink 作用于共享 canonical node；删除 inherited node 按 global shared delete 理解，iPad 负责最终明确确认。
10. parent graph 缺失不阻塞当前 Review；不伪造历史 Explanation。Review 自己新增的 Explanation 只归当前 Review 图，不回写原题图；inherited 节点不能作为当前图 OWN 子节点的 parent。
11. **自拟图永久登记**：用户明确提出自拟问题时，以 `USER_AUTHORED` 来源创建，系统生成唯一 `custom_id`；不得伪装成正式题、不得写入 `questions.sqlite3`。以后按 ID、标题或正文关键词检索并重新打开同一张图，保留其布局、解释节点与笔迹。
12. **自拟图独立调度**：创建时必须登记 HIGH/MEDIUM/LOW 之一；用户未说明时默认 MEDIUM。时序写入根 `scheduler.sqlite3` 的独立表，不进入正式 `review_schedule`，也不生成 Review Capsule。
13. **完成边界**：`user-graph-open` 只记录 `REVIEW_SHOWN`，绝不推进周期；只有用户明确说“看完了/完成复习”才记录 `REVIEW_COMPLETED` 并计算下一次到期。到期只是候选，一次只呈现一张，用户跳过时保持原到期状态。
14. **资料节点只由用户显式导入**：`MATERIAL` 只能创建在当前 `USER_AUTHORED` 图。文本、`.md` 或 Markdown 文件夹导入时逐份原样保存为独立节点；禁止自动摘要、自动创建 `EXPLANATION`、自动解析父子结构或加入复习调度。正文创建后不可改，标题可改；内容实质变化时新建资料，不覆盖旧资料。

## 三、自拟图周期序列

| 频率 | 间隔序列（天） | 末档行为 |
|---|---|---|
| HIGH / 高频 | `1 → 2 → 4 → 7 → 14 → 30` | 每 30 天 |
| MEDIUM / 中频 | `3 → 7 → 14 → 30 → 60` | 每 60 天 |
| LOW / 低频 | `7 → 21 → 45 → 90` | 每 90 天 |

创建/改频时把序列快照写入该图的 schedule，避免未来默认参数变化静默改写已有计划。改频保留历史复习次数，并按新序列的对应阶段继续。

## 四、CLI（Agent 使用；禁止直写 SQLite）

```bash
# daemon 需先启动(常驻; 固定端口 57689 —— iPad 端静态直连依赖该端口)
./DualEnd-Mac/bin/daemon-fixed.sh start     # 固定端口启动(含孤儿 Bonjour 广播清理)
./DualEnd-Mac/bin/daemon-fixed.sh status

# 开题
node DualEnd-Mac/bin/qreview-dual.mjs question open --json /tmp/open.json
# open.json:
# {
#   "question_ref": {"source": "QUESTION_BANK", "question_key": "qb:<question_id>", "source_id": "<question_id>"},
#   "question_body_markdown": "<题干原文 Markdown>",
#   "ai_title": "<4-18字>"
# }
# REVIEW 来源：同一 capsule 无论本次 Probe 如何措辞，都复用同一张问题图。
#   "question_ref": {"source": "REVIEW_CAPSULE", "question_key": "capsule:<capsule_id>", "source_id": "<capsule_id>", "probe_key": "<probe_key>"}
#   "inherit_from": {"source": "QUESTION_BANK", "question_key": "qb:<primary_source_question_id>", "source_id": "<primary_source_question_id>"}
# probe_key 仅描述本轮 retrieval probe，不参与 QuestionGraph 身份；CENTER 保留首次开题正文快照。

# 把用户明确选中的解释加入
node DualEnd-Mac/bin/qreview-dual.mjs graph add-node --json /tmp/add.json
# add.json:
# { "round_id": "<open 返回>", "node_kind": "EXPLANATION",  // 或 TEMPORARY(仅本轮可见)
#   "parent_node_id": "<可选；未传默认 CENTER，TEMPORARY 不可自定义>",
#   "ai_title": "...", "body_markdown": "<解释原文或明确解析后的子解释>" }

# 结束本题
node DualEnd-Mac/bin/qreview-dual.mjs question close --round <round_id>

# 查看当前图
node DualEnd-Mac/bin/qreview-dual.mjs graph snapshot

# 自拟图的原始 Markdown 资料（当前图必须已有 ACTIVE round）
# add-material.json: {"round_id":"...", "ai_title":"...", "body_markdown":"原始 Markdown"}
node DualEnd-Mac/bin/qreview-dual.mjs graph add-material --json /tmp/add-material.json
node DualEnd-Mac/bin/qreview-dual.mjs graph import-markdown --round <round_id> --file <file.md> [--title <title>]
node DualEnd-Mac/bin/qreview-dual.mjs graph import-folder --round <round_id> --dir <folder>
node DualEnd-Mac/bin/qreview-dual.mjs graph materials --graph <graph_id>

# 自拟问题图（create.json: {"title":"...","body_markdown":"..."}）
# 统一入口会同时创建 canonical 图与独立 schedule
python3 学习系统/cli.py user-graph-create --json /tmp/create.json --frequency high
python3 学习系统/cli.py user-graph-due --limit 1
python3 学习系统/cli.py user-graph-open --id <custom_id>
python3 学习系统/cli.py user-graph-complete --id <custom_id>
python3 学习系统/cli.py user-graph-frequency --id <custom_id> --frequency low
python3 学习系统/cli.py user-graph-list

# 底层图查询入口（只查图，不推进 schedule）
node DualEnd-Mac/bin/qreview-dual.mjs custom list [--query <标题或正文关键词>]
node DualEnd-Mac/bin/qreview-dual.mjs custom show --id <custom_id>
node DualEnd-Mac/bin/qreview-dual.mjs custom open --id <custom_id>
```

## 五、节点语义

| kind | 形状 | 生命周期 | 说明 |
|---|---|---|---|
| `CENTER` | 正方 | 永久 | 问题正文快照；title 可改；不可删 |
| `EXPLANATION` | 圆 | 永久 | 默认连 CENTER；也可在创建时连同图的 CENTER/EXPLANATION 父节点；不可改 body |
| `TEMPORARY` | 三角 | 仅当前轮次 | 固定连 CENTER；用户显式加；`question.close` 后自动移出，下轮不复活 |
| `MATERIAL` | 不适用 | 永久 | 仅自拟图的原始 Markdown 资料；无 parent、无 Canvas layout、无 topology edge；正文不可改，标题可改 |

iPad 上自拟图工具栏显示“资料”书本按钮：左侧目录只列 `MATERIAL`；单击打开节点信息（只可改标题/删除），双击进入现有 Reader/Apple Pencil 批注。`MATERIAL` 不渲染到 Canvas，也不能拖动或改形状。其余拓扑节点可拖动、改 title、删除非 CENTER 节点、修改形状并手写批注。**iPad 不参与 Agent 对话、不能改正文。**

> **节点形状（shape，协议 v4 / schema v6 起）**：shape 与 kind 正交——`SQUARE`（方形）/ `CIRCLE`（圆形）/ `TRIANGLE`（三角形），**任意节点含 CENTER 都可改**。
> 新建默认：CENTER→SQUARE，EXPLANATION/TEMPORARY→CIRCLE；旧图迁移后保持原视觉（旧 TEMPORARY=TRIANGLE）。
> 用户说"把某节点改成圆形/三角形"时：iPad 端直接在节点面板改；Agent 侧用 `node.set-shape`（`{"node_id","shape","base_node_revision"}`）。改 shape 不改变 kind/parent/body/layout。
> `MATERIAL` 是唯一例外：没有 shape；`node.set-shape(MATERIAL)` 与 topology move 必须被 domain service 拒绝。

## 六、Agent 启动时

若本机 daemon 未运行，学习会话开始时可选提示："问题图同步未启动（可选）：`./DualEnd-Mac/bin/daemon-fixed.sh start`"。未启动不视为错误，学习照常。
