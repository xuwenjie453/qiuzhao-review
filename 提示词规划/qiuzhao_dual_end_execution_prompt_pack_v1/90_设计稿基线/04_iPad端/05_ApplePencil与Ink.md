# Apple Pencil / Ink 设计

## 1. 技术路径

使用原生 `PKCanvasView`。Apple 官方明确将 PencilKit 用作低延迟 Apple Pencil/触控绘制，并以 `PKDrawing` 表示可保存的绘图内容。

## 2. 输入策略

Reader：

```swift
canvas.drawingPolicy = .pencilOnly
```

- Pencil：写；
- finger：滚动 outer reader；
- 不允许手指误画。

## 3. Tool

默认 ink 工具参数集中配置；不要每次触摸重建 tool。

Eraser 使用 PencilKit `PKEraserTool`。

## 4. Pencil 双击

用 `UIPencilInteraction` delegate 接受 double tap：

```text
current tool = ink -> 保存 previousInkTool -> eraser
current tool = eraser -> previousInkTool
```

用户需求的第一下双击必定进入 eraser。再次双击返回此前 ink，避免没有返回路径。

设备事实：第一代 Apple Pencil 不支持该硬件 double-tap；该型号仍可通过工具 UI 选 eraser。

## 5. 持久化

`PKDrawing.dataRepresentation()` 作为 opaque bytes。

保存触发：

- drawing changed：300–500ms debounce 写本地；
- reader disappear：force flush；
- app scene inactive/background：force flush；
- memory pressure：force flush if dirty。

**debounce 只用于 I/O，不得延迟屏幕笔迹渲染。**PencilKit 直接渲染用户落笔。

## 6. Ink revision

每次本地 durable snapshot：`ink_revision += 1`，写 outbox `INK_PUT(full blob)`。v1 用 full snapshot 而非 stroke delta，简化恢复和幂等；解释节点内容规模有限，网络是 LAN。

## 7. 性能验收

真机 + Apple Pencil：

- 落笔视觉反馈由 PencilKit 原生路径完成；
- 连续 2 分钟书写无明显卡顿；
- 同时后台 debounce save 不阻塞 MainActor；
- 50 次离开/返回 node，ink 与正文无可见偏移。
