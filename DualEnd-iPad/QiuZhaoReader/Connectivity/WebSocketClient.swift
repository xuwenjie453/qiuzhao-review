// WebSocketClient —— URLSessionWebSocketTask 封装（Apple 原生帧/ping 处理）。
// Mac daemon 端点由 Bonjour 解析为 host:port 后建立; 无任何手动 IP/端口 UI。
import Foundation

final class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    var onOpen: (() -> Void)?
    var onText: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onError: ((Error?) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let host: String
    private let port: UInt16
    private var closed = false
    private var heartbeat: Timer?

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
        super.init()
    }

    func connect() {
        closed = false
        let url = URL(string: "ws://\(host):\(port)/bridge")!
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        let t = session.webSocketTask(with: url)
        task = t
        t.resume()
        receiveLoop()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.task?.sendPing { _ in }   // URLSession 自动处理 pong
        }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self, !self.closed else { return }
            switch result {
            case .success(.string(let text)):
                self.onText?(text)
                self.receiveLoop()
            case .success(.data):
                self.receiveLoop()
            case .failure:
                self.close()
            @unknown default:
                self.receiveLoop()
            }
        }
    }

    func send(text: String) {
        task?.send(.string(text)) { _ in }   // socket send ≠ committed (outbox 仅凭 ACK 清除)
    }

    func close() {
        guard !closed else { return }
        closed = true
        heartbeat?.invalidate()
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        onClose?()
    }

    // MARK: URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onOpen?()
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        closed = true
        heartbeat?.invalidate()
        onClose?()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if !closed { onError?(error); close() }
    }
}
