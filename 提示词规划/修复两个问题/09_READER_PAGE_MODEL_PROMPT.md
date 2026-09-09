# 问题二：A4 PDF-like 页面模型实现提示词

请把 Reader 从“固定宽度的长 UIView”重构为“居中的 A4 页面文档”。必须保持 Node Body immutable 和既有 ink 兼容。

## 页面坐标

使用 A4 canonical page：

```text
pageWidth  = 595.92pt
pageHeight = 842.88pt
bodyLeft   ≈ 41.5pt
bodyRight  ≈ 41.5pt
bodyWidth  ≈ 512.9pt
```

这些是页面内部坐标，不是 iPad 屏幕坐标。页面显示时整体乘以统一 scale。

## 页面层级

实现或等价实现如下层级：

```text
OuterScrollView（唯一滚动/缩放 owner）
└── DocumentViewport
    ├── A4 Page Background
    ├── Text Layout Layer
    └── PKCanvasView（覆盖整张 A4 页面）
```

不要用多个互相同步的 UIScrollView。不要把外层横向 gutter 当成页面内部留白。

## 横屏行为

默认使用 Fit Page：

```text
scale = min(viewportWidth / pageWidth,
            viewportHeight / pageHeight)
```

页面在横屏中居中，页面外灰色背景可见；页面内部左右留白仍属于白纸并可写。提供 Fit Width 或双指缩放作为可选模式。

## 多页

正文超过一页时按 A4 高度分页，每页有独立白纸、页码和批注层。页面之间有固定间隙和阴影，不能把全部内容继续堆成一张无边界长页面。

## 重要边界

- 白纸内部全部可用 Pencil 书写，包括正文两侧留白；
- 白纸外灰色区域不写；
- 页面缩放、滚动、旋转不能改变 page canonical 坐标；
- 先确认旧 drawing 的兼容方案，再替换 Reader 容器。

