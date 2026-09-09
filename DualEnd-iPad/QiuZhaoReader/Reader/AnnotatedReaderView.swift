// AnnotatedReaderView —— A4 PDF-like Reader + PencilKit。
// Outer UIScrollView 是唯一滚动/缩放 owner；PageView 内的文字和 Canvas
// 共享同一 canonical page 坐标。页面外 gutter 不属于可写文档。
import UIKit
import PencilKit

protocol AnnotatedReaderDelegate: AnyObject {
    func readerInkChanged(_ view: AnnotatedReaderView)
    func readerNeedsFlush(_ view: AnnotatedReaderView)
}

/// PKCanvasView 本身是 UIScrollView 子类，但在这里只作为 document-space ink layer。
/// 通过 hitTest 把输入限制在 A4 白纸内部，避免页面外灰色 gutter 被误写。
final class PageCanvasView: PKCanvasView {
    var allowedPageRects: [CGRect] = []

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard allowedPageRects.contains(where: { $0.contains(point) }) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// 一张固定 A4 canonical page。正文 block 只在 page 内布局，背景/阴影与 Canvas 分层。
final class ReaderPageView: UIView {
    private let bodyView = UIView()
    private let pageNumberLabel = UILabel()

    init(index: Int, typography: ReaderTypography) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .systemBackground
        isUserInteractionEnabled = false
        layer.cornerRadius = 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)

        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.isUserInteractionEnabled = false
        addSubview(bodyView)

        pageNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        pageNumberLabel.text = "\(index + 1)"
        pageNumberLabel.font = .systemFont(ofSize: 9)
        pageNumberLabel.textColor = .secondaryLabel
        pageNumberLabel.textAlignment = .center
        addSubview(pageNumberLabel)

        NSLayoutConstraint.activate([
            bodyView.topAnchor.constraint(equalTo: topAnchor, constant: typography.topInset),
            bodyView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: typography.horizontalInset),
            bodyView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -typography.horizontalInset),
            bodyView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(typography.bottomInset + 18)),
            pageNumberLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageNumberLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func install(blocks: [UIView], gaps: [CGFloat]) {
        for child in bodyView.subviews { child.removeFromSuperview() }
        var previous: UIView?
        for (index, block) in blocks.enumerated() {
            block.translatesAutoresizingMaskIntoConstraints = false
            block.isUserInteractionEnabled = false
            bodyView.addSubview(block)
            NSLayoutConstraint.activate([
                block.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
                block.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
                block.topAnchor.constraint(equalTo: previous?.bottomAnchor ?? bodyView.topAnchor,
                                            constant: previous == nil ? 0 : (index < gaps.count ? gaps[index] : 0)),
            ])
            previous = block
        }
        if let previous {
            previous.bottomAnchor.constraint(equalTo: bodyView.bottomAnchor).isActive = true
        }
    }

}

final class AnnotatedReaderView: UIView {
    weak var delegate: AnnotatedReaderDelegate?
    let nodeId: String
    let canvas = PageCanvasView()
    let layoutSignature: String

    private let scroll = UIScrollView()
    private let contentView = UIView()
    private var contentHeightConstraint: NSLayoutConstraint!
    private let typography = ReaderTypography.shared
    private var pageRects: [CGRect] = []
    private var pageViews: [ReaderPageView] = []
    private var zoomInitialized = false
    private var inkDirty = false
    private var debounceWork: DispatchWorkItem?
    private(set) var currentInkRevision = 0

    private struct PreparedBlock {
        let view: UIView
        let gapBefore: CGFloat
    }

    init(nodeId: String, markdown: String) {
        self.nodeId = nodeId
        self.layoutSignature = typography.layoutSignature
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        build(markdown: markdown)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(markdown: String) {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.delegate = self
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.alwaysBounceHorizontal = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.minimumZoomScale = 0.5
        scroll.maximumZoomScale = 3
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scroll.addSubview(contentView)
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: typography.canonicalPageHeight)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalToConstant: typography.canonicalPageWidth),
            contentHeightConstraint,
        ])

        // 先放 page，再放 Canvas，确保 page background/文字不遮住 PencilKit。
        renderDocument(markdown)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.drawingPolicy = .pencilOnly
        canvas.isScrollEnabled = false
        canvas.contentInset = .zero
        canvas.contentOffset = .zero
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = self
        canvas.tool = PKInkingTool(.pen, color: .black, width: 2.5)
        canvas.accessibilityIdentifier = "ink-canvas-\(nodeId)"
        contentView.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        let available = bounds.insetBy(dx: 16, dy: 16)
        let fitScale = min(available.width / typography.canonicalPageWidth,
                           available.height / typography.canonicalPageHeight)
        let minimum = max(0.5, min(1, fitScale))
        if abs(scroll.minimumZoomScale - minimum) > 0.001 {
            scroll.minimumZoomScale = minimum
        }
        if !zoomInitialized {
            zoomInitialized = true
            scroll.setZoomScale(minimum, animated: false)
        }
        centerContent()
    }

    private func centerContent() {
        let scaledWidth = contentView.bounds.width * scroll.zoomScale
        let gutter = max(0, (scroll.bounds.width - scaledWidth) / 2)
        var inset = scroll.contentInset
        if abs(inset.left - gutter) > 0.5 || abs(inset.right - gutter) > 0.5 {
            inset.left = gutter
            inset.right = gutter
            scroll.contentInset = inset
            scroll.scrollIndicatorInsets = inset
        }
    }

    // MARK: A4 block pagination
    private func renderDocument(_ markdown: String) {
        for page in pageViews { page.removeFromSuperview() }
        pageViews.removeAll()
        let blocks = MarkdownParser.parse(markdown)
        var pageBlocks: [[PreparedBlock]] = [[]]
        var used: CGFloat = 0
        let available = typography.pageContentHeight

        for block in blocks {
            let view = view(for: block)
            let height = max(1, measuredHeight(of: view, width: typography.textColumnWidth))
            let gap = pageBlocks[pageBlocks.count - 1].isEmpty ? 0 : spacing(block)
            if !pageBlocks[pageBlocks.count - 1].isEmpty && used + gap + height > available {
                pageBlocks.append([])
                used = 0
            }
            let gapBefore = pageBlocks[pageBlocks.count - 1].isEmpty ? 0 : gap
            pageBlocks[pageBlocks.count - 1].append(PreparedBlock(view: view, gapBefore: gapBefore))
            used += gapBefore + height
        }
        if pageBlocks.count == 1 && pageBlocks[0].isEmpty { pageBlocks = [[]] }

        let step = typography.canonicalPageHeight + typography.pageGap
        pageRects = pageBlocks.indices.map {
            CGRect(x: 0, y: CGFloat($0) * step,
                   width: typography.canonicalPageWidth,
                   height: typography.canonicalPageHeight)
        }
        contentHeightConstraint.constant = max(typography.canonicalPageHeight,
                                                CGFloat(pageBlocks.count) * typography.canonicalPageHeight
                                                + CGFloat(max(0, pageBlocks.count - 1)) * typography.pageGap)
        for (index, blocksForPage) in pageBlocks.enumerated() {
            let page = ReaderPageView(index: index, typography: typography)
            page.install(blocks: blocksForPage.map(\.view), gaps: blocksForPage.map(\.gapBefore))
            contentView.addSubview(page)
            NSLayoutConstraint.activate([
                page.topAnchor.constraint(equalTo: contentView.topAnchor,
                                          constant: CGFloat(index) * step),
                page.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                page.widthAnchor.constraint(equalToConstant: typography.canonicalPageWidth),
                page.heightAnchor.constraint(equalToConstant: typography.canonicalPageHeight),
            ])
            pageViews.append(page)
        }
        canvas.allowedPageRects = pageRects
    }

    private func measuredHeight(of view: UIView, width: CGFloat) -> CGFloat {
        view.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = view.widthAnchor.constraint(equalToConstant: width)
        widthConstraint.isActive = true
        let size = view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel)
        widthConstraint.isActive = false
        return size.height
    }

    private func spacing(_ block: MDBlock) -> CGFloat {
        if case .heading = block { return 14 }
        if case .paragraph = block { return typography.paragraphSpacing }
        return 10
    }

    private func view(for block: MDBlock) -> UIView {
        switch block {
        case .heading(let level, let text):
            let label = UILabel()
            label.numberOfLines = 0
            label.text = text
            label.font = .boldSystemFont(ofSize: level == 1 ? typography.h1Size : typography.h2Size)
            label.textColor = level == 1 ? .label : .systemBlue
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            if level <= 2 {
                let wrapper = UIView()
                let bar = UIView()
                bar.translatesAutoresizingMaskIntoConstraints = false
                bar.backgroundColor = level == 1 ? .label : .systemBlue
                wrapper.addSubview(bar)
                label.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(label)
                NSLayoutConstraint.activate([
                    bar.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                    bar.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    bar.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                    bar.widthAnchor.constraint(equalToConstant: 4),
                    label.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 14),
                    label.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                    label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                ])
                return wrapper
            }
            return label
        case .paragraph(let text):
            let label = UILabel()
            label.numberOfLines = 0
            label.attributedText = attributed(text, font: regularFont(), color: .label, alignment: .justified)
            return label
        case .list(let text):
            let label = UILabel()
            label.numberOfLines = 0
            label.attributedText = attributed("•  " + text, font: regularFont(), color: .label, alignment: .left)
            return label
        case .code(let code):
            let textView = UITextView()
            textView.text = code
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.font = .monospacedSystemFont(ofSize: typography.codeFontSize, weight: .regular)
            textView.textContainerInset = UIEdgeInsets(top: 8, left: typography.codeBlockInset,
                                                        bottom: 8, right: typography.codeBlockInset)
            textView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.65)
            return textView
        case .quote(let text):
            let label = UILabel()
            label.numberOfLines = 0
            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = typography.blockquoteInset
            style.headIndent = typography.blockquoteInset
            style.lineSpacing = typography.bodyLineSpacing
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: UIFont.italicSystemFont(ofSize: typography.bodyFontSize),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: style,
            ])
            return label
        case .hr:
            let line = UIView()
            line.heightAnchor.constraint(equalToConstant: 1).isActive = true
            line.backgroundColor = .separator
            return line
        case .table(let headers, let rows):
            return tableCell(headers: headers, rows: rows)
        }
    }

    private func regularFont() -> UIFont {
        UIFont(name: "PingFangSC-Regular", size: typography.bodyFontSize)
            ?? .systemFont(ofSize: typography.bodyFontSize)
    }

    private func attributed(_ text: String, font: UIFont, color: UIColor,
                            alignment: NSTextAlignment) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = typography.bodyLineSpacing
        style.paragraphSpacing = 2
        style.alignment = alignment
        return NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style,
        ])
    }

    private func tableCell(headers: [String], rows: [[String]]) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        func rowCell(_ cells: [String], header: Bool) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            for cell in cells {
                let label = UILabel()
                label.numberOfLines = 0
                label.text = cell
                label.font = .systemFont(ofSize: typography.bodyFontSize - 2,
                                         weight: header ? .bold : .regular)
                label.layer.borderWidth = 0.5
                label.layer.borderColor = UIColor.separator.cgColor
                label.textAlignment = .left
                row.addArrangedSubview(label)
            }
            return row
        }
        stack.addArrangedSubview(rowCell(headers, header: true))
        for row in rows { stack.addArrangedSubview(rowCell(row, header: false)) }
        return stack
    }

    func loadInk(drawing: PKDrawing?, revision: Int) {
        canvas.drawing = drawing ?? PKDrawing()
        canvas.contentInset = .zero
        canvas.contentOffset = .zero
        canvas.zoomScale = 1
        currentInkRevision = revision
        inkDirty = false
    }

    func flushIfDirty() {
        guard inkDirty else { return }
        inkDirty = false
        currentInkRevision += 1
        delegate?.readerNeedsFlush(self)
    }

    func setEraser(_ eraser: Bool) {
        canvas.tool = eraser ? PKEraserTool(.vector)
                             : PKInkingTool(.pen, color: .black, width: 2.5)
    }
}

extension AnnotatedReaderView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        inkDirty = true
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushIfDirty() }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        delegate?.readerInkChanged(self)
    }
}

extension AnnotatedReaderView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }
}
