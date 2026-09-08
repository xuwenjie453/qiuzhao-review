# ReaderTypography 合同

所有 layout 数值集中：
```text
canonicalPageWidth
horizontalInset
bodyFontSize
bodyLineSpacing
paragraphSpacing
h1Size
h2Size
codeFontSize
codeBlockInset
blockquoteInset
```

当前没有参考 PDF：
- 可以给 development default；
- 不可命名/声明为 matched；
- Release Gate blocked。

未来 PDF 到达：
- 只调 token；
- 不重写 Reader/Ink coordinate architecture；
- 新 token 若改变 layout signature，需明确旧 Ink compatibility 策略；设计目标是通过 canonical width 最大化稳定。
