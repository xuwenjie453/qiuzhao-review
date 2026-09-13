// SyncEngine —— HELLO/WELCOME、snapshot/patch 接收(先 durable 后 ACK)、
// outbox 发送(ACK 清除)、重连退避、active 切换、session_epoch 隔离。
// 传输: BonjourBrowser 选 .service 端点 → WebSocketTransport(NWConnection, 系统解析地址)。
import Foundation
import Network

enum SyncEvent {
    case phaseChanged(ConnectionPhase)
    case graphChanged(QuestionGraphState)
    /// The command was durably accepted. The UI deliberately waits for the
    /// resulting graph snapshot/patch before dropping its optimistic overlay.
    case commandAck(commandId: String, kind: String?)
    /// The command cannot be applied against the current canonical revision.
    case commandRejected(commandId: String?, kind: String?, reason: String)
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
    private var networkEpoch: UInt64 = 0
    private var activeTransportEpoch: UInt64?
    private var reconnectWorkItem: DispatchWorkItem?
    private var welcomeWatchdog: DispatchWorkItem?
    /// v3.1 静态直连状态：当前 attempt 是否走的静态端点；连续失败计数用于逃生门。
    private var attemptUsesStatic = false
    private var staticFailures = 0
    private let staticFailoverThreshold = 5

    var onEvent: ((SyncEvent) -> Void)?

    init(store: ClientStore, browser: BonjourBrowser) {
        self.store = store
        self.browser = browser
        browser.onCandidatesChanged = { [weak self] in self?.connect() }
    }

    func start() {
        stopFlag = false
        startNewNetworkEpoch(reason: "start")
    }

    /// 前后台切换或网络大变更时建立新的发现/连接世代；旧回调不能污染新连接。
    func startNewNetworkEpoch(reason: String) {
        // stop() 为后台阶段设置了 stopFlag；新的前台 epoch 必须重新允许连接。
        stopFlag = false
        networkEpoch &+= 1
        reconnectWorkItem?.cancel(); reconnectWorkItem = nil
        welcomeWatchdog?.cancel(); welcomeWatchdog = nil
        ws?.close(); ws = nil; activeTransportEpoch = nil; sessionEpoch = nil
        phase = .discovering
        onEvent?(.phaseChanged(.discovering))
        print("[diag] network epoch", networkEpoch, "reason:", reason)
        browser.stop()
        browser.start()
        connect()
    }

    func stop() {
        stopFlag = true
        reconnectWorkItem?.cancel(); reconnectWorkItem = nil
        welcomeWatchdog?.cancel(); welcomeWatchdog = nil
        ws?.close()
        ws = nil; activeTransportEpoch = nil
        browser.stop()
        phase = .cachedOffline
        onEvent?(.phaseChanged(.cachedOffline))
    }

    // MARK: 连接(静态直连优先 + Bonjour 兜底 + 重连退避 0.5/1/2/4/8→10s)
    private func connect() {
        guard !stopFlag else { return }
        guard ws == nil else { return }

        // v3.1 静态端点优先：直连 IP:Port，不碰 mDNS/DNS（免受 VPN fake-ip 劫持）。
        // 连续失败超过阈值后让 Bonjour 发现一轮（IP 变化的逃生门）；Bonjour 无候选时回退静态。
        if staticFailures < staticFailoverThreshold, let s = StaticEndpoint.resolve() {
            print("[diag] 静态端点直连:", s.name)
            startAttempt(name: s.name,
                         endpoint: .hostPort(host: NWEndpoint.Host(s.host),
                                             port: NWEndpoint.Port(rawValue: s.port)!),
                         usesStatic: true)
            return
        }
        if let picked = browser.preferredEndpoint() {
            print("[diag] 选中服务:", picked.name)
            startAttempt(name: picked.name, endpoint: picked.endpoint, usesStatic: false)
            return
        }
        if let s = StaticEndpoint.resolve() {   // Bonjour 无候选 → 回退静态
            print("[diag] Bonjour 无候选, 回退静态端点:", s.name)
            startAttempt(name: s.name,
                         endpoint: .hostPort(host: NWEndpoint.Host(s.host),
                                             port: NWEndpoint.Port(rawValue: s.port)!),
                         usesStatic: true)
            return
        }
        scheduleReconnect()
    }

    private func startAttempt(name: String, endpoint: NWEndpoint, usesStatic: Bool) {
        attemptUsesStatic = usesStatic
        preferredId = name
        Task { await store.rememberDaemon(name) }
        phase = .connecting
        onEvent?(.phaseChanged(.connecting))
        let t = WebSocketTransport(endpoint: endpoint)
        t.delegate = self
        ws = t
        activeTransportEpoch = networkEpoch
        t.connect()
    }

    private func scheduleReconnect() {
        guard !stopFlag else { return }
        guard reconnectWorkItem == nil else { return }
        let delays = [0.5, 1.0, 2.0, 4.0, 8.0]
        let delay = reconnectAttempt < delays.count ? delays[reconnectAttempt] : 10.0
        reconnectAttempt += 1
        let epoch = networkEpoch
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.stopFlag, self.networkEpoch == epoch else { return }
            self.reconnectWorkItem = nil
            self.connect()
        }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: WebSocketTransportDelegate
    func transportOpen(_ t: WebSocketTransport) {
        guard t === ws, activeTransportEpoch == networkEpoch else { return }
        onSocketOpen()
    }
    func transport(_ t: WebSocketTransport, didReceiveText text: String) {
        guard t === ws, activeTransportEpoch == networkEpoch else { return }
        onText(text)
    }
    func transportClosed(_ t: WebSocketTransport) {
        guard t === ws, activeTransportEpoch == networkEpoch else { return }
        ws = nil; activeTransportEpoch = nil
        onSocketClosed()
    }
    func transportFailed(_ t: WebSocketTransport, error: Error?) {
        guard t === ws, activeTransportEpoch == networkEpoch else { return }
        ws = nil; activeTransportEpoch = nil
        onSocketClosed()
    }

    private func onSocketOpen() {
        print("[diag] ws open")
        phase = .syncing
        onEvent?(.phaseChanged(.syncing))
        welcomeWatchdog?.cancel()
        let epoch = networkEpoch
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.networkEpoch == epoch, self.ws != nil, self.sessionEpoch == nil else { return }
            self.ws?.close()
        }
        welcomeWatchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
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
        }
    }

    private func onSocketClosed() {
        print("[diag] ws closed")
        if attemptUsesStatic { staticFailures += 1 }   // 静态失败计数（逃生门）
        ws = nil
        activeTransportEpoch = nil
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
        if let mine = sessionEpoch {
            guard decoded.sessionEpoch == mine else { return }
        } else if decoded.type != ServerMessageType.WELCOME.rawValue {
            return
        }
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
        welcomeWatchdog?.cancel(); welcomeWatchdog = nil
        if let epoch = m.payload["session_epoch"]?.string { sessionEpoch = epoch }
        reconnectAttempt = 0
        staticFailures = 0   // 会话建立成功 → 静态直连健康, 复位逃生门计数
        Task {
            await store.rememberDaemon(daemonId)
            if let active = m.payload["active"]?.dict,
               let graphId = active["graph_id"]?.string {
                await store.setActive(graphId: graphId, roundId: active["round_id"]?.string)
                await requestSnapshot(graphId: graphId)
            }
            // 仅在收到 WELCOME 后恢复并重放 outbox，避免握手前使用 nil epoch。
            await store.restoreInflightToPending()
            await replayOutbox()
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
            if let commandId {
                DispatchQueue.main.async { [weak self] in
                    self?.onEvent?(.commandAck(commandId: commandId,
                                               kind: m.payload["kind"]?.string))
                }
            }
        }
    }

    private func onRejected(_ m: DecodedEnvelope) {
        let commandId = m.payload["command_id"]?.string
        let kind = m.payload["kind"]?.string
        let reason = m.payload["reason"]?.string ?? "REJECTED"
        onEvent?(.error(reason))
        Task {
            // A rejection is terminal for this outbox item. Remove it before
            // reloading the canonical graph so an old intent cannot replay on
            // the next reconnect.
            await store.clearOutbox(byMessageId: m.messageId, byCommandId: commandId)
            // Mac's rejection envelope does not always repeat graph_id. Read
            // the active cached graph before requesting a canonical snapshot;
            // publishing the local cache here would otherwise resurrect the
            // rejected optimistic coordinate after we clear its overlay.
            var graphId = m.payload["graph_id"]?.string
            if graphId == nil {
                graphId = (await store.cachedGraphState()).snapshot?.graphId
            }
            if let graphId { await requestSnapshot(graphId: graphId) }
            else { await publishGraph() }
            DispatchQueue.main.async { [weak self] in
                self?.onEvent?(.commandRejected(commandId: commandId, kind: kind, reason: reason))
            }
        }
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
