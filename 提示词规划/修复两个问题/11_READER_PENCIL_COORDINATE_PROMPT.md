# 问题二：PencilKit 整页可写与坐标稳定提示词

请确保正文和批注始终共享同一页面坐标。

## Canvas 覆盖范围

每个 A4 PageView 必须包含一个覆盖整张白纸的 PKCanvasView：

```text
canvas.top    = page.top
canvas.bottom = page.bottom
canvas.leading  = page.leading
canvas.trailing = page.trailing
```

正文两侧的页面留白必须可写。页面外部灰色区域不属于 Canvas。

## PKCanvasView 内部状态

明确设置并在调试日志中验证：

```text
contentInset = .zero
contentOffset = .zero
zoomScale = 1
minimumZoomScale = 1
maximumZoomScale = 1
isScrollEnabled = false
```

外层 ScrollView 是唯一滚动/缩放 owner。禁止通过两个 scroll view 的 contentOffset 做硬同步。

## 统一变换

页面坐标到屏幕坐标只允许有一个变换：

```text
screen = pageOrigin + pagePoint * scale
```

文字层和 Canvas 层必须作为同一 PageView 的兄弟图层一起变换。不要分别加 contentInset、padding、offset。

## Pencil 行为

- Pencil 可写，手指默认滚动；
- 页面内部正文和边缘留白均可写；
- 滚动、缩放、旋转后笔迹仍与页面坐标重合；
- Reader 切换节点后 drawing 不串 node；
- 旧 `pkdrawing-v1` 可加载。

加入真机画线测试：正文左侧、正文中间、正文右侧、页面四角、滚动后和放大后各画线。

