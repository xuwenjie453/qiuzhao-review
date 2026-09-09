# Reader 初始化与渲染时序提示词

追踪新解释节点和旧节点重进的完整时间线：

```text
graphState 收到节点
fullScreenCover 出现
ReaderHostView.load()
markdown 设置完成
ReaderHostVC.configure()
AnnotatedReaderView.init
renderDocument 完成
Canvas 加入 contentView
第一次 layoutSubviews
outer targetScale 设置完成
outer contentOffset 设置完成
Canvas geometry 设置完成
drawing 异步加载完成
canvas.drawing = drawing
Canvas 完成渲染（如可用）
Canvas 重新启用交互
首次 hover
```

## 重点检查

- `ReaderContainer.updateUIViewController` 是否可能先收到空 markdown；
- `configure()` 与异步 `loadDrawing()` 是否并发改变 Canvas；
- `layoutSubviews()` 是否反复调用 `setZoomScale`；
- `DispatchQueue.main.async` 是否只是主线程下一轮，而不是 layout/CA/PencilKit 完成信号；
- Canvas 是否在 hover 已开始后仍发生 frame、bounds 或 contentSize 改变。

## 最终设计要求

如果确属时序问题，必须等待一个明确的完成条件，例如最终 layout、外层 zoom 结束、Canvas 渲染完成或统一 viewport commit。禁止使用无法说明设备差异的固定毫秒延迟。
