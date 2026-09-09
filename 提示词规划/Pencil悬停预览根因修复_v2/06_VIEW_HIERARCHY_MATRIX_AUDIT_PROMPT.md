# View hierarchy 与坐标矩阵审计提示词

分别在正常、hover、落笔、hover 结束四个时刻记录以下值：

```text
outerScroll.bounds
outerScroll.contentSize
outerScroll.contentOffset
outerScroll.zoomScale
outerScroll.minimumZoomScale
outerScroll.maximumZoomScale
outerScroll.isZooming
outerScroll.layer.presentation()?.transform

contentView.frame
contentView.bounds
contentView.transform
contentView.layer.presentation()?.transform

canvas.frame
canvas.bounds
canvas.contentSize
canvas.contentInset
canvas.contentOffset
canvas.zoomScale
canvas.transform
canvas.layer.presentation()?.transform
```

同时记录同一个点的：

```swift
canvas.convert(point, to: window)
window.convert(point, to: canvas)
```

## 必须回答

1. 页面文字和 Canvas 的 canonical 原点是否完全一致？
2. 实际显示是否存在一层以上非 identity transform？
3. Canvas 是否因为 `contentSize` 自动缩放了内部 drawing？
4. hover 时 presentation layer 是否仍处于旧 zoom？
5. `allowedPageRects` 是否在 Canvas 本地坐标中，而不是 window 坐标？
6. 是否有任何代码同时根据 frame、contentOffset 和 zoomScale 进行手工换算？

结论必须指出“哪一个矩阵在何时与预期不一致”，不能只写“坐标系不统一”。
