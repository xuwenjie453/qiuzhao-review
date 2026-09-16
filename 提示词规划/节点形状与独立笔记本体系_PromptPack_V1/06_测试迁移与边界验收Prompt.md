# 06 测试、迁移与边界验收 Prompt

本步骤负责把“功能看起来能用”提升为“架构边界可证明”。

## 一、测试层级

至少覆盖三层：

1. **纯逻辑测试**：shape/default/WORLD_V1/目录关系；
2. **存储测试**：migration、SQLite、revision、membership；
3. **集成测试**：Review sync + Notebook isolation + CLI tree。

如果已有 iPad UI tests，再补少量关键交互；不要依赖纯手工冒烟作为唯一证据。

---

## 二、Review Shape migration 验收

从 schema v5 fixture/临时库升级到新 schema：

旧数据：

```text
CENTER
EXPLANATION
TEMPORARY
```

升级后必须得到：

```text
CENTER       + SQUARE
EXPLANATION  + CIRCLE
TEMPORARY    + TRIANGLE
```

同时保持：

- graph_id 不变；
- node_id 不变；
- parent_node_id 不变；
- body 不变；
- x_world/y_world 不变；
- layout_revision 不变；
- ink 不变；
- graph inheritance 不变。

新创建 TEMPORARY 则必须是 CIRCLE。

---

## 三、Shape 不变量测试

对每种 kind × shape 组合验证：

```text
CENTER + SQUARE/CIRCLE/TRIANGLE
EXPLANATION + SQUARE/CIRCLE/TRIANGLE
TEMPORARY + SQUARE/CIRCLE/TRIANGLE
```

至少 service/domain 层应允许全部组合。

修改 shape 前后断言：

```text
kind unchanged
parent unchanged
body unchanged
layout unchanged
round unchanged
```

只允许：

```text
shape changed
node_revision advanced
graph_revision advanced
```

---

## 四、Notebook isolation 测试

这是本轮最重要测试。

### Test A：Notebook 无 Review DB 也能运行

测试环境只创建 `notebook.sqlite3`，不提供：

```text
dual-end.db
scheduler.sqlite3
questions.sqlite3
```

Notebook CRUD / Graph CRUD / tree 必须工作。

### Test B：Review 无 Notebook DB 也能运行

删除/不创建 notebook DB，原 Review QuestionGraph 测试必须通过。

### Test C：同名/同内容不产生关联

分别在 Review 和 Notebook 创建：

```text
title = Redis持久化
body = 相同文本
```

断言：

```text
graph_id 不同
node_id 不同
数据库不同
修改互不影响
```

### Test D：Review USER_AUTHORED 不进入 Notebook tree

在 Review DB 创建多个 USER_AUTHORED graph，Notebook tree 输出必须完全忽略。

### Test E：NotebookGraph 不进入 scheduler

创建/编辑/打开/移动 NotebookGraph 前后，scheduler 相关表无新增 review schedule/event。

---

## 五、Graph UI 回归

Review：

- node drag；
- canvas pan；
- frozen gesture ownership；
- edge auto-pan；
- parent-child rendering；
- inherited node；
- optimistic pending move；
- offline cache；
- shape picker。

Notebook：

- node drag；
- canvas pan；
- edge auto-pan；
- parent-child rendering；
- shape picker；
- reopen 后位置/shape 持久化。

尤其验证：

```text
改变 shape 不应改变 node center
```

因此方/圆/三角之间切换不能让 layout 漂移。

---

## 六、CLI tree 验收数据集

构造：

```text
Notebook A
  Graph 1
  Graph 2
Notebook B
  Graph 3
Notebook C (empty)
Unfiled
  Graph 4
  Graph 5
```

同时在 Review DB 构造：

```text
QUESTION_BANK graph
REVIEW_CAPSULE graph
USER_AUTHORED graph
```

最终 `notebook tree` 只能出现 Graph 1~5。

删除 Notebook A 后：

```text
Graph 1/2 -> Unfiled
```

Graph 本体、节点、布局保持存在。

---

## 七、协议/兼容性验收

如果 Review wire protocol 因 shape 升级：

- 旧客户端被明确拒绝；
- 新客户端 shape round-trip；
- snapshot/patch fixtures 更新；
- MOVE_NODE WORLD_V1 不受影响；
- ACK/replay/dedup 不受影响。

如果不升级：

必须有测试证明 v3 客户端完整理解 shape，不允许仅凭“JSON 可多字段”判断兼容。

Notebook 若 V1 没有跨设备同步，不要擅自加入 Review wire protocol。

---

## 八、静态边界审计

在最终交付前搜索代码确认：

### Review 侧不得出现

```text
notebook.sqlite3
notebook_graph_membership
NotebookGraph store import
```

### Notebook 侧不得出现

```text
review_schedule
user_graph_scheduler
QUESTION_BANK
REVIEW_CAPSULE
review graph inheritance
DualEnd Review ClientStore
```

共享 UI 文件允许出现：

```text
NodeShape
GraphCanvasGeometry
GraphNodePresentation
```

但不应 import 任一具体 store。

---

## 九、最终验收表

必须逐项回答 PASS/FAIL：

```text
[ ] NodeKind 与 NodeShape 已完全剥离
[ ] 旧 Review 图视觉保持
[ ] 新 CENTER 默认方形
[ ] 新非 CENTER 默认圆形
[ ] 任意 Review node 可选三形状
[ ] Notebook 有独立 DB
[ ] NotebookGraph 不复用 Review graph identity
[ ] Notebook 不写 scheduler
[ ] Review 不读 Notebook 数据
[ ] Notebook tree 只列 NotebookGraph
[ ] 未归档正确
[ ] 删除 Notebook 不删除 Graph
[ ] Shared Graph UI 不依赖具体 store
[ ] WORLD_V1/pan/drag 没有回归
[ ] 自动测试通过
```

任一核心项 FAIL 都不得宣称完成。
