// SyncEngine —— HELLO/WELCOME、snapshot/patch 接收(先 durable 后 ACK)、
// outbox 发送(ACK 清除)、重连退避、active 切换、session_epoch 隔离。
// 传输: BonjourBrowser 选 .service 端点 → WebSocketTransport(NWConnection, 系统解析地址)。
import Foundation
import Network

enum SyncEvent {
    case phaseChanged(ConnectionPhase)
    case graphChanged(QuestionGraphState)
    case error(String)
}

final class SyncEngine: WebSocketTransportDelegate {
    private let store: ClientStore
    private let browser: BonjourBrowser
    private var ws: WebSocketTransport?
    private(set) var phase: ConnectionPhase = .cachedOffline
    private var sessionEpoch: String?
    private var reconnectAttempt = 0
    private var stopFlag = false
    private var preferredId: String?

    var onEvent: ((SyncEvent) -> Void)?

    init(store: ClientStore, browser: BonjourBrowser) {
        self.store = store
        self.browser = browser
    }

    func start() {
        stopFlag = false
        connect()
    }
    func stop() {
        stopFlag = true
        ws?.close()
        ws = nil
        phase = .cachedOffline
    }

    // MARK: 连接(自动发现 + 自动选择 + 重连退避 0.5/1/2/4/8→10s)
    private func connect() {
        guard !stopFlag else { return }
        guard ws == nil else { return }
        guard let picked = browser.preferredEndpoint() else {
            scheduleReconnect()
            return
        }
        print("[diag] 选中服务:", picked.name)
        reconnectAttempt = 0
        preferredId = picked.name
        Task { await store.rememberDaemon(picked.name) }
        phase = .connecting
        onEvent?(.phaseChanged(.connecting))
        let t = WebSocketTransport(endpoint: picked.endpoint)
        t.delegate = self
        ws = t
        t.connect()
    }

    private func scheduleReconnect() {
        guard !stopFlag else { return }
        let delays = [0.5, 1.0, 2.0, 4.0, 8.0]
        let delay = reconnectAttempt < delays.count ? delays[reconnectAttempt] : 10.0
        reconnectAttempt += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.stopFlag else { return }
            self.connect()
        }
    }

    // MARK: WebSocketTransportDelegate
    func transportOpen(_ t: WebSocketTransport) {
        guard t === ws else { return }
        onSocketOpen()
    }
    func transport(_ t: WebSocketTransport, didReceiveText text: String) {
        guard t === ws else { return }
        onText(text)
    }
    func transportClosed(_ t: WebSocketTransport) {
        if t === ws { ws = nil }
        onSocketClosed()
    }
    func transportFailed(_ t: WebSocketTransport, error: Error?) {
        if t === ws { ws = nil }
        onSocketClosed()
    }

    private func onSocketOpen() {
        print("[diag] ws open")
        reconnectAttempt = 0
        phase = .syncing
        onEvent?(.phaseChanged(.syncing))
        Task {
            let cached = await store.cachedGraphState()
            let payload: [String: Any] = [
                "device_id": Self.deviceId(),
                "client_build": WireV1.clientBuild,
                "supported_protocols": [1],
                "last_server_seq": 0,
                "cached_graph": cached.snapshot.map { ["graph_id": $0.graphId, "revision": $0.revision] } ?? [:],
            ]
            send(.HELLO, payload)
            // 重连: INFLIGHT → PENDING 并按序重放 outbox
            await store.restoreInflightToPending()
            await replayOutbox()
        }
    }

    private func onSocketClosed() {
        print("[diag] ws closed")
        ws = nil
        sessionEpoch = nil
        phase = .cachedOffline
        onEvent?(.phaseChanged(.cachedOffline))
        scheduleReconnect()
    }

    private func onText(_ text: String) {
        guard let decoded = try? MessageCoder.decode(text) else {
            print("[diag] 无法解析消息(前80字):", String(text.prefix(80)))
            return
        }
        print("[diag] recv:", decoded.type)
        // session_epoch 隔离: 旧会话消息作废 (M-5.5)
        if let epoch = decoded.sessionEpoch, let mine = sessionEpoch, epoch != mine { return }
        handle(decoded)
    }

    // MARK: 消息处理
    private func handle(_ m: DecodedEnvelope) {
        switch m.type {
        case ServerMessageType.WELCOME.rawValue: onWelcome(m)
        case ServerMessageType.GRAPH_SNAPSHOT.rawValue: onSnapshot(m)
        case ServerMessageType.GRAPH_PATCH.rawValue: onPatch(m)
        case ServerMessageType.ACTIVE_GRAPH_CHANGED.rawValue: onActiveChanged(m)
        case ServerMessageType.COMMAND_ACK.rawValue: onAck(m)
        case ServerMessageType.COMMAND_REJECTED.rawValue: onRejected(m)
        case ServerMessageType.PING.rawValue: send(.PONG, [:])
        default: break // 未知 type: 记录并忽略, 不 crash
        }
    }

    private func onWelcome(_ m: DecodedEnvelope) {
        guard let daemonId = m.payload["daemon_id"]?.string else { return }
        if let epoch = m.payload["session_epoch"]?.string { sessionEpoch = epoch }
        Task {
            await store.rememberDaemon(daemonId)
            if let active = m.payload["active"]?.dict,
               let graphId = active["graph_id"]?.string {
                await store.setActive(graphId: graphId, roundId: active["round_id"]?.string)
                await requestSnapshot(graphId: graphId)
            }
            phase = .ready
            onEvent?(.phaseChanged(.ready))
        }
    }

    private func onSnapshot(_ m: DecodedEnvelope) {
        Task {
            let result = await store.applySnapshot(payload: m.payload, messageId: m.messageId)
            send(.ACK, ["message_id": m.messageId])   // durable 后才 ACK (M-3.5)
            guard let dto = result else { return }
            await store.setActive(graphId: dto.graphId, roundId: dto.roundId)
            await publishGraph()
        }
    }

    private func onPatch(_ m: DecodedEnvelope) {
        Task {
            switch await store.applyPatch(payload: m.payload, messageId: m.messageId) {
            case .applied:
                send(.ACK, ["message_id": m.messageId])
                await publishGraph()
            case .baseMismatch:
                // 不盲 apply; 请求 snapshot 恢复 (M-3.4)
                send(.ACK, ["message_id": m.messageId])
                if let gid = m.payload["graph_id"]?.string { await requestSnapshot(graphId: gid) }
            case .dedup, .malformed:
                break
            }
        }
    }

    private func onActiveChanged(_ m: DecodedEnvelope) {
        Task {
            guard let graphId = m.payload["graph_id"]?.string else { return }
            await store.setActive(graphId: graphId, roundId: m.payload["round_id"]?.string)
            await requestSnapshot(graphId: graphId)
        }
    }

    private func onAck(_ m: DecodedEnvelope) {
        Task {
            let commandId = m.payload["command_id"]?.string
            await store.clearOutbox(byMessageId: m.messageId, byCommandId: commandId)
        }
    }

    private func onRejected(_ m: DecodedEnvelope) {
        let reason = m.payload["reason"]?.string ?? "REJECTED"
        onEvent?(.error(reason))
        Task { await publishGraph() }   // 恢复 server 视图, UI 可提示重试
    }

    // MARK: 发送 / outbox
    func send(_ type: ClientMessageType, _ payload: [String: Any]) {
        guard let t = ws as? WebSocketTransport, t.isOpen else { return }
        t.send(text: MessageCoder.make(type.rawValue, payload: payload, epoch: sessionEpoch))
    }

    func requestSnapshot(graphId: String) async {
        send(.SNAPSHOT_REQUEST, ["graph_id": graphId])
    }

    func replayOutbox() async {
        let outbox = await store.pendingOutbox()
        for item in outbox {
            guard let payloadStr = item["payload_json"] as? String,
                  let payload = (try? JSONSerialization.jsonObject(with: Data(payloadStr.utf8))) as? [String: Any],
                  let kind = payload["kind"] as? String,
                  let mid = item["message_id"] as? String else { continue }
            if kind == "INK_PUT" {
                let wire: [String: Any] = [
                    "command_id": payload["command_id"] ?? "", "kind": "INK_PUT",
                    "node_id": payload["node_id"] ?? "", "ink_revision": payload["ink_revision"] ?? 0,
                    "format": payload["format"] ?? "pkdrawing-v1", "blob": payload["blob"] ?? "",
                    "blob_sha256": payload["blob_sha256"] ?? "", "graph_id": payload["graph_id"] ?? "",
                ]
                send(.INK_PUT, wire)
            } else {
                send(.CLIENT_COMMAND, payload)
            }
            await store.markInflight(mid)
        }
    }

    /// 本地 mutation 已 durable; 此处网络尝试(仅 ready 状态)
    func pushLocalMutation() {
        guard phase == .ready else { return }
        Task { await replayOutbox() }
    }

    private func publishGraph() async {
        let state = await store.cachedGraphState()
        DispatchQueue.main.async { [weak self] in self?.onEvent?(.graphChanged(state)) }
    }

    static func deviceId() -> String {
        let key = "dualend.device_id"
        if let v = UserDefaults.standard.string(forKey: key) { return v }
        let v = UUID().uuidString.lowercased()
        UserDefaults.standard.set(v, forKey: key)
        return v
    }
}
