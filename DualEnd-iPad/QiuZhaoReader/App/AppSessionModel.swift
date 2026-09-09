// App —— RootView + 会话状态机 + 7 态连接徽章 + Topology/Reader 导航 + 管理 sheet。
// 首次启动先显示本地网络用途说明再触发 NWBrowser(M-7.4); 本地网络权限被拒明示(M-7.2-6)。
import SwiftUI
import UIKit

@main
struct QiuZhaoReaderApp: App {
    @StateObject private var model = AppSessionModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onAppear { model.bootstrap() }
        }
    }
}

@MainActor
final class AppSessionModel: ObservableObject {
    @Published var phase: ConnectionPhase = .cachedOffline
    @Published var graphState = QuestionGraphState()
    @Published var showPermissionExplanation = false
    @Published var lastError: String?

    private var store: ClientStore!
    private var browser: BonjourBrowser!
    private var sync: SyncEngine!
    private var storePath: String!
    /// command_id -> node_id for optimistic MOVE_NODE commands. This is kept
    /// in memory only; the durable intent itself remains in ClientStore's
    /// outbox across reconnects.
    private var pendingMoveCommands: [String: String] = [:]

    func bootstrap() {
        guard store == nil else { return }
        storePath = Self.localDBPath()
        store = ClientStore(dbPath: storePath)
        browser = BonjourBrowser(
            preferredProvider: { Self.preferredDaemonId() },
            onDenied: { [weak self] in self?.phase = .localNetworkDenied })
        sync = SyncEngine(store: store, browser: browser)
        sync.onEvent = { [weak self] ev in
            switch ev {
            case .phaseChanged(let p): self?.phase = p
            case .graphChanged(let st): self?.applyGraphState(st)
            case .commandAck:
                // Keep the optimistic overlay until the matching canonical
                // snapshot/patch is observed. Clearing on ACK alone creates a
                // visible one-frame jump back to the old server coordinate.
                break
            case .commandRejected(let commandId, _, let reason):
                self?.handleCommandRejected(commandId: commandId, reason: reason)
            case .error(let e): self?.lastError = e
            }
        }
        // 1) 先显示 cache (本地优先), 再联网
        Task { [weak self] in
            guard let self else { return }
            self.graphState = await self.store.cachedGraphState()
        }
        // 2) 立即开始自动发现(说明页仅首次展示, 不拦截发现流程; 系统权限弹窗由 browse 触发)
        startDiscovery()
        if !UserDefaults.standard.bool(forKey: "dualend.permission.note.shown") {
            showPermissionExplanation = true
        }
        #if DEBUG
        autoOpenReaderForDiagnostics()
        #endif
    }

    #if DEBUG
    /// 仅诊断/无头复现（v3 包）：launch argument `-uiTestOpenReaderNode <node_id|title>`
    /// 直接走"双击节点进 Reader"的同一条路由（readerRoute → fullScreenCover），
    /// 用于复现与采样"双击即卡死"。不带参数时零行为。
    func autoOpenReaderForDiagnostics() {
        guard let arg = UserDefaults.standard.string(forKey: "uiTestOpenReaderNode"),
              !arg.isEmpty else { return }
        func tryOpen() -> Bool {
            guard let snap = graphState.snapshot,
                  let node = snap.nodes.first(where: { $0.nodeId == arg || $0.title == arg })
            else { return false }
            nodeDoubleTapped(node.nodeId)
            return true
        }
        if tryOpen() { return }
        // 缓存图异步加载，稍后重试
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            _ = self?.autoOpenRetry(arg: arg)
        }
    }
    private func autoOpenRetry(arg: String) -> Bool {
        guard let snap = graphState.snapshot,
              let node = snap.nodes.first(where: { $0.nodeId == arg || $0.title == arg })
        else { return false }
        nodeDoubleTapped(node.nodeId)
        return true
    }
    #endif

    /// daemon 偏好存 UserDefaults(同步可用, 免 actor 等待)
    static func preferredDaemonId() -> String? {
        UserDefaults.standard.string(forKey: "dualend.preferred_daemon")
    }
    static func rememberPreferredDaemon(_ daemonId: String) {
        UserDefaults.standard.set(daemonId, forKey: "dualend.preferred_daemon")
    }

    func startDiscovery() {
        UserDefaults.standard.set(true, forKey: "dualend.permission.note.shown")
        showPermissionExplanation = false
        browser.start()
        sync.start()
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    static func localDBPath() -> String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QiuZhaoReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("client-store.sqlite").path
    }

    // MARK: UI 动作（先 local durable, 网络由 SyncEngine 尝试）
    func nodeTapped(_ nodeId: String) {
        graphState.selectedNodeId = nodeId
        graphState.managedNodeId = nodeId
    }
    func backgroundTapped() {
        graphState.selectedNodeId = nil
        graphState.managedNodeId = nil
    }
    func nodeDoubleTapped(_ nodeId: String) {
        // 关闭可能残留的单击管理 sheet，避免双击后两个 modal 状态竞争。
        graphState.managedNodeId = nil
        graphState.selectedNodeId = nodeId
        graphState.readerRoute = nodeId
    }
    func nodeDragged(_ nodeId: String, to pos: CGPoint) {
        // 位置必须逐帧严格跟随输入，不在坐标上做插值；拖动动画由节点的
        // scale/shadow 表达，避免手指或 Pencil 悬停点与实际节点错位。
        graphState.dragTransient[nodeId] = pos
    }
    func nodeDragEnded(_ nodeId: String, at pos: CGPoint) {
        // Keep the final position visible while the durable command traverses
        // the outbox and while Mac publishes its next graph revision.
        graphState.pendingPositions[nodeId] = pos
        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
            graphState.dragTransient[nodeId] = nil
        }
        guard let snap = graphState.snapshot,
              let node = snap.nodes.first(where: { $0.nodeId == nodeId }) else { return }
        Task {
            let commandId = await store.localMove(nodeId: nodeId, x: Double(pos.x), y: Double(pos.y),
                                                  baseLayoutRevision: node.layout.revision)
            await MainActor.run {
                self.pendingMoveCommands[commandId] = nodeId
            }
            sync.pushLocalMutation()
        }
    }
    func rename(nodeId: String, title: String) {
        guard let snap = graphState.snapshot,
              let node = snap.nodes.first(where: { $0.nodeId == nodeId }) else { return }
        Task {
            await store.localRename(nodeId: nodeId, title: title, baseNodeRevision: node.nodeRevision)
            sync.pushLocalMutation()
        }
        graphState.managedNodeId = nil
    }
    func delete(nodeId: String) {
        guard let snap = graphState.snapshot,
              let node = snap.nodes.first(where: { $0.nodeId == nodeId }), !node.isCenter else { return }
        Task {
            await store.localDelete(nodeId: nodeId, baseNodeRevision: node.nodeRevision)
            sync.pushLocalMutation()
        }
        graphState.managedNodeId = nil
    }
    func didEnterReader(nodeId: String) { /* ink flush 生命周期由 ReaderHost 处理 */ }

    // MARK: - Canonical graph merge / optimistic move lifecycle
    private func applyGraphState(_ incoming: QuestionGraphState) {
        var next = incoming
        // These fields are local UI state and are intentionally not replaced
        // by a server snapshot.
        next.selectedNodeId = graphState.selectedNodeId
        next.managedNodeId = graphState.managedNodeId
        next.readerRoute = graphState.readerRoute
        next.dragTransient = graphState.dragTransient
        next.pendingPositions = graphState.pendingPositions

        // A pending move is complete only when the canonical graph contains
        // the same normalized coordinate. Older snapshots must not make the
        // node jump back during the ACK/patch gap.
        if let snapshot = incoming.snapshot {
            for (nodeId, pending) in graphState.pendingPositions {
                guard let node = snapshot.nodes.first(where: { $0.nodeId == nodeId }) else { continue }
                let dx = abs(node.layout.x - Double(pending.x))
                let dy = abs(node.layout.y - Double(pending.y))
                if dx < 0.0005 && dy < 0.0005 {
                    next.pendingPositions[nodeId] = nil
                    pendingMoveCommands = pendingMoveCommands.filter { $0.value != nodeId }
                }
            }
        }
        graphState = next
    }

    private func handleCommandRejected(commandId: String?, reason: String) {
        if let commandId, let nodeId = pendingMoveCommands.removeValue(forKey: commandId) {
            graphState.pendingPositions[nodeId] = nil
            graphState.dragTransient[nodeId] = nil
        }
        lastError = reason
    }
}

// MARK: - Ink / Reader 支撑（同文件 extension 可访问 private store/sync）
extension AppSessionModel {
    func loadInk(nodeId: String) async -> (Data?, Int) {
        let blob = await store.inkBlob(nodeId: nodeId)
        let rev = await store.inkRevision(nodeId: nodeId)
        return (blob, rev)
    }
    /// 本地 durable + outbox（网络由 SyncEngine 重放）
    func flushInk(nodeId: String, drawingData: Data) {
        Task {
            let next = await store.inkRevision(nodeId: nodeId) + 1
            await store.localInkSave(nodeId: nodeId, revision: next, blob: drawingData)
            sync.pushLocalMutation()
        }
    }
}

// MARK: - 徽章文案 (7 态 UX, M-7.2)
func connectionBadge(for phase: ConnectionPhase) -> (text: String, color: Color) {
    switch phase {
    case .cachedOffline: return ("离线 · 显示本地内容", .gray)
    case .discovering: return ("正在连接…", .orange)
    case .connecting: return ("正在连接…", .orange)
    case .syncing: return ("同步中…", .blue)
    case .ready: return ("已连接", .green)
    case .localNetworkDenied: return ("需要本地网络权限", .red)
    case .protocolUnsupported: return ("协议版本不兼容", .red)
    }
}

// MARK: - Root
struct RootView: View {
    @EnvironmentObject var model: AppSessionModel

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    QuestionGraphView(state: model.graphState,
                                      containerSize: geo.size,
                                      onNodeTap: { model.nodeTapped($0) },
                                      onNodeDoubleTap: { model.nodeDoubleTapped($0) },
                                      onBackgroundTap: { model.backgroundTapped() },
                                      onNodeDragChanged: { model.nodeDragged($0, to: $1) },
                                      onNodeDragEnded: { model.nodeDragEnded($0, at: $1) })
                    if let err = model.lastError {
                        Text(err).font(.footnote).foregroundColor(.white)
                            .padding(8).background(Color.red.opacity(0.9)).cornerRadius(8)
                            .padding(.bottom, 8)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("问题图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { badgeView } }
            .sheet(item: Binding(
                get: { model.graphState.managedNodeId.map(NodeSheetRoute.init) },
                set: { if $0 == nil { model.graphState.managedNodeId = nil } }
            )) { route in
                if let node = currentNode(route.nodeId) {
                    NodeManageSheet(node: node,
                                    onRename: { model.rename(nodeId: node.nodeId, title: $0) },
                                    onDelete: { model.delete(nodeId: node.nodeId) })
                        // .sheet(item:) 复用承载视图时强制按 node_id 重建，
                        // 防止从新节点点回 CENTER 仍显示上一个节点内容。
                        .id(route.nodeId)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { model.showPermissionExplanation },
            set: { model.showPermissionExplanation = $0 }
        )) {
            FirstLaunchPermissionView(onStart: { model.startDiscovery() })
        }
        .fullScreenCover(item: Binding(
            get: { model.graphState.readerRoute.map(ReaderRoute.init) },
            set: { if $0 == nil { model.graphState.readerRoute = nil } }
        )) { route in
            NavigationStack {
                ReaderHostView(nodeId: route.nodeId)
                    .environmentObject(model)
            }
        }
    }

    private var badgeView: some View {
        let b = connectionBadge(for: model.phase)
        return HStack(spacing: 5) {
            Circle().fill(b.color).frame(width: 8, height: 8)
            Text(b.text).font(.caption).foregroundColor(b.color)
        }
        .onTapGesture {
            if model.phase == .localNetworkDenied { model.openSettings() }
        }
    }

    private func currentNode(_ id: String) -> GraphNodeDTO? {
        model.graphState.snapshot?.nodes.first { $0.nodeId == id }
    }
}

struct NodeSheetRoute: Identifiable { let nodeId: String; var id: String { nodeId } }
struct ReaderRoute: Identifiable { let nodeId: String; var id: String { nodeId } }

// MARK: - 首次启动权限说明 (M-7.4): 先说明用途再触发系统 Local Network 权限
struct FirstLaunchPermissionView: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48)).foregroundColor(.blue)
            Text("自动发现 Mac 学习守护进程")
                .font(.title2.bold())
            Text("用于自动发现同一局域网中的 Mac 学习守护进程。")
                .font(.body).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("继续", action: onStart)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Single-tap 管理 sheet: title / kind / status / delete(CENTER 不出现)
struct NodeManageSheet: View {
    let node: GraphNodeDTO
    let onRename: (String) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("标题（最多 80 字符）") {
                    TextField("节点标题", text: $title)
                        .onAppear { title = node.title }
                }
                Section {
                    HStack { Text("类型"); Spacer(); Text(kindName).foregroundColor(.secondary) }
                    HStack {
                        Text("状态")
                        Spacer()
                        Text(node.isCenter ? "永久 · 题目中心" : (node.kind == .TEMPORARY ? "本轮临时" : "永久"))
                            .foregroundColor(.secondary)
                    }
                }
                if !node.isCenter {
                    Section {
                        Button("删除节点", role: .destructive) { onDelete(); dismiss() }
                    }
                }
            }
            .navigationTitle("节点")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let t = title.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty && t != node.title { onRename(t) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
    private var kindName: String {
        switch node.kind {
        case .CENTER: return "CENTER · 方形"
        case .EXPLANATION: return "EXPLANATION · 圆形"
        case .TEMPORARY: return "TEMPORARY · 三角形"
        }
    }
}
