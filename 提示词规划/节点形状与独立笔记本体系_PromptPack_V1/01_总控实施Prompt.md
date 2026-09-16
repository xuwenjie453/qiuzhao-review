# 01 总控实施 Prompt

你正在实现“节点形状解耦 + 独立笔记本体系”。

## 目标

在不破坏现有 Review QuestionGraph 的 WORLD_V1、层级关系、双端同步、离线缓存、CAS、outbox、复习调度的前提下：

1. 为节点新增独立 `shape` 概念；
2. 让所有节点可选 `SQUARE / CIRCLE / TRIANGLE`；
3. 保留默认：CENTER 新建时为方形，所有新非 CENTER 节点默认为圆形；
4. 旧数据迁移后保持旧视觉：CENTER=方形、EXPLANATION=圆形、TEMPORARY=三角形；
5. 新建一个完全独立的 Notebook 业务域；
6. Notebook 只收纳 NotebookGraph（用户笔记图）；
7. 可以列出/打印所有 Notebook 与其子 NotebookGraph，并显示未归档图；
8. Notebook 数据与复习系统没有任何数据交集。

---

## 一、开始实现前必须重新读取

至少重新读取当前分支/当前 main 中：

### Review QuestionGraph
- `DualEnd-Mac/src/store/state-db.mjs`
- `DualEnd-Mac/src/graph/question-graph-service.mjs`
- `DualEnd-Mac/src/graph/world-layout.mjs`
- `DualEnd-Mac/src/bridge/sync-session.mjs`
- `DualEnd-Mac/src/daemon.mjs`
- `DualEnd-Mac/bin/qreview-dual.mjs`

### iPad
- `DualEnd-iPad/QiuZhaoReader/Domain/Models.swift`
- `DualEnd-iPad/QiuZhaoReader/Topology/QuestionGraphView.swift`
- `DualEnd-iPad/QiuZhaoReader/Topology/GraphCanvasGeometry.swift`
- `DualEnd-iPad/QiuZhaoReader/Store/ClientStore.swift`
- `DualEnd-iPad/QiuZhaoReader/Protocol/WireMessage.swift`
- 节点管理 sheet / rename / delete / move 的实际入口

### 复习系统边界
- `学习系统/lsys/user_graph_scheduler.py`
- `学习系统/cli.py`
- RuntimePrompt 中双端问题图协议

确认最新代码后再动手，不允许根据旧 Prompt 猜文件结构。

---

## 二、架构硬约束

### 1. Review 与 Notebook 是两个 bounded context

必须满足：

```text
Review DB 不引用 Notebook DB
Notebook DB 不引用 Review DB
```

禁止：

- Notebook 表加入 `dual-end.db`；
- NotebookGraph 使用 Review `graphs/nodes/layouts` 表；
- NotebookGraph 写入 `scheduler.sqlite3`；
- NotebookGraph 复用 Review USER_AUTHORED 的 graph_id；
- Notebook membership 影响 review schedule；
- Review inheritance 被当作 Notebook 目录关系。

### 2. 允许共享代码，不允许共享 canonical 数据

可以抽出：

```text
NodeShape
NodeGlyph
WORLD_V1 geometry
GraphCanvas
Pan / Drag / edge auto-pan
parent-child line renderer
Markdown reader
PencilKit rendering
```

但共享组件输入必须是中性的 presentation/domain adapter，不得让共享 UI 直接 import Review Store 或 Notebook Store。

### 3. NodeKind 与 NodeShape 正交

任何代码都不得写：

```text
if kind == CENTER => square
if kind == EXPLANATION => circle
if kind == TEMPORARY => triangle
```

除“旧数据 migration 默认值”与“新节点 creation 默认值”外，渲染只能读取 `shape`。

---

## 三、推荐实施顺序

严格按以下顺序推进：

### Phase 0：基线审计
- 确认当前 schema/protocol 版本；
- 找出所有 `NodeGlyph(kind:)`、kind→shape 的隐式映射；
- 找出 Review node DTO / snapshot / patch / cache / outbox 全链路；
- 找出 iPad 节点管理 UI；
- 列出测试入口。

### Phase 1：Review NodeShape
先只在复习系统中完成 shape canonical 化和同步闭环，确保现有功能不回归。

### Phase 2：Notebook canonical 数据层
新建独立 `notebook.sqlite3` 及 Notebook/NotebookGraph/NoteNode 模型，不碰 scheduler。

### Phase 3：Notebook service + command/query API
建立 notebook create/list/tree、note graph create/open/move 等最小 API。

### Phase 4：共享 Graph UI 抽象
只在有明确收益时抽共用组件；不要先大重构后实现功能。

### Phase 5：NotebookGraph 展示/编辑
让 NotebookGraph 使用独立 store，但可复用统一 shape / world canvas / drag/pan。

### Phase 6：目录打印与 CLI
实现打印所有 Notebook + 所有 NotebookGraph + 未归档。

### Phase 7：回归测试与边界审计
重点检查“无数据交集”，而不仅是 UI 能跑。

---

## 四、范围控制

本轮不要顺手实现：

- Notebook 嵌套；
- 标签；
- 搜索引擎；
- 自动复习；
- Review↔Notebook 导入导出；
- 云同步；
- 多设备 Notebook 同步协议；
- NoteGraph 多 Notebook 归属；
- 新的复杂图布局算法。

如果发现这些需求会影响当前设计，只留下 TODO/接口余量，不实施。

---

## 五、提交纪律

建议拆成可审计提交：

1. `feat(graph): decouple node shape from kind`
2. `feat(notebook): add isolated notebook canonical store`
3. `feat(notebook): add notebook graph service and directory queries`
4. `refactor(graph-ui): share neutral graph presentation primitives`
5. `feat(notebook): add notebook graph surface and tree output`
6. `test: cover shape migration and review-notebook isolation`

不要把全部工作压成一个巨型 commit。

---

## 六、完成时必须报告

最终交付说明至少包含：

- schema 变化；
- protocol 是否升级以及原因；
- Review shape 的迁移策略；
- Notebook DB 的实际路径；
- Notebook 与 Review 无交集的证据；
- CLI 示例；
- iPad/UI 变化；
- 自动测试结果；
- 仍未实现的 V1 外能力。
