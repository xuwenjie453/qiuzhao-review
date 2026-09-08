// AnnotatedReaderView —— 单一坐标系的 Reader (ADR-008/M-8.3)。
// UIScrollView(唯一滚动 owner) → ContentCoordinateView(fixed canonical width, 计算高度)
//   → MarkdownRenderedView(只读) + PKCanvasView(透明 ink, 同 bounds)。
// 正文与 Ink 共用同一 bounds: 禁止双滚动源硬同步(会漂移)。
import UIKit
import PencilKit

protocol AnnotatedReaderDelegate: AnyObject {
    func readerInkChanged(_ view: AnnotatedReaderView)
    func readerNeedsFlush(_ view: AnnotatedReaderView)
}

final class AnnotatedReaderView: UIView {
    weak var delegate: AnnotatedReaderDelegate?
    let nodeId: String

    private let scroll = UIScrollView()
    private let contentView = UIView()          // ContentCoordinateView
    private let markdownView = UIView()         // 正文渲染(只读)
    let canvas = PKCanvasView()

    private var inkDirty = false
    private var debounceWork: DispatchWorkItem?
    private let typography = ReaderTypography.shared

    init(nodeId: String, markdown: String) {
        self.nodeId = nodeId
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        build(markdown: markdown)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: 构建
    private func build(markdown: String) {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.delegate = self
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(contentView)
        // 固定 canonical page width: 宽屏只加 gutter
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalToConstant: typography.canonicalPageWidth),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
        ])

        markdownView.translatesAutoresizingMaskIntoConstraints = false
        markdownView.isUserInteractionEnabled = false
        contentView.addSubview(markdownView)
        NSLayoutConstraint.activate([
            markdownView.topAnchor.constraint(equalTo: contentView.topAnchor),
            markdownView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: typography.horizontalInset),
            markdownView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -typography.horizontalInset),
        ])
        renderMarkdown(markdown, into: markdownView)

        // Ink surface: 同一 contentView bounds
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.drawingPolicy = .pencilOnly          // M: finger 滚动, pencil 写
        canvas.isScrollEnabled = false              // PKCanvasView 是 UIScrollView 子类: 禁用内层滚动, 外层唯一滚动
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = self
        canvas.tool = PKInkingTool(.pen, color: .black, width: 2.5)
        contentView.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: Markdown 渲染(block 布局; body immutable → 稳定底纸)
    private func renderMarkdown(_ md: String, into container: UIView) {
        var lastView: UIView?
        let blocks = MarkdownParser.parse(md)
        for block in blocks {
            let v = view(for: block)
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
            if let last = lastView {
                v.topAnchor.constraint(equalTo: last.bottomAnchor, constant: spacing(block)).isActive = true
            } else {
                v.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
            }
            v.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
            v.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
            lastView = v
        }
        if let last = lastView {
            last.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24).isActive = true
        }
    }

    private func spacing(_ b: MDBlock) -> CGFloat {
        if case .heading = b { return 14 }
        if case .paragraph = b { return typography.paragraphSpacing }
        return 10
    }

    private func view(for block: MDBlock) -> UIView {
        switch block {
        case .heading(let level, let text):
            let l = UILabel()
            l.numberOfLines = 0
            l.text = text
            l.font = .boldSystemFont(ofSize: level == 1 ? typography.h1Size : typography.h2Size)
            return l
        case .paragraph(let text):
            let l = UILabel()
            l.numberOfLines = 0
            l.text = text
            l.font = .systemFont(ofSize: typography.bodyFontSize)
            return l
        case .list(let text):
            let l = UILabel()
            l.numberOfLines = 0
            l.text = "•  " + text
            l.font = .systemFont(ofSize: typography.bodyFontSize)
            return l
        case .code(let code):
            let tv = UITextView()
            tv.text = code
            tv.isEditable = false
            tv.isScrollEnabled = false
            tv.font = .monospacedSystemFont(ofSize: typography.codeFontSize, weight: .regular)
            tv.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
            tv.textContainerInset = UIEdgeInsets(top: 8, left: typography.codeBlockInset, bottom: 8, right: typography.codeBlockInset)
            return tv
        case .quote(let text):
            let l = UILabel()
            l.numberOfLines = 0
            l.text = text
            l.font = .italicSystemFont(ofSize: typography.bodyFontSize)
            l.textColor = .secondaryLabel
            l.leftInset = typography.blockquoteInset
            return l
        case .hr:
            let v = UIView()
            v.heightAnchor.constraint(equalToConstant: 1).isActive = true
            v.backgroundColor = .separator
            return v
        case .table(let headers, let rows):
            return tableCell(headers: headers, rows: rows)
        }
    }

    private func tableCell(headers: [String], rows: [[String]]) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        func rowCell(_ cells: [String], isHeader: Bool) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 0
            for c in cells {
                let l = UILabel()
                l.text = c
                l.font = .systemFont(ofSize: typography.bodyFontSize - 2, weight: isHeader ? .bold : .regular)
                l.numberOfLines = 0
                l.widthAnchor.constraint(equalToConstant: typography.canonicalPageWidth / max(1, CGFloat(cells.count)) - 40).isActive = true
                row.addArrangedSubview(l)
            }
            return row
        }
        stack.addArrangedSubview(rowCell(headers, isHeader: true))
        for r in rows { stack.addArrangedSubview(rowCell(r, isHeader: false)) }
        return stack
    }

    // MARK: Ink 装载/保存 (node_id 绑定)
    func loadInk(drawing: PKDrawing?, revision: Int) {
        canvas.drawing = drawing ?? PKDrawing()
        currentInkRevision = revision
        inkDirty = false
    }
    private(set) var currentInkRevision = 0

    func flushIfDirty() {
        guard inkDirty else { return }
        inkDirty = false
        currentInkRevision += 1
        delegate?.readerNeedsFlush(self)
    }

    func setEraser(_ eraser: Bool) {
        if eraser {
            canvas.tool = PKEraserTool(.vector)
        } else {
            canvas.tool = PKInkingTool(.pen, color: .black, width: 2.5)
        }
    }
}

extension AnnotatedReaderView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        inkDirty = true
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flushIfDirty()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        delegate?.readerInkChanged(self)
    }
}

extension AnnotatedReaderView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) { /* 唯一滚动源, 无同步需求 */ }
}

extension UILabel {
    private struct LeftInsetKey { static var key = 0 }
    var leftInset: CGFloat {
        get { (objc_getAssociatedObject(self, &LeftInsetKey.key) as? CGFloat) ?? 0 }
        set {
            objc_setAssociatedObject(self, &LeftInsetKey.key, newValue, .OBJC_ASSOCIATION_RETAIN)
            textAlignment = .left
            // 用 paragraph style 实现缩进(简单近似)
            if let t = text {
                let ps = NSMutableParagraphStyle()
                ps.firstLineHeadIndent = newValue
                ps.headIndent = newValue
                attributedText = NSAttributedString(string: t, attributes: [.paragraphStyle: ps])
            }
        }
    }
}
