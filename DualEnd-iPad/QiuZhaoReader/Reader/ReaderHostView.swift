// ReaderHost —— UIViewControllerRepresentable 承载 AnnotatedReaderView（UIKit + PencilKit）。
// PKDrawing 经 ClientStore 按 node_id 持久化; 离开页面/退后台 force flush; debounce 只影响 I/O 不延迟渲染。
import SwiftUI
import UIKit
import PencilKit

struct ReaderHostView: View {
    @EnvironmentObject var model: AppSessionModel
    @Environment(\.dismiss) private var dismiss
    let nodeId: String

    @State private var markdown = ""
    @State private var drawing: PKDrawing?
    @State private var eraser = false
    @State private var vcHolder = ReaderHostHolder()
    @State private var configured = false
    // Reader 路由存活期内只保留一个 Pencil 控制器；SwiftUI 值视图重建会丢掉
    // UIPencilInteraction delegate 与工具状态，故用 @StateObject。
    @StateObject private var pencil = PencilToolController()

    var body: some View {
        VStack(spacing: 0) {
            ReaderContainer(markdown: markdown, drawing: drawing, nodeId: nodeId,
                            pencil: pencil, eraser: $eraser,
                            holder: vcHolder,
                            dirtyFlush: { data in
                                model.flushInk(nodeId: nodeId, drawingData: data)
                            })
                .ignoresSafeArea(.keyboard)
            toolBar
        }
        .navigationTitle("节点阅读与批注")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("返回", systemImage: "chevron.left")
                }
            }
        }
        .onAppear { load() }
        .onDisappear { forceFlush() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            forceFlush()
        }
    }

    private func load() {
        guard !configured else { return }
        configured = true
        markdown = model.markdownFor(nodeId: nodeId) ?? "（暂无正文——等待 Mac 同步）"
        Task {
            let (blob, _) = await model.loadInk(nodeId: nodeId)
            if let blob, let d = try? PKDrawing(data: blob) { drawing = d }
        }
    }

    private func forceFlush() {
        vcHolder.vc?.flushNow(onFlush: { data in
            model.flushInk(nodeId: nodeId, drawingData: data)
        })
    }

    private var toolBar: some View {
        HStack {
            Button {
                eraser.toggle()
            } label: {
                Image(systemName: eraser ? "eraser.fill" : "pencil.tip")
            }
            .buttonStyle(.bordered)
            Text(eraser ? "橡皮擦（支持型号可 Pencil 双击切换）" : "手写笔（手指滚动，Pencil 书写）")
                .font(.footnote).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }
}

extension AppSessionModel {
    func markdownFor(nodeId: String) -> String? {
        graphState.snapshot?.nodes.first(where: { $0.nodeId == nodeId })?.bodyMarkdown
    }
}

// 经 holder 桥接拿到 UIViewController (Representable 更新时不重建)
final class ReaderHostHolder {
    weak var vc: ReaderHostVC?
}

struct ReaderContainer: UIViewControllerRepresentable {
    let markdown: String
    let drawing: PKDrawing?
    let nodeId: String
    let pencil: PencilToolController
    @Binding var eraser: Bool
    let holder: ReaderHostHolder
    let dirtyFlush: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastConfiguredNode: String?
        var lastConfiguredMarkdown: String?
        var lastDrawingData: Data?
        var onDirtyFlush: ((Data) -> Void)?
        weak var attachedCanvas: PKCanvasView?
    }

    func makeUIViewController(context: Context) -> ReaderHostVC {
        let vc = ReaderHostVC()
        vc.coordinator = context.coordinator
        holder.vc = vc
        return vc
    }
    func updateUIViewController(_ vc: ReaderHostVC, context: Context) {
        let co = context.coordinator
        let needReconfigure = co.lastConfiguredNode != nodeId || co.lastConfiguredMarkdown != markdown
        if needReconfigure && !markdown.isEmpty {
            co.lastConfiguredNode = nodeId
            co.lastConfiguredMarkdown = markdown
            vc.configure(nodeId: nodeId, markdown: markdown, drawing: drawing)
            // flush 委托: 每次 Reader 保存 debounce 触发后交 Coordinator 持有最新 data 并通知
            vc.onDirtyFlush = { data in
                co.lastDrawingData = data
                co.onDirtyFlush?(data)
            }
        }
        // drawing 异步到达后的装载(首次已由 configure 传入 nil; 这里补装)
        if let drawing, !needReconfigure, co.lastConfiguredNode == nodeId, vc.needsDrawingLoad {
            vc.loadDrawing(drawing)
        }
        // Representable 的首次 update 可能早于 configure；不要解包尚未创建的
        // AnnotatedReaderView，否则双击节点进入 Reader 会直接闪退。
        if let readerView = vc.readerView {
            // UIPencilInteraction（双击切工具）只在换 canvas 时挂载一次。
            if co.attachedCanvas !== readerView.canvas {
                pencil.attach(to: readerView.canvas)
                co.attachedCanvas = readerView.canvas
            }
            pencil.apply(to: readerView.canvas, isEraser: eraser)
        }
        co.onDirtyFlush = dirtyFlush
    }
}

final class ReaderHostVC: UIViewController {
    private(set) var readerView: AnnotatedReaderView!
    var onDirtyFlush: ((Data) -> Void)?
    weak var coordinator: ReaderContainer.Coordinator?
    private(set) var configuredNodeId: String?
    var needsDrawingLoad = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    func configure(nodeId: String, markdown: String, drawing: PKDrawing?) {
        configuredNodeId = nodeId
        needsDrawingLoad = false
        if let old = readerView { old.removeFromSuperview() }
        let rv = AnnotatedReaderView(nodeId: nodeId, markdown: markdown)
        rv.translatesAutoresizingMaskIntoConstraints = false
        rv.delegate = self
        view.addSubview(rv)
        NSLayoutConstraint.activate([
            rv.topAnchor.constraint(equalTo: view.topAnchor),
            rv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        readerView = rv
        if let drawing { rv.loadInk(drawing: drawing, revision: 0) }
        else { needsDrawingLoad = true }
    }

    func loadDrawing(_ drawing: PKDrawing) {
        readerView?.loadInk(drawing: drawing, revision: readerView.currentInkRevision)
        needsDrawingLoad = false
    }

    /// force flush (离开页面/退后台): 即使无新笔迹也把最新 committed drawing 同步
    func flushNow(onFlush: @escaping (Data) -> Void) {
        guard let rv = readerView else { return }
        rv.flushIfDirty()
        onFlush(rv.canvas.drawing.dataRepresentation())
    }
}

extension ReaderHostVC: AnnotatedReaderDelegate {
    func readerInkChanged(_ view: AnnotatedReaderView) { /* 屏幕渲染由 PencilKit 原生完成 */ }
    func readerNeedsFlush(_ view: AnnotatedReaderView) {
        onDirtyFlush?(view.canvas.drawing.dataRepresentation())
    }
}
