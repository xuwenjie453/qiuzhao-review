# 宽度适配实现提示词

只实现 Reader 的按宽度适配，不在本阶段处理旋转位置保持。

## 目标算法

页面 canonical 宽度固定为 `595.92`，使用 Reader 实际 UIScrollView 宽度：

```swift
let rawScale = scroll.bounds.width / typography.canonicalPageWidth
let targetScale = min(max(rawScale, 0.5), 3.0)
```

不要再使用宽度和高度取最小值的整页适配算法。

## 实现要求

1. 只使用 `scroll.bounds.width`，不得使用 `UIScreen.main.bounds`。
2. 缩放后页面显示宽度与阅读区域宽度误差不超过 0.5pt。
3. `minimumZoomScale`、`maximumZoomScale` 和初始 `zoomScale` 必须一致。
4. 关闭 pinch gesture，避免用户再次缩放。
5. `contentView` 仍保持 canonical 宽度，不得把文档内容改成屏幕点坐标。
6. 页面分页、正文字号、行距、`layoutSignature` 不得因 targetScale 改变。
7. 不修改 drawing 的 `dataRepresentation`。

## 首次进入

增加一次性视口初始化状态。第一次获得有效 bounds 后按顺序：

1. 计算 targetScale；
2. 应用固定 zoom；
3. 触发布局；
4. 将横向和纵向 offset 设为顶部；
5. 标记视口初始化完成。

后续布局不得无条件把纵向 offset 设为零。

## 验收

- 横屏宽度 1180pt 时，缩放后页面宽度约为 1180pt；
- 首次进入 `contentOffset.y == 0`；
- `minimumZoomScale == maximumZoomScale == zoomScale`；
- `layoutSignature` 与修改前相同；
- canonical 页面宽度仍为 595.92。

如果修改 `centerContent()`，必须说明它为何不再添加大面积左右留白。
