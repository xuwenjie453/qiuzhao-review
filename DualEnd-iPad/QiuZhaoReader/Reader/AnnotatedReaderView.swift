// AnnotatedReaderView —— A4 PDF-like Reader + PencilKit。
// PKCanvasView 是唯一滚动/缩放 owner；只读正文作为它的同步底层镜像层。
// Pencil hover、书写中墨迹与历史 PKDrawing 因此共享同一显示变换
// screen(P) = P·z − contentOffset（v3 包 02 冻结契约，单一变换根因修复）。
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

    /// viewport 系(不含滚动) ↔ canonical。
    static func displayPoint(from canonical: CGPoint, scale: CGFloat,
                             contentOffset: CGPoint) -> CGPoint {
        CGPoint(x: canonical.x * scale - contentOffset.x,
                y: canonical.y * scale - contentOffset.y)
    }

    static func canonicalPoint(from display: CGPoint, scale: CGFloat,
                               contentOffset: CGPoint) -> CGPoint {
        let safeScale = max(scale, 0.001)
        return CGPoint(x: (display.x + contentOffset.x) / safeScale,
                       y: (display.y + contentOffset.y) / safeScale)
    }

    /// UIScrollView 的 contentSize 语义是“当前缩放下的内容尺寸”= display 单位。
    /// 单位约定由单测钉死（v3 包 06 缺陷 #1 的防回归）。
    static func displayContentSize(documentSize: CGSize, scale: CGFloat) -> CGSize {
        CGSize(width: documentSize.width * scale,
               height: documentSize.height * scale)
    }

    /// 文档镜像层几何：anchorPoint=(0,0) 时 canonical P 渲染于 position + P·scale，
    /// 与 Canvas 的 P·z − contentOffset 完全一致（02 冻结不变量）。
    static func documentLayerPosition(contentOffset: CGPoint) -> CGPoint {
        CGPoint(x: -contentOffset.x, y: -contentOffset.y)
    }

    static func documentLayerTransform(scale: CGFloat) -> CGAffineTransform {
        CGAffineTransform(scaleX: scale, y: scale)
    }
}

protocol AnnotatedReaderDelegate: AnyObject {
    func readerInkChanged(_ view: AnnotatedReaderView)
    func readerNeedsFlush(_ view: AnnotatedReaderView)
}

/// PKCanvasView 同时拥有 PencilKit drawing viewport 和 Reader 的纵向滚动。
/// 手指始终可滚动；只有 Pencil 落笔才受 A4 白纸范围限制。
final class PageCanvasView: PKCanvasView {
    var allowedPageRects: [CGRect] = []

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let touch = event?.allTouches?.first, touch.type == .pencil {
            // hitTest point 与 location(in:) 同处 canvas bounds 坐标系；UIScrollView 的
            // bounds.origin == contentOffset，原点已随滚动移动 → canonical 换算只除
            // zoomScale，不再加 contentOffset（加了是双重计算）。
            let documentPoint = ReaderViewportMath.canonicalPoint(
                from: point, scale: zoomScale, contentOffset: .zero)
            guard allowedPageRects.contains(where: { $0.contains(documentPoint) }) else {
                return nil
            }
        }
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

    /// 文档镜像层：非交互兄弟层，承载 ReaderPageView；几何由 syncDocumentMirror
    /// 从 Canvas 视口单向镜像（anchor .zero + position −offset + scale z）。
    /// （internal + @testable 供冒烟测试断言镜像几何。）
    let contentView = UIView()
    private let typography = ReaderTypography.shared
    private var pageRects: [CGRect] = []
    private(set) var pageViews: [ReaderPageView] = []
    private(set) var documentSize: CGSize
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
        self.documentSize = CGSize(width: typography.canonicalPageWidth,
                                   height: typography.canonicalPageHeight)
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        build(markdown: markdown)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(markdown: String) {
        // 1) 文档镜像层：手动几何（不参与 autolayout 定位），只作为 Canvas 的只读底衬。
        contentView.translatesAutoresizingMaskIntoConstraints = true
        contentView.backgroundColor = .clear
        contentView.isUserInteractionEnabled = false
        contentView.bounds = CGRect(origin: .zero, size: documentSize)
        contentView.layer.anchorPoint = .zero
        contentView.layer.position = .zero
        addSubview(contentView)

        // 2) 正文页装入镜像层（canonical 坐标，不随显示缩放变化）。
        renderDocument(markdown)

        // 3) Canvas：唯一滚动/缩放 owner。frame 由 layoutSubviews 手动铺满
        //    （本视图子树零内部约束，完全不进 autolayout 引擎——否则引擎会为
        //    translates=true 的镜像层生成固定约束并每轮回写 frame，与手写镜像
        //    几何互相触发重排，真机 runloop 下形成主线程布局死循环）。
        canvas.translatesAutoresizingMaskIntoConstraints = true
        canvas.drawingPolicy = .pencilOnly
        canvas.allowsFingerDrawing = false
        canvas.isScrollEnabled = true
        canvas.bounces = true
        canvas.alwaysBounceHorizontal = false
        canvas.alwaysBounceVertical = true
        canvas.isDirectionalLockEnabled = true
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.showsHorizontalScrollIndicator = false
        canvas.showsVerticalScrollIndicator = true
        canvas.contentInset = .zero
        canvas.scrollIndicatorInsets = .zero
        canvas.contentOffset = .zero
        canvas.minimumZoomScale = 0.5
        canvas.maximumZoomScale = 3
        canvas.pinchGestureRecognizer?.isEnabled = false
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = self
        canvas.tool = PKInkingTool(.pen, color: .black, width: 2.5)
        canvas.accessibilityIdentifier = "ink-canvas-\(nodeId)"
        addSubview(canvas)

        #if DEBUG
        installHoverProbe()
        #endif
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1,
              !isApplyingViewport else { return }
        // 内部纯 frame 布局：canvas 铺满、镜像层手动几何，子树零约束。
        canvas.frame = bounds
        guard canvas.bounds.width > 1, canvas.bounds.height > 1 else { return }
        let size = canvas.bounds.size
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
                // 兜底重申：对抗 translates 视图被 autolayout 回写 frame 的一过性竞争。
                lockHorizontalOffset()
                syncDocumentMirror()
            }
        }
        lastViewportSize = size
    }

    /// 唯一允许写 Canvas 视口几何的入口。顺序冻结（v3 包 05 §二）：
    /// zoom → contentSize(display 单位) → clamp offset。
    private func applyViewport(resetToTop: Bool) {
        guard canvas.bounds.width > 1, canvas.bounds.height > 1 else { return }
        isApplyingViewport = true
        defer { isApplyingViewport = false }

        let oldScale = max(canvas.zoomScale, 0.001)
        let oldCanonicalTop = resetToTop
            ? 0
            : ReaderViewportMath.canonicalTopY(contentOffsetY: canvas.contentOffset.y,
                                               scale: oldScale)
        let z = ReaderViewportMath.fitWidthScale(
            viewportWidth: canvas.bounds.width,
            pageWidth: typography.canonicalPageWidth)

        canvas.contentInset = .zero
        canvas.scrollIndicatorInsets = .zero
        canvas.minimumZoomScale = z
        canvas.maximumZoomScale = z
        canvas.setZoomScale(z, animated: false)
        // contentSize 必须以生效后的 z 计算（display 单位 = canonical × z）。
        canvas.contentSize = ReaderViewportMath.displayContentSize(
            documentSize: documentSize, scale: z)
        canvas.layoutIfNeeded()

        // offset 夹取放在 contentSize 确定之后（旋转保持阅读位置）。
        let newY = resetToTop
            ? 0
            : ReaderViewportMath.clampedOffsetY(
                canonicalTopY: oldCanonicalTop,
                scale: z,
                contentSizeHeight: canvas.contentSize.height,
                viewportHeight: canvas.bounds.height)
        canvas.setContentOffset(CGPoint(x: 0, y: newY), animated: false)
        lockHorizontalOffset()
        syncDocumentMirror()
    }

    /// 把 Canvas 拥有的视口单向镜像到只读文档层：anchor .zero、position −offset、
    /// transform scale(z)，使 canonical P 渲染于 P·z − offset —— 与 Canvas 逐点一致。
    /// 值相等时零写入（避免无谓的 layer 几何变化再触发父视图重排）。
    private func syncDocumentMirror() {
        guard canvas.zoomScale > 0 else { return }
        let targetPosition = ReaderViewportMath.documentLayerPosition(
            contentOffset: canvas.contentOffset)
        let targetTransform = ReaderViewportMath.documentLayerTransform(scale: canvas.zoomScale)
        guard contentView.layer.position != targetPosition
            || contentView.layer.affineTransform() != targetTransform
            || contentView.bounds.size != documentSize
            || contentView.layer.anchorPoint != .zero else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentView.bounds = CGRect(origin: .zero, size: documentSize)
        contentView.layer.anchorPoint = .zero
        contentView.layer.position = targetPosition
        contentView.layer.setAffineTransform(targetTransform)
        CATransaction.commit()
    }

    private func lockHorizontalOffset() {
        guard !isApplyingViewport else { return }
        if abs(canvas.contentOffset.x) > 0.5 {
            canvas.contentOffset.x = 0
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
        let documentHeight = max(typography.canonicalPageHeight,
                                 CGFloat(pageBlocks.count) * typography.canonicalPageHeight
                                 + CGFloat(max(0, pageBlocks.count - 1)) * typography.pageGap)
        documentSize = CGSize(width: typography.canonicalPageWidth, height: documentHeight)
        contentView.bounds = CGRect(origin: .zero, size: documentSize)
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

    /// 只赋 drawing 与 revision 标记；零几何副作用（渲染完成由
    /// canvasViewDidFinishRendering 补镜像同步）。
    func loadInk(drawing: PKDrawing?, revision: Int) {
        canvas.drawing = drawing ?? PKDrawing()
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

    func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
        // PencilKit 赋值/滚动/缩放后异步渲染完成；此时镜像已 canonical 的视口，
        // 绝不改写 drawing 或重置 Canvas 几何。
        syncDocumentMirror()
        #if DEBUG
        probeSnapshot(event: "render-finished")
        #endif
    }
}

extension AnnotatedReaderView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === canvas else { return }
        lockHorizontalOffset()
        syncDocumentMirror()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard scrollView === canvas else { return }
        lockHorizontalOffset()
        syncDocumentMirror()
    }
}

// MARK: - Phase 0 只读取证探针（v3 包 04 号）
// 记录 hover 事件与 Canvas 视口几何到 Documents/hover-probe.jsonl；不绘制任何
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
        func affine(_ t: CGAffineTransform) -> [Double] {
            [Double(t.a), Double(t.b), Double(t.c), Double(t.d), Double(t.tx), Double(t.ty)]
        }
        var g: [String: Any] = [
            "canvas_zoom": Double(canvas.zoomScale),
            "canvas_offset": pt(canvas.contentOffset),
            "canvas_bounds": rect(canvas.bounds),
            "canvas_frame": rect(canvas.frame),
            "content_bounds": rect(contentView.bounds),
            "mirror_position": pt(contentView.layer.position),
            "mirror_affine": affine(contentView.layer.affineTransform()),
        ]
        if let t = canvas.layer.presentation()?.affineTransform() { g["canvas_present"] = affine(t) }
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
