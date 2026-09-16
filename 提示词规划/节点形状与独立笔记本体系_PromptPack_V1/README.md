# 节点形状解耦 + 独立笔记本体系 Prompt 包 V1

本目录用于指导实现两项新增能力：

1. **节点类型（kind）与节点形状（shape）彻底解耦**；
2. **建立与复习系统完全独立的 Notebook / NotebookGraph 笔记体系**。

## 基线

实现前必须以本分支创建时的 `main` 为事实基线：

- Review QuestionGraph 已使用 `WORLD_V1` 世界坐标；
- Mac QuestionGraph canonical schema 当前为 v5；
- 双端 wire protocol 当前为 v3；
- iPad 已有 Canvas Pan / Node Drag / edge auto-pan / parent-child hierarchy；
- 复习系统已有 `QUESTION_BANK / REVIEW_CAPSULE / USER_AUTHORED` QuestionGraph；
- 复习系统已有 `user_graph_scheduler`，它仍属于复习域。

如果实现时 `main` 已继续演进，先重新读取当前代码，再把本 Prompt 中的语义契约映射到最新结构；禁止机械覆盖新实现。

## 本次最重要的两条边界

### A. 语义与视觉分离

```text
NodeKind  = 节点是什么、如何生命周期管理
NodeShape = 节点长什么样
```

两者不得相互推导。

### B. 复习系统与笔记系统零数据交集

```text
Review System                 Notebook System
─────────────                 ───────────────
QuestionGraph                 Notebook
QUESTION_BANK                 NotebookGraph
REVIEW_CAPSULE                NoteNode
USER_AUTHORED                 notebook.sqlite3
scheduler.sqlite3
DualEnd canonical DB
```

允许共享纯 UI/几何代码，但禁止共享业务数据、ID、数据库表、调度、继承或事件。

## 文件阅读顺序

1. `01_总控实施Prompt.md`
2. `02_节点形状解耦与ReviewGraph升级Prompt.md`
3. `03_独立Notebook数据层与SchemaPrompt.md`
4. `04_NotebookGraph与共享GraphUIPrompt.md`
5. `05_Notebook目录CLI与打印Prompt.md`
6. `06_测试迁移与边界验收Prompt.md`
7. `07_实施顺序与交付清单.md`

## V1 明确不做

- Notebook 自动进入复习调度；
- Review Graph 自动出现在 Notebook；
- Review Graph 与 NotebookGraph 共用 graph_id / node_id；
- 跨系统 FK；
- 跨系统自动同步；
- Notebook 嵌套；
- 标签系统；
- 一图多 Notebook；
- 多人协作 / 云同步；
- NotebookGraph 自动复习；
- 跨系统双向链接；
- 为了复用代码而让 NotebookGraph 直接复用 Review Graph 的 canonical 表。

## 最终验收一句话

> 两套系统可以“画得一样”，但必须“存得完全不同”；节点可以“语义相同但形状不同”，也可以“形状相同但语义不同”。
