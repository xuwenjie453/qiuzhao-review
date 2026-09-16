# 03 — Canvas Pan 实现 Prompt

只实现 iPad 问题图的本地 viewport 平移。不要把本功能扩散到 Mac、sync 或 canonical schema。

## 1. 目标语义

在 `QuestionGraphView` 中：

```text
Drag starts on blank canvas → pan entire rendered graph
Drag starts on any node      → node owns the gesture
```

“entire graph”必须同时包括：

- 所有 node glyph/title；
- 所有 parent-child links（若 Parent Node 功能尚未实现，则包括当前 center-child links）。

pan 是 local presentation state：

```text
renderPoint = graphPoint + viewportOffset
```

不得改写：

```text
node.layout
pendingPositions 的 canonical 语义
Mac DB
graph_revision
node_revision
layout_revision
```

也不得发送 `MOVE_NODE`。

## 2. 推荐状态模型

可按当前 SwiftUI 结构适配，语义等价即可：

```swift
@State private var committedCanvasOffset: CGSize = .zero
@GestureState private var canvasDragTranslation: CGSize = .zero
```

实时 offset：

```swift
liveOffset = clamp(committedCanvasOffset + canvasDragTranslation)
```

手指结束后把最终值写入 `committedCanvasOffset`；`@GestureState` 自动归零。

切换到另一张 graph（至少以 `graphId` 为 identity）时重置为 `.zero`。V1 不把 viewport offset 持久化到 SQLite。

## 3. 图层组织

把“links + nodes”置于同一个可平移的 inner canvas layer：

```text
Root viewport (固定)
└── Pannable canvas layer (.offset(liveOffset))
    ├── Links
    └── Nodes
```

背景命中区域仍覆盖整个 viewport。不要分别给 node 和 link 计算不同 offset。

## 4. Gesture arbitration：必须由 startLocation 决定

使用当前 named coordinate space（或等价机制）。当 drag 开始：

- `startLocation` 位于任一 node 的**当前视觉 hit rect** → canvas pan 本次 gesture 永远不生效；
- `startLocation` 在 blank → 本次 gesture 全程属于 canvas pan，即使手指后来经过 node；
- 从 node 开始后即使移出 node，也不能切成 canvas pan。

CENTER 也是 node hit area：CENTER 本身按既有规则不可拖；从 CENTER 起手也**不能**借机 pan。要 pan 必须从 blank 起手。

保留现有 single tap / double tap。可沿用约 `minimumDistance = 8` 区分 tap 与 drag，但以当前 UI 行为为准，不要因本功能破坏点击。

## 5. Hit testing 必须应用 viewport transform

如果 canonical/render helper 当前返回未平移屏幕点，则：

```text
visualNodeCenter = baseScreenPoint + liveOffset
visualHitRect     = baseHitRect.offsetBy(liveOffset)
```

所有“手势起点是否在 node”判断必须使用 visual hit rect。

不要出现：图视觉上被移走，但旧位置仍挡住 background pan/tap。

## 6. 关键：pan 后 node drag 的逆变换

这是 Must 测试点，不能靠 `grabOffset` 偶然抵消。

假设：

```text
base graph point = G
viewport offset  = O
visual point     = G + O
```

node drag gesture 给你的 location 若处于 viewport/graph-canvas visual coordinate，则在写回 `geometry.normalizedPoint(...)` 前必须显式移除 O：

```text
graphSpacePoint = visualGesturePoint - live/committed viewportOffset
normalized      = normalizedPoint(graphSpacePoint)
```

仍需保留原有“触点相对节点中心的 grab offset”，防止节点瞬间吸附到手指中心。但 grab offset 与 viewport inverse transform 是两个独立概念。

实现后必须验证：

> 画布 offset=0 时拖节点 Δ，与画布先 pan 任意 O 后再拖同样视觉 Δ，最终 canonical normalized delta 相同。

## 7. Clamp：根据当前可见 node centers，而不是固定 contentRect 猜范围

目标：任一最边缘可见 node 的**中心**都能被 pan 到 viewport center，同时不允许整张图越过到完全不可恢复。

令未平移的当前可见 node screen centers 为：

```text
minX, maxX, minY, maxY
```

viewport center：

```text
cx = width / 2
cy = height / 2
```

允许：

```text
cx - maxX <= offsetX <= cx - minX
cy - maxY <= offsetY <= cy - minY
```

如果没有 snapshot/nodes，则 offset 为 `.zero`。如果只有一个点，可以按上述公式得到使其可居中的范围；若当前产品更希望单点不乱动，可以 clamp 为零，但必须在测试中固定语义，不能出现 NaN/反向区间。

当节点被拖动、snapshot 更新、viewport size 改变时，显示使用的 live offset 应重新经过 clamp，避免旧 offset 在新边界下失效。

## 8. 与 Parent Node 连线集成

如果执行本 Prompt 时 Parent Node 已实现：

- link 的 start/end 都先在 graph canvas base space 算出；
- inner canvas layer 统一 `.offset`；
- 不要在每条 link 里再次叠加 offset，避免 double transform。

如果 Parent Node 尚未实现：先保持现有 link 逻辑，但组织结构应允许后续 parent-child links 和 nodes 同层平移。

## 9. 测试

至少增加/扩展 iPad tests 覆盖：

### Geometry clamp
- 左/右/上/下最边缘 node center 均可到 viewport center；
- 极大正负 proposed offset 会被 clamp；
- resize/new snapshot 后旧 offset 会重新合法化。

### Gesture / hit helpers（尽量把纯逻辑抽成可测 helper）
- blank start → pan eligible；
- node start（含 CENTER）→ pan ineligible；
- hit rect 在 pan 后位置正确。

### Coordinate transform
- `visualPoint - viewportOffset → graphPoint` round trip；
- pan 前后执行相同 node drag，canonical normalized result 一致。

### 静态架构审计
- Canvas Pan 改动不得出现新的 Mac schema/sync command；
- 不应为了 pan 调用 `localMove` / `MOVE_NODE`。

## 10. 验收场景

手工/Simulator（若环境可用）验证：

1. 打开有多个边缘节点的图；
2. 从 blank 向任意方向拖，全图节点与连线同步移动；
3. 把边缘节点移到屏幕中央；
4. 点击/双击该节点仍正常；
5. 在 pan 后拖动该节点，松手后刷新/重连，节点 canonical 新位置正确；
6. 重新打开另一图，viewport 从初始 offset 开始；
7. daemon/DB 中不因纯 canvas pan 产生任何 layout mutation。

满足以上才算 Canvas Pan 完成。
