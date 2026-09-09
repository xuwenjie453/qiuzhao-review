// AnnotatedReaderView —— A4 PDF-like Reader + PencilKit。
// Outer UIScrollView 是唯一滚动/缩放 owner；PageView 内的文字和 Canvas
// 共享同一 canonical page 坐标。页面外 gutter 不属于可写文档。
import UIKit
import PencilKit
#if DEBUG
import os
#endif

/// Pure viewport math shared by the UIKit implementation and unit tests.
/// Document coordinates remain canonical; only the display scale changes.
enum ReaderViewportMath {
    static func fitWidthScale(viewportWidth: CGFloat, pageWidth: CGFloat,
                              minimum: CGFloat = 0.5, maximum: CGFloat = 3.0) -> CGFloat {
        guard viewportWidth > 0, pageWidth > 0 else { return minimum }
        return min(max(viewportWidth / pageWidth, minimum), maximum)
    }

    static func canonicalTopY(contentOffsetY: CGFloat, scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return 0 }
        return max(0, contentOffsetY / scale)
    }

    static func clampedOffsetY(canonicalTopY: CGFloat, scale: CGFloat,
                               contentSizeHeight: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let proposed = max(0, canonicalTopY) * max(scale, 0)
        let maximum = max(0, contentSizeHeight - viewportHeight)
        return min(max(proposed, 0), maximum)
    }
}

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
    private enum ViewportState { case uninitialized, fittedAtTop, fittedPreservingPosition }
    private var viewportState: ViewportState = .uninitialized
    private var lastViewportSize: CGSize = .zero
    private var isApplyingViewport = false
    private var inkDirty = false
    private var debounceWork: DispatchWorkItem?
    private(set) var currentInkRevision = 0
    #if DEBUG
    private var probeFileHandle: FileHandle?
    #endif

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
        scroll.alwaysBounceVertical = true
        scroll.alwaysBounceHorizontal = false
        scroll.bounces = true
        scroll.isDirectionalLockEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = true
        scroll.contentInset = .zero
        scroll.scrollIndicatorInsets = .zero
        scroll.minimumZoomScale = 0.5
        scroll.maximumZoomScale = 3
        scroll.pinchGestureRecognizer?.isEnabled = false
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

        #if DEBUG
        installHoverProbe()
        #endif
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard scroll.bounds.width > 1, scroll.bounds.height > 1,
              !isApplyingViewport else { return }
        let size = scroll.bounds.size
        switch viewportState {
        case .uninitialized:
            applyViewport(resetToTop: true)
            viewportState = .fittedAtTop
            #if DEBUG
            probeSnapshot(event: "viewport-first-fit")
            #endif
        case .fittedAtTop, .fittedPreservingPosition:
            let changed = abs(size.width - lastViewportSize.width) > 0.5
                || abs(size.height - lastViewportSize.height) > 0.5
            if changed {
                applyViewport(resetToTop: false)
                viewportState = .fittedPreservingPosition
            } else {
                lockHorizontalOffset()
            }
        }
        lastViewportSize = size
    }

    private func applyViewport(resetToTop: Bool) {
        guard scroll.bounds.width > 1, scroll.bounds.height > 1 else { return }
        isApplyingViewport = true
        defer { isApplyingViewport = false }

        let oldScale = max(scroll.zoomScale, 0.001)
        let oldCanonicalTop = resetToTop
            ? 0
            : ReaderViewportMath.canonicalTopY(contentOffsetY: scroll.contentOffset.y,
                                               scale: oldScale)
        let targetScale = ReaderViewportMath.fitWidthScale(
            viewportWidth: scroll.bounds.width,
            pageWidth: typography.canonicalPageWidth)

        scroll.contentInset = .zero
        scroll.scrollIndicatorInsets = .zero
        scroll.minimumZoomScale = targetScale
        scroll.maximumZoomScale = targetScale
        scroll.setZoomScale(targetScale, animated: false)
        scroll.layoutIfNeeded()

        let newY = resetToTop
            ? 0
            : ReaderViewportMath.clampedOffsetY(
                canonicalTopY: oldCanonicalTop,
                scale: targetScale,
                contentSizeHeight: scroll.contentSize.height,
                viewportHeight: scroll.bounds.height)
        scroll.setContentOffset(CGPoint(x: 0, y: newY), animated: false)
        lockHorizontalOffset()
    }

    private func lockHorizontalOffset() {
        guard !isApplyingViewport else { return }
        if abs(scroll.contentOffset.x) > 0.5 {
            scroll.contentOffset.x = 0
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

    #if DEBUG
    func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
        probeSnapshot(event: "render-finished")
    }
    #endif
}

extension AnnotatedReaderView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentView }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        lockHorizontalOffset()
    }
}

// MARK: - Phase 0 只读取证探针（v3 包 04 号）
// 记录 hover 事件与双重视口几何到 Documents/hover-probe.jsonl；不绘制任何
// 假笔迹/覆盖层，不改变正式行为；按 11 号交付报告明示移除或保留。
#if DEBUG
extension AnnotatedReaderView {
    func installHoverProbe() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("hover-probe.jsonl")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        probeFileHandle = FileHandle(forWritingAtPath: url.path)
        probeFileHandle?.seekToEndOfFile()
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(hoverProbeFired(_:)))
        hover.cancelsTouchesInView = false
        addGestureRecognizer(hover)
    }

    @objc private func hoverProbeFired(_ g: UIHoverGestureRecognizer) {
        let phase: String
        switch g.state {
        case .began: phase = "began"
        case .changed: phase = "changed"
        case .ended: phase = "ended"
        case .cancelled: phase = "cancelled"
        default: phase = "other"
        }
        var line: [String: Any] = [
            "event": "hover",
            "phase": phase,
            "loc_self": [Double(g.location(in: self).x), Double(g.location(in: self).y)],
            "loc_canvas": [Double(g.location(in: canvas).x), Double(g.location(in: canvas).y)],
        ]
        if let w = window {
            line["loc_window"] = [Double(g.location(in: w).x), Double(g.location(in: w).y)]
        }
        if g.responds(to: NSSelectorFromString("zOffset")),
           let z = g.value(forKey: "zOffset") as? Double {
            line["z_offset"] = z
        }
        line.merge(probeGeometry()) { a, _ in a }
        probeWrite(line)
    }

    func probeSnapshot(event: String) {
        var line: [String: Any] = ["event": event]
        line.merge(probeGeometry()) { a, _ in a }
        probeWrite(line)
    }

    private func probeGeometry() -> [String: Any] {
        func pt(_ p: CGPoint) -> [Double] { [Double(p.x), Double(p.y)] }
        func rect(_ r: CGRect) -> [Double] {
            [Double(r.minX), Double(r.minY), Double(r.width), Double(r.height)]
        }
        func affine(_ t: CGAffineTransform?) -> [Double]? {
            guard let t else { return nil }
            return [Double(t.a), Double(t.b), Double(t.c), Double(t.d), Double(t.tx), Double(t.ty)]
        }
        var g: [String: Any] = [
            "scroll_zoom": Double(scroll.zoomScale),
            "canvas_zoom": Double(canvas.zoomScale),
            "scroll_offset": pt(scroll.contentOffset),
            "canvas_offset": pt(canvas.contentOffset),
            "scroll_bounds": rect(scroll.bounds),
            "canvas_bounds": rect(canvas.bounds),
            "canvas_frame": rect(canvas.frame),        // canvas 在 contentView 坐标系（旧架构随外层 zoom 变化）
            "content_frame": rect(contentView.frame),  // zooming view frame == canonical×zoom 的直接证据
            "content_bounds": rect(contentView.bounds),
        ]
        if let t = scroll.layer.presentation()?.affineTransform() { g["scroll_present"] = affine(t) }
        if let t = canvas.layer.presentation()?.affineTransform() { g["canvas_present"] = affine(t) }
        g["content_affine"] = affine(contentView.layer.affineTransform())
        return g
    }

    private func probeWrite(_ line: [String: Any]?) {
        guard var line, let handle = probeFileHandle else { return }
        line["ts"] = Date().timeIntervalSince1970
        guard let out = try? JSONSerialization.data(withJSONObject: line) else { return }
        handle.write(out)
        handle.write(Data("\n".utf8))
        os_log("[hover-probe] %{public}@",
               String(data: out, encoding: .utf8) ?? "")
    }
}
#endif
