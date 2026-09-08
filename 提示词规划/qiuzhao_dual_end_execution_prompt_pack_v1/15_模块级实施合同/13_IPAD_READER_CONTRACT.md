# AnnotatedReaderView 合同

推荐结构：
```text
UIScrollView (only scroll owner)
  ContentCoordinateView(canonicalPageWidth, contentHeight)
    MarkdownRenderedView
    PKCanvasView transparent overlay, exact same bounds
```

要求：
- body immutable；
- Reader 不提供 text editing；
- contentHeight 由 Markdown layout 计算并同时赋给 Ink canvas；
- canonical width 固定，横屏外层 gutter；
- body/token/width 形成 layout signature；
- 相同 signature 下 reopen 后 Ink 位置稳定。

不得：
- Markdown 一个 scroll、PencilKit 一个 scroll，再同步 offset；
- 让 dynamic type 随系统任意变化导致旧 Ink 坐标重排，除非有迁移策略。本版本优先固定阅读 typography token。
