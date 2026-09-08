# 双端问题图与 iPad 协作协议（Dual-End Contract）

本文件定义 Runtime Agent 与 `DualEnd-Mac` 守护进程的协作边界。Mac 仍是学习会话发生地；iPad 是**只读正文 + 手写批注**终端。问题图（QuestionGraph）是双端唯一业务对象。

## 一、何时发命令（MUST 时机）

| 时机 | 命令 |
|---|---|
| TaskIntent 选中正式题并开始教学/诊断（LEARN/REPAIR） | `question.open` |
| Review Capsule 生成具体 retrieval probe 并开始作答 | `question.open`（以 capsule/probe identity） |
| 用户**明确**要某段解释入图 | `graph.add-node` |
| 本题结束 / 切换到下一题 | `question.close` |

## 二、硬性规则（违反即失信）

1. **解释不自动入图**：Agent 的普通回答不产生任何节点。只有用户明确表达"把刚才这段/这个解释加入问题图"时才能调用 `graph.add-node`。
2. **body 用原解释原文**：`body_markdown` 必须是用户指中的那段 assistant 原文，禁止"整理改写"。
3. **title 可概括**：由 Agent 生成，建议 4–18 个中文字符。
4. **daemon 不在线不阻断学习**：命令失败时告知"iPad 同步暂不可用"，继续正常学习与事件落库；禁止伪造"节点已加入"。
5. 命令幂等：每次命令带新 `command_id`（UUID）。

## 三、CLI（Agent 使用；禁止直写 SQLite）

```bash
# daemon 需先启动(常驻)
node DualEnd-Mac/bin/qreview-dual.mjs daemon start
node DualEnd-Mac/bin/qreview-dual.mjs daemon status

# 开题
node DualEnd-Mac/bin/qreview-dual.mjs question open --json /tmp/open.json
# open.json:
# {
#   "question_ref": {"source": "QUESTION_BANK", "question_key": "qb:<question_id>", "source_id": "<question_id>"},
#   "question_body_markdown": "<题干原文 Markdown>",
#   "ai_title": "<4-18字>"
# }
# REVIEW 来源:
#   "question_ref": {"source": "REVIEW_CAPSULE", "question_key": "capsule:<capsule_id>:<probe_key>", "source_id": "<capsule_id>", "probe_key": "<probe_key>"}

# 把用户明确选中的解释加入
node DualEnd-Mac/bin/qreview-dual.mjs graph add-node --json /tmp/add.json
# add.json:
# { "round_id": "<open 返回>", "node_kind": "EXPLANATION",  // 或 TEMPORARY(仅本轮可见)
#   "ai_title": "...", "body_markdown": "<解释原文>" }

# 结束本题
node DualEnd-Mac/bin/qreview-dual.mjs question close --round <round_id>

# 查看当前图
node DualEnd-Mac/bin/qreview-dual.mjs graph snapshot
```

## 四、节点语义

| kind | 形状 | 生命周期 | 说明 |
|---|---|---|---|
| `CENTER` | 正方 | 永久 | 问题正文快照；title 可改；不可删 |
| `EXPLANATION` | 圆 | 永久 | 用户选中的 AI 解释原文；不可改 body |
| `TEMPORARY` | 三角 | 仅当前轮次 | 用户显式加；`question.close` 后自动移出，下轮不复活 |

iPad 端只能：拖动布局、改 title、删除非 CENTER 节点、Apple Pencil 手写（ink 按 `node_id` 永久绑定）。**iPad 不参与 Agent 对话、不能改正文。**

## 五、Agent 启动时

若本机 daemon 未运行，学习会话开始时可选提示："问题图同步未启动（可选）：`node DualEnd-Mac/bin/qreview-dual.mjs daemon start`"。未启动不视为错误，学习照常。
