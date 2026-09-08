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
            case .graphChanged(let st): self?.graphState = st
            case .error(let e): self?.lastError = e
            }
        }
        // 1) 先显示 cache (本地优先), 再联网
        Task { [weak self] in
            guard let self else { return }
            self.graphState = await self.store.cachedGraphState()
        }
        // 2) 首次启动先说明本地网络用途, 用户确认后才触发系统权限 (M-7.4)
        if !UserDefaults.standard.bool(forKey: "dualend.permission.note.shown") {
            showPermissionExplanation = true
        } else {
            startDiscovery()
        }
    }

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
    func nodeTapped(_ nodeId: String) { graphState.managedNodeId = nodeId }
    func nodeDoubleTapped(_ nodeId: String) {
        graphState.selectedNodeId = nodeId
        graphState.readerRoute = nodeId
    }
    func nodeDragged(_ nodeId: String, to pos: CGPoint) {
        graphState.dragTransient[nodeId] = pos
    }
    func nodeDragEnded(_ nodeId: String, at pos: CGPoint) {
        graphState.dragTransient[nodeId] = nil
        guard let snap = graphState.snapshot,
              let node = snap.nodes.first(where: { $0.nodeId == nodeId }) else { return }
        Task {
            await store.localMove(nodeId: nodeId, x: Double(pos.x), y: Double(pos.y),
                                  baseLayoutRevision: node.layout.revision)
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
            ReaderHostView(nodeId: route.nodeId)
                .environmentObject(model)
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
