# 04 NotebookGraph 与共享 GraphUI Prompt

本步骤目标：让 NotebookGraph 复用成熟的图形交互能力，但绝不复用 Review canonical 数据。

## 一、原则

必须坚持：

```text
共享 presentation / geometry / interaction code
≠
共享 store / identity / lifecycle
```

不要为了复用 `QuestionGraphView`，直接把 NotebookGraph 包装成 Review `GraphSnapshotDTO` 后写进 review store。

---

## 二、推荐抽象层次

优先提取中性 UI 模型，例如：

```text
GraphNodePresentation
├── id
├── parentId
├── shape
├── title
├── worldPosition
├── selected
└── optional visual flags
```

以及：

```text
GraphPresentation
├── centerNodeId
└── nodes
```

Review Adapter：

```text
Review GraphNodeDTO
-> GraphNodePresentation
```

Notebook Adapter：

```text
NoteNodeDTO
-> GraphNodePresentation
```

共享 UI 不应知道：

```text
QUESTION_BANK
REVIEW_CAPSULE
USER_AUTHORED
Notebook membership
review round
review inheritance
scheduler
```

---

## 三、共享组件候选

可以共享/抽取：

- `NodeShape` 枚举或同一视觉枚举定义；
- `NodeGlyph`；
- `GraphCanvasGeometry` / WORLD_V1 screen<->world transform；
- Canvas pan session；
- node drag；
- edge auto-pan；
- parent-child line；
- hit testing；
- selection visual；
- Markdown node reader；
- PencilKit renderer（如果 Notebook V1 要 ink）。

不要强行共享：

- Review Graph service；
- Review ClientStore；
- Review outbox；
- review sync protocol；
- notebook membership；
- review inheritance；
- round/temporary lifecycle。

---

## 四、重构策略

采用“最小抽取”，不要一次性重写整个 `QuestionGraphView`。

推荐顺序：

1. 先把 `NodeGlyph(kind:)` 改造成 `NodeGlyph(shape:)`；
2. 把纯几何 `GraphCanvasGeometry` 保持为无业务依赖；
3. 如果现有 `QuestionGraphView` 的 store 依赖太强，先提取内部纯视图 `GraphCanvasView`；
4. Review `QuestionGraphView` 继续负责把 Review state 映射进去；
5. 新增 `NotebookGraphView`，负责把 Notebook state 映射进去；
6. 两者共用纯 canvas，但各自处理业务 mutation。

目标形态：

```text
ReviewQuestionGraphView
      │
      ├── Review Adapter
      │
      ▼
   SharedGraphCanvas
      ▲
      │
      ├── Notebook Adapter
      │
NotebookGraphView
```

---

## 五、NotebookGraph 交互

V1 建议支持：

- 打开 NotebookGraph；
- 单击节点；
- 双击进入正文；
- 拖动节点；
- 拖动画布；
- edge auto-pan；
- 修改节点标题；
- 修改节点 shape；
- 创建 EXPLANATION 子节点；
- 删除非 CENTER 节点；
- parent-child 连线；
- Markdown 正文。

如果时间/范围要收缩，可以暂不加入 PencilKit，但不要破坏未来加入 `note_ink` 的可能性。

NotebookGraph 不需要：

- ACTIVE round；
- TEMPORARY；
- Review inherited node；
- question source；
- capsule probe；
- scheduler state。

---

## 六、NotebookGraph 创建体验

创建一张自制笔记图：

```text
输入 title + center body
-> 生成 note graph id
-> 创建 CENTER
   kind=CENTER
   shape=SQUARE
   world=(0,0)
-> 可选 notebook_id
-> 若未指定则未归档
```

新增普通节点：

```text
kind=EXPLANATION
shape=CIRCLE
parent=指定 parent 或 CENTER
world=确定性初始位置 / 当前 viewport 附近的合理位置
```

不要借用 Review `question.open` 或 `graph.add-node` command。

---

## 七、Shape picker

Review 和 Notebook 可以共享同一个 picker UI：

```text
□ SQUARE
○ CIRCLE
△ TRIANGLE
```

但回调必须分别进入：

```text
Review mutation adapter
Notebook mutation adapter
```

不能让共享 picker 自己知道 DB。

---

## 八、WORLD_V1

NotebookGraph 直接使用同样的“世界坐标思想”：

```text
canonical node position = world point
camera offset = UI local state
```

这只是数学约定共享，不代表数据共享。

Notebook DB 只存自己的 `x_world/y_world`。

Canvas Pan offset 不落 canonical graph；node drag 时先逆 camera transform 再写 world point。

必须保留现有已经解决的手势不变量：

```text
node drag ownership 与 canvas pan ownership 起点确定
node drag 不被 parent canvas 中途夺取
edge auto-pan 是 node drag 内显式 camera movement
```

---

## 九、测试

至少覆盖：

1. 同一 `NodeShape` 在 Review/Notebook renderer 中视觉一致；
2. Review kind 不再决定 glyph；
3. Notebook kind 不再决定 glyph；
4. Notebook node drag 只写 notebook store；
5. Notebook canvas pan 不写任何 canonical DB；
6. Notebook shape change 只写 notebook store；
7. Review shape change 只写 review store；
8. 两边同名 graph/node 不发生 identity 冲突；
9. shared canvas 不 import 两边具体 store；
10. Review 原有 pan/drag/edge auto-pan 全部回归通过。
