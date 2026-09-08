# 与现有 qiuzhao-review 的集成

## 1. 不改原核心职责

当前 repo 的关键边界：

- `试题库/questions.sqlite3`：正式题目索引，保持只读；
- `scheduler.sqlite3`：Goal/Policy/session/review scheduling；
- `Knowledge/Algorithms/Projects`：三引擎状态；
- `学习系统/lsys/`：现有确定性学习逻辑；
- Runtime Prompt：Agent 日常执行契约。

双端扩展是旁路 projection，不改变这些数据库的事实语义。

## 2. 接入点

### LEARN / REPAIR

当 TaskIntent 选中正式题并开始围绕题目教学/诊断时，Agent `question.open`。

### REVIEW

当 Review Capsule 生成具体 retrieval probe 并开始作答时，Agent 用 capsule/probe identity `question.open`。

### 用户追问

Agent 的回答仍直接在 Mac 会话输出。只有用户明确选中某段回答时才 `node.add`。

### task done / switch

Agent `question.close`。

## 3. 不强耦合 daemon 可用性

双端是体验增强。daemon 不可用时：

- 学习必须继续；
- 原 Learning Events 仍正常写；
- Agent 可简洁告知 iPad 同步不可用；
- 不伪造 node 已加入。

若用户明确要求加节点而 daemon offline，可选把操作写到本机 CLI pending file 后 daemon 启动再提交；v1 更简单的行为是明确失败并让 Agent 保留本轮上下文，daemon 恢复后用户可再次指令。
