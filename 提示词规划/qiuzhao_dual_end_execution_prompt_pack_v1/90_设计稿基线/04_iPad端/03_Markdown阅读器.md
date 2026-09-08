# Markdown Reader 设计

## 1. 不变量

Node Body 一旦 commit 不变。Reader 因此可把“正文布局坐标”视为 Ink 的稳定底纸。

## 2. 渲染范围

必须支持秋招解释常见 Markdown：

- headings；
- paragraphs；
- bold/italic；
- ordered/unordered list；
- inline code；
- fenced code block；
- blockquote；
- links；
- horizontal rule；
- simple tables（若现有 Agent 输出出现）。

仅 `AttributedString(markdown:)` 对复杂块级布局不足时，使用自建 block parser/renderer；不要引入 WebView 作为默认实现，因为 WebView 与 Pencil overlay 的内容高度、选择和滚动坐标更难稳定。若决定复用 reading-system 已有 Reader renderer，应保持协议层与本设计不变量不变。

## 3. 单一坐标系

推荐 UIKit `AnnotatedReaderView`：

```text
UIScrollView (唯一滚动 owner)
  └── ContentCoordinateView (fixed width, calculated height)
       ├── MarkdownRenderedView (read-only)
       └── PKCanvasView / InkSurface (transparent, same bounds)
```

关键：正文和 Ink 共用同一 `ContentCoordinateView.bounds`。禁止两个独立 scroll view 各自滚动再靠 contentOffset 同步，否则高速滚动/缩放会产生笔迹漂移。

## 4. 页面宽度

阅读内容宽度 = viewportWidth - 2 * horizontalInset。

所有 typography/layout token 参与一个 `layout_signature`。只要 body、width class、font token 未变，节点 Ink 坐标就稳定。

## 5. 旋转

横竖屏切换会改变正文换行，从而改变 Ink 对齐。因此 v1 推荐：**Reader 固定使用设计参考的阅读宽度 column，横屏增加外侧 gutter，而不是让正文 column 无限变宽。**这样同一 node 的正文行折叠基本稳定。

如果尺寸类变化仍导致 layout_signature 变化，Reader 应保持固定 canonical page width 并对外层居中，而不是重排后硬套旧 ink。
