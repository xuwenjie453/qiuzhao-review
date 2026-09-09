# 横竖屏、分屏与视口状态提示词

实现尺寸变化时的稳定视口状态，不要把旋转当成重新打开节点。

## 状态

至少区分：

```text
UNINITIALIZED
WIDTH_FITTED_AT_TOP
WIDTH_FITTED_PRESERVING_POSITION
```

首次进入使用 `WIDTH_FITTED_AT_TOP`；窗口尺寸变化使用 `WIDTH_FITTED_PRESERVING_POSITION`。

## 位置保持算法

重新计算宽度比例前：

```swift
let canonicalTopY = scroll.contentOffset.y / oldScale
```

重新计算 `newScale` 后：

```swift
let newOffsetY = canonicalTopY * newScale
```

把 newOffsetY 裁剪到合法纵向范围，横向 offset 始终为 0。

## 约束

- 第一次进入必须显示第一页顶部。
- 后续 `layoutSubviews` 不得反复回到顶部。
- 横竖屏切换不能重建 PKDrawing。
- 分屏宽度变化不能改变正文 canonical 排版。
- 尺寸未实际变化时不要重复设置 zoom，避免滚动跳动。
- 尺寸变化发生在 Pencil stroke 中间时，优先保证坐标一致，不修改 drawing 数据。

## 验收场景

1. 阅读第一页顶部时旋转。
2. 滚动到第二页中部时旋转。
3. 滚动到底部时旋转。
4. 进入分屏，再退出分屏。
5. 旋转前后检查同一笔迹与正文的相对位置。

每个场景记录旋转前后 canonical 位置和误差。
