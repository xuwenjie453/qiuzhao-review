# 03 — 实现策略与代码修改 Prompt

本阶段要求用最小改动修复问题，不扩大到新的 ViewModel、gesture framework 或跨端架构。

## 1. 修改 `QuestionGraphView.swift`

### 1.1 保留节点视觉位置函数

现有类似：

```swift
private func normalizedPosition(for node: GraphNodeDTO) -> CGPoint {
    state.dragTransient[node.nodeId]
        ?? state.pendingPositions[node.nodeId]
        ?? CGPoint(x: node.layout.x, y: node.layout.y)
}
```

这个函数继续用于：

- node glyph 实时位置；
- parent-child link 实时 start/end；
- 当前视觉 hit testing（结合 viewport offset）。

不要删掉 `dragTransient`。

### 1.2 新增稳定位置函数

增加专门给 viewport constraints 使用的函数：

```swift
private func stableNormalizedPosition(for node: GraphNodeDTO) -> CGPoint {
    state.pendingPositions[node.nodeId]
        ?? CGPoint(x: node.layout.x, y: node.layout.y)
}
```

注意：

- 禁止读取 `state.dragTransient`；
- 不要把这个函数拿去替代节点实时 render position；
- 它只用于需要“稳定布局基线”的逻辑。

### 1.3 替换 `baseNodeCenters`

当前若类似：

```swift
private var baseNodeCenters: [CGPoint] {
    state.snapshot?.nodes.map { point(for: $0) } ?? []
}
```

必须避免 `point(for:)` 经由 transient position。

推荐改为：

```swift
private var viewportConstraintCenters: [CGPoint] {
    state.snapshot?.nodes.map { node in
        geometry.screenPoint(from: stableNormalizedPosition(for: node))
    } ?? []
}
```

名称可适配，但语义必须清楚区分：

```text
visual/current node centers      = transient-aware
viewport constraint node centers = transient-free
```

### 1.4 修改 `liveCanvasOffset`

让 clamp 使用 stable centers：

```swift
private var liveCanvasOffset: CGSize {
    let proposed = CGSize(
        width: committedCanvasOffset.width + canvasDragTranslation.width,
        height: committedCanvasOffset.height + canvasDragTranslation.height
    )
    return geometry.clampedViewportOffset(
        proposed: proposed,
        nodeCenters: viewportConstraintCenters
    )
}
```

这样在 Node Drag 中：

```text
canvasDragTranslation == 0
viewportConstraintCenters stable
→ liveCanvasOffset stable
```

### 1.5 Canvas Pan commit 同样使用 stable centers

`.onEnded` 不能再用 transient-aware centers：

```swift
committedCanvasOffset = geometry.clampedViewportOffset(
    proposed: proposed,
    nodeCenters: viewportConstraintCenters
)
```

## 2. Gesture ownership

### 2.1 抽统一判断（推荐）

```swift
private func canStartCanvasPan(at startLocation: CGPoint, viewportOffset: CGSize) -> Bool {
    !containsNode(at: startLocation, viewportOffset: viewportOffset)
}
```

Canvas gesture：

```swift
.updating($canvasDragTranslation) { value, translation, _ in
    guard canStartCanvasPan(
        at: value.startLocation,
        viewportOffset: committedCanvasOffset
    ) else {
        translation = .zero
        return
    }
    translation = value.translation
}
```

`.onEnded` 使用完全相同的 start-location ownership 语义。

### 2.2 不要用当前 `liveCanvasOffset` 判断 gesture 起点 ownership

一次 gesture 开始时应基于手势开始前已经 committed 的 viewport state 做判断。

推荐：

```text
start hit test = committedCanvasOffset
```

原因：

- gesture start 时 `canvasDragTranslation` 应为 0；
- ownership 一旦确定不应被本次 gesture 的移动影响。

## 3. Node Drag inverse transform

保留并确认以下逻辑：

```swift
let graphCenter = geometry.graphPoint(
    fromVisual: newVisualCenter,
    viewportOffset: viewportOffset
)
let normalized = geometry.normalizedPoint(from: graphCenter)
```

修复完成后，Node Drag 生命周期中的 `viewportOffset` 不应因该节点 transient movement 发生变化。

不要把 inverse transform 删除成：

```swift
geometry.normalizedPoint(from: newVisualCenter)
```

否则画布 pan 后拖节点会写入错误 canonical layout。

## 4. 是否需要改 `GraphCanvasGeometry.swift`

原则上本 Bug 可以只改 `QuestionGraphView.swift`。

只有以下情况才改 Geometry：

- 为测试增加纯 helper；
- 希望把 clamp bounds 计算拆成显式 value type；
- 现有 helper 无法独立验证 transform。

不得改变现有 clamp 目标语义：

```text
最边缘 node center 能到 viewport center
```

不要通过放宽/取消 clamp 来“解决”闪烁。

## 5. 可选增强：显式冻结 Node Drag viewport offset

如果 SwiftUI 更新机制仍可能让 `NodeShapeView` 在一次拖动中收到变化的 `viewportOffset`，可以增加第二道防线：在 Node Drag 首次 `.onChanged` 时记录 drag-session viewport offset。

例如概念上：

```swift
@State private var dragViewportOffset: CGSize?
```

首次 drag：

```text
dragViewportOffset = viewportOffset
```

后续 inverse transform 使用：

```text
dragViewportOffset ?? viewportOffset
```

结束后归 nil。

但这是**防御性增强，不是替代主修复**。

只有当测试/实际运行证明父视图 offset 仍可能在 Node Drag 中被其它外部状态变化影响时再采用。

## 6. Parent-child rendering 不得退化

当前连线已经通过：

```text
resolvedParent(child)
point(parent) → point(child)
```

修复后仍应让正在拖动的节点与连线一起实时更新。

不能为了让 viewport bounds 稳定而把所有 render point 都改成 stable position。

必须保持：

```text
render/link = transient-aware
viewport clamp = transient-free
```

## 7. 修改完成后的代码审计

搜索并确认：

```text
clampedViewportOffset(
```

所有 QuestionGraphView 中的调用都不能传入由 `dragTransient` 驱动的 centers。

同时搜索：

```text
dragTransient
```

确认它仍参与 node rendering，但不再参与 viewport bounds。

最后搜索：

```text
localMove
MOVE_NODE
```

确认 Canvas Pan 本身没有新增任何调用。
