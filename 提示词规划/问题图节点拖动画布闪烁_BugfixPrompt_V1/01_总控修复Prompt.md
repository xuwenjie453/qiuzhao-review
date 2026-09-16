# 01 — 总控修复 Prompt

你现在负责修复 iPad QuestionGraph 的一个交互 Bug：

> 拖动节点时，整个问题图也会跟着移动，背景不断抖动/闪烁。

你的任务不是重新设计 Canvas Pan，而是在当前已经实现的 QuestionGraph 层级 + Canvas Pan 架构中修复 Node Drag 与 viewport clamp 的耦合。

## 一、开始前必须完成

1. 确认当前分支是包含已实现功能代码的目标分支，禁止切回旧基线实现。
2. 阅读：
   - `AGENTS.md`
   - `提示词规划/问题图层级与画布交互_实现Prompt_V1/03_Canvas_Pan实现Prompt.md`
   - 本 Bugfix Prompt 包全部文件
3. 打开并审计：
   - `DualEnd-iPad/QiuZhaoReader/Topology/QuestionGraphView.swift`
   - `DualEnd-iPad/QiuZhaoReader/Topology/GraphCanvasGeometry.swift`
   - `DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift`
4. 在修改前明确当前这几个值的来源：
   - `committedCanvasOffset`
   - `canvasDragTranslation`
   - `liveCanvasOffset`
   - `baseNodeCenters`
   - `dragTransient`
   - `pendingPositions`
   - `normalizedPosition(for:)`
   - `viewportOffset` 传入 `NodeShapeView` 的路径

## 二、冻结的 Bug 根因

当前实现中，画布 offset 的 clamp bounds 使用了会随 Node Drag 每帧变化的节点位置：

```text
normalizedPosition(for: node)
  = dragTransient ?? pendingPositions ?? canonical layout

baseNodeCenters
  = point(normalizedPosition)

liveCanvasOffset
  = clamp(committedCanvasOffset + canvasDragTranslation,
          nodeCenters: baseNodeCenters)
```

这造成：

```text
Node Drag
→ dragTransient 变化
→ baseNodeCenters 变化
→ clamp range 变化
→ liveCanvasOffset 变化
→ 整个 pannable layer 位移
→ Node drag inverse transform 使用新的 viewportOffset
→ 反馈环
```

这才是本次必须修掉的核心机制。

## 三、必须实现的交互不变量

### Node Drag

```text
输入：drag transient / pending canonical move
允许改变：被拖节点的位置、对应连线
禁止改变：canvas viewport offset
```

必须满足：

```text
Δnode != 0
ΔcanvasOffset == 0
```

### Canvas Pan

```text
输入：blank-canvas drag
允许改变：local viewport offset
禁止改变：canonical node layout
```

必须满足：

```text
ΔcanvasOffset != 0
canonical node positions unchanged
```

### Gesture ownership

手势所有权由 `startLocation` 决定，整个 gesture 生命周期不切换：

```text
start on node  → Node owns drag
start on blank → Canvas owns drag
```

CENTER 也属于 node hit area；从 CENTER 起手不能触发 Canvas Pan。

## 四、优先修复策略

第一优先级：

> **将 viewport clamp 使用的 node centers 与 `dragTransient` 解耦。**

推荐增加稳定位置函数：

```swift
private func stableNormalizedPosition(for node: GraphNodeDTO) -> CGPoint {
    state.pendingPositions[node.nodeId]
        ?? CGPoint(x: node.layout.x, y: node.layout.y)
}
```

然后：

```swift
private var viewportConstraintCenters: [CGPoint] {
    state.snapshot?.nodes.map {
        geometry.screenPoint(from: stableNormalizedPosition(for: $0))
    } ?? []
}
```

`liveCanvasOffset` 必须 clamp against `viewportConstraintCenters`，而不是当前会包含 `dragTransient` 的视觉节点中心。

## 五、防御性修复

在不扩大改动面的前提下，建议明确：

- `containsNode(...)` 用当前视觉位置 + 当前 viewport offset 做 hit testing；
- viewport bounds 用 stable position，不用 drag transient；
- Node drag 的 inverse transform 继续显式使用 viewport offset；
- 不要删除已有 `graphPoint(fromVisual:viewportOffset:)` 逆变换；
- 不要用“拖节点时临时关闭整个 Canvas Pan 功能”作为唯一修复，因为那会掩盖 clamp 耦合，且未来状态更新仍可能引发 viewport jump。

## 六、禁止的错误修复

不要：

- 把 `.simultaneousGesture(canvasPanGesture)` 粗暴改成抢占式 `highPriorityGesture`，导致背景拖动抢走节点 drag；
- 在 Node Drag 时直接把 `committedCanvasOffset = .zero`；
- 删除 viewport clamp；
- 禁止 pan 后再拖节点；
- 把节点 drag 改成纯视觉、不提交 canonical MOVE_NODE；
- 修改 Mac / schema / sync / parent model；
- 用 animation delay/debounce 隐藏闪烁；
- 仅降低刷新频率来掩盖根因。

## 七、完成后必须输出

最终报告至少说明：

1. 根因是什么；
2. 改了哪些文件；
3. viewport constraint centers 现在基于什么位置；
4. 为什么 Node Drag 不再改变 Canvas offset；
5. Canvas Pan 是否仍正常；
6. pan 后 node drag 的 inverse transform 是否仍成立；
7. 跑了哪些测试；
8. 哪些测试因环境原因没有运行。
