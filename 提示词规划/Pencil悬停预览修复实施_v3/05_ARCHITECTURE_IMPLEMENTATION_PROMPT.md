# Phase 1：架构实施（唯一显示变换）

按 `02` 冻结的契约实施路线 B。本文件是 HOW：精确到函数与属性。参考 `git show 5121d17` 的实现但必须按 `06` 修正清单改造，**不得照抄**。

## 一、视图构建 `build(markdown:)`

```swift
// 1. 文档镜像层：非交互兄弟层，不参与命中测试
contentView.isUserInteractionEnabled = false
contentView.backgroundColor = .clear
contentView.bounds = CGRect(origin: .zero, size: documentSize)   // canonical
contentView.layer.anchorPoint = .zero
contentView.layer.position = .zero
addSubview(contentView)                                          // 先加（在 Canvas 下层）
renderDocument(markdown)                                         // 页面装入 contentView（不变）

// 2. Canvas：唯一滚动/缩放 owner，钉满四边（autolayout）
canvas.drawingPolicy = .pencilOnly
canvas.allowsFingerDrawing = false        // 手指滚动，Pencil 书写
canvas.isScrollEnabled = true             // ★ Canvas 就是滚动 owner
canvas.bounces = true
canvas.alwaysBounceHorizontal = false
canvas.alwaysBounceVertical = true
canvas.isDirectionalLockEnabled = true
canvas.contentInsetAdjustmentBehavior = .never
canvas.contentInset = .zero
canvas.scrollIndicatorInsets = .zero
canvas.contentOffset = .zero
canvas.minimumZoomScale = 0.5             // 初值；applyViewport 会钉到适宽值
canvas.maximumZoomScale = 3
canvas.pinchGestureRecognizer?.isEnabled = false   // 禁捏合，宽度恒适屏
canvas.backgroundColor = .clear
canvas.isOpaque = false
canvas.delegate = self
addSubview(canvas)                                  // 后加（在镜像层之上）
// canvas 四边 autolayout 钉到 self
```

`renderDocument` 逻辑不变（分页、pageRects、documentSize 计算、`canvas.allowedPageRects = pageRects`）。

## 二、视口应用 `applyViewport(resetToTop:)`（顺序冻结）

```swift
private func applyViewport(resetToTop: Bool) {
    isApplyingViewport = true; defer { isApplyingViewport = false }
    guard canvas.bounds.width > 1, canvas.bounds.height > 1 else { return }

    let oldTop = resetToTop ? 0
        : canvas.contentOffset.y / max(canvas.zoomScale, 0.001)     // canonical 化旧位置
    let z = ReaderViewportMath.fitWidthScale(
        viewportWidth: canvas.bounds.width,                          // 实际视口，禁 UIScreen
        pageWidth: typography.canonicalPageWidth)

    canvas.contentInset = .zero
    canvas.scrollIndicatorInsets = .zero
    canvas.minimumZoomScale = z
    canvas.maximumZoomScale = z
    canvas.setZoomScale(z, animated: false)
    canvas.contentSize = CGSize(width:  documentSize.width  * z,    // ★ display 单位：
                                height: documentSize.height * z)    //   canonical × z
    canvas.layoutIfNeeded()

    let maxOffsetY = max(0, canvas.contentSize.height - canvas.bounds.height)
    let y = min(max(oldTop * z, 0), maxOffsetY)
    canvas.setContentOffset(CGPoint(x: 0, y: y), animated: false)    // 夹取在 contentSize 之后
    lockHorizontalOffset()
    syncDocumentMirror()
}
```

顺序理由（写进代码注释）：
1. 先 `setZoomScale` 后 `contentSize`：contentSize 语义是当前缩放下的内容尺寸，必须以生效后的 z 计算；
2. offset 夹取放在 contentSize 确定之后（旋转保持阅读位置）；
3. `isApplyingViewport` 防止 zoom/offset 触发的委托回调与设置过程递归。

## 三、镜像同步 `syncDocumentMirror()`（单向、幂等、每帧可承受）

```swift
private func syncDocumentMirror() {
    guard canvas.zoomScale > 0 else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    contentView.bounds.size = documentSize
    contentView.layer.anchorPoint = .zero
    contentView.layer.position = CGPoint(x: -canvas.contentOffset.x,
                                         y: -canvas.contentOffset.y)
    contentView.layer.setAffineTransform(
        CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale))
    CATransaction.commit()
}
```

调用点（四个，缺一不可）：
1. `scrollViewDidScroll`（canvas）；
2. `scrollViewDidZoom`（canvas）；
3. `canvasViewDidFinishRendering`（PencilKit 异步渲染完成，drawing 异步装载的时序证据）；
4. `layoutSubviews` 的尺寸未变分支（兜底重申，对抗 autolayout 对 translates 视图的 frame 回写）。

方向永远 Canvas → 正文；不存在反向写。

## 四、`layoutSubviews` 状态机（保持既有三态）

```text
uninitialized → applyViewport(resetToTop: true) → fittedAtTop
尺寸变化(>0.5pt) → applyViewport(resetToTop: false) → fittedPreservingPosition
尺寸未变 → lockHorizontalOffset() + syncDocumentMirror()
```

## 五、`PageCanvasView.hitTest`（只约束 Pencil，基准注释必须保留）

```swift
override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if let touch = event?.allTouches?.first, touch.type == .pencil {
        // hitTest point 与 location(in:) 同处 canvas bounds 坐标系；UIScrollView 的
        // bounds.origin == contentOffset，该系原点已随滚动移动 → canonical 换算
        // 只除 zoomScale，不再加 contentOffset（加了是双重计算）。
        let doc = CGPoint(x: point.x / max(zoomScale, 0.001),
                          y: point.y / max(zoomScale, 0.001))
        guard allowedPageRects.contains(where: { $0.contains(doc) }) else { return nil }
    }
    return super.hitTest(point, with: event)   // 手指放行 → 滚动不受影响
}
```

## 六、数学助手（供 07 号单测，纯函数）

在 `ReaderViewportMath` 增加：

```swift
static func displayContentSize(documentSize: CGSize, scale: CGFloat) -> CGSize
static func documentLayerPosition(contentOffset: CGPoint) -> CGPoint   // = -offset
static func documentLayerTransform(scale: CGFloat) -> CGAffineTransform
// 并保留既有 fitWidthScale / canonicalTopY / clampedOffsetY / displayPoint / canonicalPoint
```

## 七、Drawing 装载与 Pencil 生命周期（与视口解耦）

- `loadInk(drawing:revision:)` 只赋 `canvas.drawing` 与 revision 标记，**不碰任何几何**；渲染完成由 `canvasViewDidFinishRendering` 补镜像同步。
- `ReaderHostView.updateUIViewController`：Coordinator 记住已挂 canvas（`attachedCanvas`），首次及换 canvas 时调用 `pencil.attach(to: readerView.canvas)`，每次 update 调 `pencil.apply(to:isEraser:)`。
- `PencilToolController`：weak canvas；`attach` 对同一 canvas 幂等；双击切换后在 canvas 上 `apply`。
- 此三处与「暂存」实现等价，可直接参考 `5121d17` 对应 diff。

## 八、Phase 1 自检（进入 Phase 2 前逐条回答）

1. Reader 中是否只剩一条 canonical→screen 变换（`02` 公式）？每层 transform 的来源是什么？
2. Canvas 之上是否没有任何祖先缩放/平移变换？
3. `contentSize` 是否为 display 单位？空 drawing 与有笔迹两种状态下滚动范围是否正确？
4. `loadInk` 是否零几何副作用？
5. hitTest 换算基准注释是否在位？
