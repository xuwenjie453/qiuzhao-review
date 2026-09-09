// ReaderTypography —— A4 PDF-like Reader 的唯一排版 token。
// 页面坐标使用 PDF A4 canonical points；屏幕方向只改变外层缩放。
import CoreGraphics

struct ReaderTypography {
    // A4 页面尺寸，来自参考 PDF 的实际 MediaBox。
    let canonicalPageWidth: CGFloat = 595.92
    let canonicalPageHeight: CGFloat = 842.88
    // 参考 PDF 正文左右约 41.5pt，正文列约占页面宽度的 86%。
    let horizontalInset: CGFloat = 41.5
    let topInset: CGFloat = 82
    let bottomInset: CGFloat = 42
    let pageGap: CGFloat = 24
    let bodyFontSize: CGFloat = 18
    let bodyLineSpacing: CGFloat = 7
    let paragraphSpacing: CGFloat = 16
    let h1Size: CGFloat = 34
    let h2Size: CGFloat = 25
    let codeFontSize: CGFloat = 14
    let codeBlockInset: CGFloat = 16
    let blockquoteInset: CGFloat = 14

    var textColumnWidth: CGFloat { canonicalPageWidth - 2 * horizontalInset }
    var pageContentHeight: CGFloat { canonicalPageHeight - topInset - bottomInset }

    // body 与 token 组成稳定的 ink 底纸签名；屏幕方向/缩放不参与签名。
    var layoutSignature: String {
        "a4-v2|w=\(canonicalPageWidth)|h=\(canonicalPageHeight)|inset=\(horizontalInset)|top=\(topInset)|body=\(bodyFontSize)|line=\(bodyLineSpacing)|h1=\(h1Size)|h2=\(h2Size)"
    }

    static let shared = ReaderTypography()
}
