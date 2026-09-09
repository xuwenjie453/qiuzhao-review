# 纵向滚动与横向锁定提示词

在宽度适配基础上，实现只能上下滑动。

## UIScrollView 配置

外层 Reader UIScrollView 是唯一滚动 owner，并满足：

```swift
scroll.alwaysBounceVertical = true
scroll.alwaysBounceHorizontal = false
scroll.showsVerticalScrollIndicator = true
scroll.showsHorizontalScrollIndicator = false
scroll.isDirectionalLockEnabled = true
```

Canvas 不得成为第二个滚动 owner：

```swift
canvas.isScrollEnabled = false
canvas.minimumZoomScale = 1
canvas.maximumZoomScale = 1
```

## 横向锁定

1. 清除用于居中页面的左右 contentInset。
2. 页面缩放后宽度与阅读区域一致，不制造横向内容范围。
3. 在 `scrollViewDidScroll` 中只修正横向 offset，不得重置 y：

```swift
if abs(scrollView.contentOffset.x) > 0.5 {
    scrollView.contentOffset.x = 0
}
```

4. 不得启用 `alwaysBounceHorizontal`。
5. 不得通过修改 canonical 坐标解决横向偏移。

## 纵向内容高度

验证内容高度仍为：

```text
pageCount × canonicalPageHeight
+ (pageCount - 1) × pageGap
```

固定 zoom 后内容高度自动增大。纵向滚动范围必须覆盖所有页面，但不能产生横向范围。

## 验收

- 手指上下滑动可以连续阅读；
- 手指左右滑动页面不移动；
- 斜向滑动不会导致页面持续横向漂移；
- 到达顶部和底部时无异常跳动；
- Pencil 书写时不改变外层纵向 offset；
- 页面外 gutter 不产生 ink。
