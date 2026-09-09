// ReaderTypography —— 全部排版数值集中一处 (M-8.1)。
// 参考《物理与数学的对应关系》PDF：宽留白、较大正文、粗体层级标题。
import CoreGraphics

struct ReaderTypography {
    // 固定 canonical page width: 旋转/窗口变化只变外围留白, 不变正文宽度 (ADR-008)
    // 以 iPad Air 11" 竖屏宽度为基准，完整页面（含两侧批注留白）可写。
    let canonicalPageWidth: CGFloat = 820
    let textColumnWidth: CGFloat = 700
    let topInset: CGFloat = 38
    let bodyFontSize: CGFloat = 20
    let bodyLineSpacing: CGFloat = 8
    let paragraphSpacing: CGFloat = 16
    let h1Size: CGFloat = 34
    let h2Size: CGFloat = 24
    let codeFontSize: CGFloat = 14
    let codeBlockInset: CGFloat = 16
    let blockquoteInset: CGFloat = 14

    static let shared = ReaderTypography()
}
