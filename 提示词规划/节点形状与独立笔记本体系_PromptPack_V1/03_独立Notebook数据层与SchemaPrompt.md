# 03 独立 Notebook 数据层与 Schema Prompt

本步骤创建全新的笔记系统 canonical 数据层。

## 一、硬边界

Notebook System 与 Review System 数据完全隔离。

必须满足：

```text
Notebook DB 不 ATTACH review DB 做业务写入
Review DB 不引用 notebook DB
scheduler.sqlite3 不保存 notebook/NotebookGraph
notebook.sqlite3 不保存 review schedule/event
```

NotebookGraph 不得复用 Review QuestionGraph 的 `graphs/nodes/layouts` 行，也不得复用 review USER_AUTHORED graph identity。

---

## 二、数据库位置

建议独立路径：

```text
系统数据/notebook/notebook.sqlite3
```

如果项目已有更统一的 data root 约定，可按现有约定放置，但必须仍是独立 DB 文件。

建议新增独立模块目录，例如：

```text
Notebook-Mac/
```

或在现有 Mac 工程下建立明确隔离的 `src/notebook/` 子域。

重点不是目录名，而是业务与 store 分离。

---

## 三、V1 Schema

建议最小表：

```sql
notebooks(
  notebook_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
```

```sql
note_graphs(
  graph_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  center_node_id TEXT NOT NULL UNIQUE,
  graph_revision INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
```

```sql
note_nodes(
  node_id TEXT PRIMARY KEY,
  graph_id TEXT NOT NULL REFERENCES note_graphs(graph_id) ON DELETE CASCADE,
  parent_node_id TEXT REFERENCES note_nodes(node_id),
  kind TEXT NOT NULL CHECK(kind IN ('CENTER','EXPLANATION')),
  shape TEXT NOT NULL CHECK(shape IN ('SQUARE','CIRCLE','TRIANGLE')),
  title TEXT NOT NULL,
  body_markdown TEXT NOT NULL,
  node_revision INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
```

```sql
note_layouts(
  node_id TEXT PRIMARY KEY REFERENCES note_nodes(node_id) ON DELETE CASCADE,
  x_world REAL NOT NULL,
  y_world REAL NOT NULL,
  layout_revision INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
)
```

```sql
notebook_graph_membership(
  notebook_id TEXT NOT NULL REFERENCES notebooks(notebook_id) ON DELETE CASCADE,
  graph_id TEXT NOT NULL REFERENCES note_graphs(graph_id) ON DELETE CASCADE,
  position INTEGER NOT NULL DEFAULT 0,
  added_at TEXT NOT NULL,
  PRIMARY KEY(notebook_id, graph_id),
  UNIQUE(graph_id)
)
```

如 NotebookGraph V1 需要手写，再加独立 `note_ink`；不要复用 review ink 表。

---

## 四、NotebookGraph 节点语义

V1 只定义：

```text
CENTER
EXPLANATION
```

暂不引入 TEMPORARY，因为笔记系统没有 round 生命周期。

默认 shape：

```text
CENTER -> SQUARE
EXPLANATION -> CIRCLE
```

但二者之后都可改成任意 `SQUARE/CIRCLE/TRIANGLE`。

父子规则：

- CENTER parent=NULL；
- EXPLANATION 默认 parent=CENTER；
- EXPLANATION 可以挂同一 NotebookGraph 内的 CENTER/EXPLANATION；
- 禁止跨图 parent；
- 删除 parent 时展示层可 fallback CENTER，或 service 层显式级联/重挂；选择一种并写死测试，不要产生悬空不可解释状态。

---

## 五、Notebook membership

V1：一张 NotebookGraph 最多属于一个 Notebook。

通过：

```text
UNIQUE(graph_id)
```

保证。

未归档图不是实际 notebook 行，而是：

```text
note_graphs 中不存在 membership 的 graph
```

因此不要创建名称固定为“未归档”的数据库 notebook。

---

## 六、Notebook service API

至少实现纯业务 service：

```text
createNotebook(title)
renameNotebook(id,title)
deleteNotebook(id)
listNotebooks()
getNotebook(id)

createGraph(title, centerBody, notebookId?)
renameGraph(id,title)
deleteGraph(id)
moveGraphToNotebook(graphId, notebookId)
removeGraphFromNotebook(graphId)
getGraph(graphId)
listUnfiledGraphs()
```

删除 Notebook：

```text
只删除 membership + notebook
不删除 NotebookGraph
Graph 自动成为未归档
```

因此如果 FK 使用 ON DELETE CASCADE，只能让它级联 membership，绝不能级联 note_graphs。

---

## 七、Revision / mutation

NotebookGraph 可以借鉴 Review CAS 设计，但不要直接复用 Review command_dedup/sync_journal 表，除非 Notebook 自己确有同步需求。

V1 最低要求：

- node_revision；
- layout_revision；
- graph_revision；
- shape/title/layout 修改可检测陈旧写入。

如果 V1 只有本机单 writer，可以保持实现轻量；不要为了“看起来一致”把 Review 的整个网络同步状态机复制过来。

---

## 八、ID

Notebook：独立 `notebook_id`。
NotebookGraph：独立 `graph_id`。
NoteNode：独立 `node_id`。

禁止使用：

```text
review graph_id
review node_id
question_id
capsule_id
custom_id
```

作为 Notebook canonical identity。

即使用户创建了同名内容，也必须是独立对象。

---

## 九、测试

至少覆盖：

1. Notebook CRUD；
2. NotebookGraph CRUD；
3. 一 Notebook 多 Graph；
4. 一 Graph 不可同时归入两个 Notebook；
5. remove membership 后进入未归档；
6. delete Notebook 后 Graph 不删除；
7. NoteNode parent 只能同图；
8. 默认 shape 正确；
9. WORLD_V1 正负坐标持久化；
10. notebook.sqlite3 在完全没有 review DB 的测试环境中仍能独立工作；
11. Notebook 功能不写 scheduler.sqlite3；
12. Notebook 功能不写 dual-end review DB。
