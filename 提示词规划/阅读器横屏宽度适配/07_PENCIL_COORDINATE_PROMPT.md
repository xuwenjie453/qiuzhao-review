# Apple Pencil 坐标与书写层提示词

验证并保护 Apple Pencil 的悬停、落笔和保存坐标，不使用手工坐标补偿。

## 坐标原则

页面、正文、Canvas 和 PKDrawing 使用同一 canonical 文档空间：

```text
A4 width  = 595.92
A4 height = 842.88
```

外层 UIScrollView 的 zoom transform 是唯一显示缩放来源。

禁止：

- 对 PKDrawing 点坐标乘 targetScale；
- 对 Pencil 触点再做一次屏幕到页面换算；
- 给 Canvas 设置与外层不同的 zoomScale；
- 旋转时重写 drawing 数据；
- 用截图或 PDF 图片替代真正的 PKCanvasView。

## 命中范围

`allowedPageRects` 必须是 contentView canonical 坐标中的整张页面矩形，而不是正文列矩形。

因此正文、左留白、右留白、页面顶部和页面底部都可写；页面外背景和页间 gutter 不可写。

## 手指与 Pencil

- `canvas.drawingPolicy = .pencilOnly`；
- Canvas 不负责滚动；
- 手指上下滑动由外层 UIScrollView 处理；
- Pencil 书写不应触发页面横移或缩放；
- 如需调整手势识别器，先通过真机确认不会阻断 Pencil hover。

## 验收

用已有笔迹和新笔迹分别验证正文中间、左右留白、页面顶部、页面底部、宽度适配后的横屏页面和旋转后的页面。退出节点再次进入，确认笔迹位置不变。

确认 `node_id`、`ink_revision`、`blob_sha256` 和 `pkdrawing-v1` 未被改变。
