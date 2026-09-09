# 基线勘察与运行期诊断提示词

必须先建立基线，再提出修改。

## 需要阅读

1. `DualEnd-iPad/QiuZhaoReader/Reader/AnnotatedReaderView.swift`
2. `DualEnd-iPad/QiuZhaoReader/Reader/ReaderHostView.swift`
3. `DualEnd-iPad/QiuZhaoReader/Reader/ReaderTypography.swift`
4. `DualEnd-iPad/QiuZhaoReader/Pencil/PencilToolController.swift`
5. `DualEnd-iPad/QiuZhaoReader/Domain/Models.swift`
6. `DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift`

## 必须回答

- 当前有几个 UIScrollView，谁负责滚动，谁负责缩放？
- `contentView` 的 canonical 宽高是多少？
- `ReaderPageView` 和 `PageCanvasView` 是否共享坐标原点？
- 当前初始缩放为何受页面高度限制？
- 当前左右 `contentInset`、`contentOffset` 和 `centerContent()` 如何工作？
- Reader configure、异步加载 drawing、onDisappear、后台恢复分别会否触发布局？
- 手指滚动是否会被 PKCanvasView 拦截？
- `allowedPageRects` 使用页面坐标还是屏幕坐标？
- 历史 PKDrawing 是否直接加载而不经过坐标转换？

## 运行基线

不修改代码，记录：

- iPad 型号、系统版本、横屏可见区域尺寸；
- Reader 首次进入截图；
- 当前页面宽度、显示比例、左右 gutter；
- `contentOffset`、`zoomScale`、`minimumZoomScale`、`maximumZoomScale`；
- 纵向滚动、页内留白书写、页面外误写情况；
- 横竖屏切换后的阅读位置和笔迹位置。

## 诊断输出

输出以下表格：

| 项目 | 当前行为 | 根因假设 | 证据 | 修改风险 |
|---|---|---|---|---|

没有证据的内容必须标记为“待验证”。
