# 视口变换矩阵审计提示词

请审计 hover 期间页面、Canvas 和外层滚动容器的几何状态。

## 必须记录

在正常状态、hover 状态、落笔状态和 hover 离开状态分别记录：

```text
scroll.bounds
scroll.contentSize
scroll.contentOffset
scroll.zoomScale
scroll.minimumZoomScale
scroll.maximumZoomScale

contentView.frame
contentView.bounds
contentView.transform

canvas.frame
canvas.bounds
canvas.contentOffset
canvas.zoomScale
canvas.contentSize
canvas.transform
```

同时记录：

```text
canvas.convert(point, to: window)
window.convert(point, to: canvas)
```

## 审计原则

- 页面和 Canvas 必须共享相同 canonical 原点；
- 外层缩放是唯一显示缩放来源；
- Canvas 自己的 zoomScale 必须为 1；
- Canvas contentOffset 和 contentInset 必须为 0；
- 页面显示宽度应等于实际阅读区域宽度；
- `allowedPageRects` 必须使用 Canvas/contentView 坐标，而不是屏幕坐标。

## 重点判断

1. hover 时 model layer 和 presentation layer 的 frame 是否不同；
2. hover 时是否出现额外 contentOffset；
3. hover preview 是否使用旧的 targetScale；
4. `contentView` 是否在 hover 期间再次布局；
5. x 方向是否为固定 origin 差值；
6. y 方向是否存在随页面位置线性变化的 scale 差值。

## 输出

把实际矩阵和预期矩阵逐项比较，并明确指出哪一个值发生变化以及该变化是否由用户滚动引起。禁止只给“坐标系不一致”的笼统结论。
