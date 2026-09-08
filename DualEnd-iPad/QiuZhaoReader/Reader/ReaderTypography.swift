// ReaderTypography —— 全部排版数值集中一处 (M-8.1)。参考 PDF 缺失: 数值未冻结,
// 排版匹配 PDF 验收项 = BLOCKED_BY_MISSING_INPUT (禁止伪造)。
import CoreGraphics

struct ReaderTypography {
    // 固定 canonical page width: 旋转/窗口变化只变外围留白, 不变正文宽度 (ADR-008)
    let canonicalPageWidth: CGFloat = 720
    let horizontalInset: CGFloat = 24
    let bodyFontSize: CGFloat = 17
    let bodyLineSpacing: CGFloat = 6
    let paragraphSpacing: CGFloat = 12
    let h1Size: CGFloat = 26
    let h2Size: CGFloat = 21
    let codeFontSize: CGFloat = 14
    let codeBlockInset: CGFloat = 16
    let blockquoteInset: CGFloat = 14

    static let shared = ReaderTypography()
}
