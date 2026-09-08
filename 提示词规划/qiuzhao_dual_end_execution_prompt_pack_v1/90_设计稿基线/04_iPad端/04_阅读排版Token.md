# Reader Typography Tokens

用户指定“字体大小和两侧留白参照已上传 PDF”。当前交付输入没有该 PDF，因此这里只冻结 token 和校准流程，不伪造最终值。

## 1. Token

```swift
struct ReaderTypography {
    let canonicalPageWidth: CGFloat
    let horizontalInset: CGFloat
    let bodyFontSize: CGFloat
    let bodyLineSpacing: CGFloat
    let paragraphSpacing: CGFloat
    let h1Size: CGFloat
    let h2Size: CGFloat
    let codeFontSize: CGFloat
    let codeBlockInset: CGFloat
    let blockquoteInset: CGFloat
}
```

初始实现中所有数值集中一处，不散落 View。

## 2. PDF 校准流程

拿到参考 PDF 后：

1. 在 100% 显示尺度测量正文 column 相对页面宽度；
2. 估算正文 x-height/字号；
3. 记录段间距、行距、标题层级；
4. 在 11"/13" iPad 真机截图并排对比；
5. 只调 token，直到阅读密度接近；
6. 冻结为 `ReaderTypography.referencePDF_v1`。

## 3. Release Gate

没有参考 PDF 时可以完成功能开发，但“版式匹配 PDF”验收项状态只能是 `BLOCKED_BY_MISSING_INPUT`，不能标 PASS。
