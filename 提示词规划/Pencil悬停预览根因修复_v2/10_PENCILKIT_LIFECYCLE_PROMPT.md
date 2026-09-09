# PencilKit 生命周期与输入层提示词

## Canvas 配置

在最终架构中明确验证：

```text
canvas.drawingPolicy = .pencilOnly
canvas.isScrollEnabled = false（若外层负责滚动）
canvas.minimumZoomScale = 1
canvas.maximumZoomScale = 1
canvas.zoomScale = 1
canvas.contentInset = .zero
canvas.contentOffset = .zero
```

这些属性只能表达“Canvas 不再拥有第二套 viewport”，不能用来掩盖父级 transform 错位。

## Hover 诊断

如需诊断，加入只读的 `UIHoverGestureRecognizer` 或等价日志，限定 Pencil touch type，记录：

```text
location(in: canvas)
location(in: window)
zOffset
canvas/window convert 结果
```

诊断代码不能改变正式 drawing，也不能自己绘制假的 stroke。

## Drawing 生命周期

- `canvas.drawing = drawing` 只加载已有数据；
- `canvasViewDrawingDidChange` 只代表正式 drawing 变化；
- hover 更新不能触发 ink revision、outbox 或网络发送；
- 在可用时使用 PencilKit 的渲染完成回调作为时序证据；
- 退出 Reader、退后台前仍需 flush 正式 drawing。

## 独立检查

检查 `PencilToolController.attach(to:)` 是否真的调用。未挂载会影响 Pencil 双击工具切换，但不得把它误判为 hover 坐标根因。
