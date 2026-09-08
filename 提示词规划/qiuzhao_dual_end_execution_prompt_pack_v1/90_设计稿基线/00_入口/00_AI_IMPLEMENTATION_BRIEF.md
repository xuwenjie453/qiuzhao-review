# AI Implementation Brief

## 1. 你正在实现什么

这是 `qiuzhao-review` 的**双端扩展**。Mac 仍是学习会话发生地：用户和 Codex/ZCode 一类 Agent 围绕一道题讨论；iPad 是只读内容 + 手写批注终端。

最基本业务对象是 `Question`，来源只有两类：

- `QUESTION_BANK`：现有试题库问题。
- `REVIEW_CAPSULE`：复习胶囊中的问题/探针问题。

每一道问题映射一个稳定 `QuestionGraph`。图中只有三类节点：

| 类型 | 形状 | 生命周期 | 正文 | 标题 | 删除 |
|---|---|---|---|---|---|
| `CENTER` | 正方形 | 永久 | 问题正文，只读 | 可改 | 禁止 |
| `EXPLANATION` | 圆形 | 永久 | 用户选中的 AI 原解释，只读 | 可改 | 可删 |
| `TEMPORARY` | 三角形 | 当前讨论轮次 | 用户选中的 AI 原解释，只读 | 可改 | 可删；轮次结束自动移出 |

**解释不能自动入图。**只有用户明确表达“把这段/刚才那个解释加入问题图”或“作为临时节点加入”时，Agent 才可调用 add-node 命令。

## 2. 现有系统保持什么不变

不要替换：

- Goal Compiler；
- Temporal Scheduler；
- D/S/R 记忆逻辑；
- Knowledge / Algorithms / Projects 三引擎；
- Learning Events / State Projection；
- Review Capsule / Review Schedule；
- questions.sqlite3 只读边界；
- 资料库 Hybrid RAG。

新增子系统不得把 iPad UI 状态写进这些学习数据库。

## 3. 新增的四个主要组件

### A. Agent Adapter

运行期 Prompt 要求 Agent 在以下时刻显式发命令：

- 开始讨论问题：`question.open`
- 用户明确要把解释加入：`graph.node.add`
- 当前问题讨论结束/切题：`question.close`

Agent 负责语义识别“用户指的是哪段解释”，Daemon 不做自动挑选。

### B. DualEnd Mac Daemon

职责：

- 新增问题图 Canonical Store；
- 接受本机 Agent 命令；
- 维护当前 active question round；
- Bonjour 广播 `_qiuzhaoreview._tcp`；
- 接受 iPad WebSocket；
- Graph Snapshot/Patch 推送；
- 接受 iPad 的标题、位置、删除、Ink 更新；
- 幂等、revision、journal、ACK。

### C. iPad Reader

两层：

1. `QuestionGraphView`：三种形状、标题、拖动、单击管理、双击进入。
2. `NodeReaderView`：Markdown 固定正文 + 透明 PencilKit Ink Layer + 纵向滚动。

### D. Sync Engine

iPad 本地 durable first。网络动作先入 outbox；服务器收到命令先落盘再 ACK。Snapshot/Patch 采用 revision 检查；重复 `message_id` one effect。

## 4. 关键身份

```text
question_key    稳定标识一道业务问题
  qb:<question_id>
  capsule:<capsule_id>:<probe_key>

graph_id        H(question_key) 的稳定 ID
round_id        每次“开始围绕该问题讨论”创建的新 UUID
node_id         永久 UUID；同一节点重开问题仍不变
session_epoch   每次 iPad↔Mac WebSocket 会话的新 UUID
message_id      每条 wire message UUID，用于 dedup
```

临时节点必须携带 `round_id`。新一轮打开同一图时，只返回当前 `round_id` 的 TEMPORARY；历史临时节点永不复活。

## 5. 正文与标题

- CENTER body：题目本身的 Markdown 快照。
- EXPLANATION/TEMPORARY body：**用户指定的那段 AI 原解释的原文 Markdown**。不能为了“整理”而改写。
- 初始 title：由当前 Agent 概括生成；Daemon 不调用另一个 LLM。
- iPad 可改 title，不能改 body。
- body 一经 node commit 即 immutable。

## 6. 零手动配对

参考 reading-system 的 Bonjour + WebSocket，但移除 6 位配对：

- daemon 启动即广播；
- iPad 启动即浏览；
- 发现兼容服务后自动连接；
- 首次连接自动记录 daemon stable id；
- 后续优先重连同一 daemon；
- 多 daemon 情况也必须自动选，不要求 IP/验证码。

这意味着 v1 的信任边界是“可信个人 LAN”。参见安全 ADR。

## 7. Apple Pencil

使用原生 PencilKit。`PKDrawing` 是笔迹真源；每 node 一份 drawing。写入本地 SQLite/blob 后再同步 Mac。离开页面、App 进入后台时必须立即 flush。

Apple Pencil 双击通过 `UIPencilInteraction` 切换 `ink ↔ eraser`。第一代 Pencil 本身不支持双击，不能以模拟器或不支持的 Pencil 作为该验收项失败依据。

## 8. 绝不能做的事

- 不自动把解释加入图。
- 不允许 iPad 修改正文。
- 不允许删除 CENTER。
- 不把上一轮 TEMPORARY 带到下一轮。
- 不为了双端 UI 改写 Scheduler 数学模型。
- 不要求用户输入 IP、端口、验证码。
- 不在未 durable apply 前 ACK。
- 不用“最后写入覆盖一切”破坏 immutable body。
