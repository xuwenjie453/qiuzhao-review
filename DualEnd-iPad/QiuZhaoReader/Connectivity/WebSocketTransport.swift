// WebSocketTransport —— NWConnection(.service) 之上的最小 RFC6455 客户端。
// 系统经 Bonjour 自动解析服务地址与端口 → 天然零 IP/端口输入(设计 M-1)。
// 文本帧收发 + ping/pong; 客户端帧带掩码; server→client 帧不掩码。
import Foundation
import Network

protocol WebSocketTransportDelegate: AnyObject {
    func transportOpen(_ t: WebSocketTransport)
    func transport(_ t: WebSocketTransport, didReceiveText: String)
    func transportClosed(_ t: WebSocketTransport)
    func transportFailed(_ t: WebSocketTransport, error: Error?)
}

final class WebSocketTransport {
    weak var delegate: WebSocketTransportDelegate?
    private var conn: NWConnection?
    private let endpoint: NWEndpoint
    private var rxBuffer = Data()
    private var opened = false
    private var finished = false
    private var tcpWatchdog: DispatchWorkItem?
    private var upgradeWatchdog: DispatchWorkItem?

    init(endpoint: NWEndpoint) { self.endpoint = endpoint }

    var isOpen: Bool { opened && conn != nil }

    func connect() {
        guard conn == nil else { return }
        finished = false
        scheduleTCPWatchdog()
        let params = NWParameters.tcp
        params.requiredInterfaceType = .wifi   // 只走 Wi-Fi: 避开 awdl/虚拟网卡干扰
        params.prohibitedInterfaceTypes = [.cellular]
        let c = NWConnection(to: endpoint, using: params)
        self.conn = c
        c.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            print("[diag] conn state:", state)
            switch state {
            case .ready:
                print("[diag] tcp ready (service resolved)")
                self.tcpWatchdog?.cancel()
                self.scheduleUpgradeWatchdog()
                self.sendUpgrade()
            case .failed(let err):
                print("[diag] tcp failed:", err)
                self.finish(error: err)
            case .cancelled:
                if !self.finished {
                    self.finish(error: NSError(domain: "WebSocketTransport", code: -2,
                                               userInfo: [NSLocalizedDescriptionKey: "connection cancelled"]))
                }
            default: break
            }
        }
        c.start(queue: .main)
    }

    // MARK: HTTP/1.1 Upgrade 握手
    private func sendUpgrade() {
        let keyData = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let key = keyData.base64EncodedString()
        // HTTP/1.1 要求每一行使用 CRLF。不要用多行 Swift literal 的换行
        // 拼接请求，否则服务端的 HTTP Upgrade 解析会停在半包/非法 header。
        let request = [
            "GET /bridge HTTP/1.1",
            "Host: qiuzao-review",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: \(key)",
            "Sec-WebSocket-Version: 13",
            "",
            "",
        ].joined(separator: "\r\n")
        print("[diag] upgrade 已发送")
        sendBytes(Data(request.utf8))
        receiveLoop()
    }

    private func receiveLoop() {
        conn?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                print("[diag] recv bytes:", data.count, "首行:", String(data: data.prefix(40), encoding: .utf8) ?? "?")
                self.rxBuffer.append(data)
                self.processBuffer()
            }
            if isComplete || error != nil {
                self.finish(error: error)
                return
            }
            if self.conn != nil && !self.finished { self.receiveLoop() }
        }
    }

    private func processBuffer() {
        while rxBuffer.count > 0 {
            if !opened {
                guard let range = rxBuffer.range(of: Data("\r\n\r\n".utf8)) else {
                    if rxBuffer.count > 4096 {
                        self.finish(error: NSError(domain: "WebSocketTransport", code: -4,
                                                   userInfo: [NSLocalizedDescriptionKey: "HTTP headers too large"]))
                    }
                    return
                }
                let head = String(data: rxBuffer[..<range.lowerBound], encoding: .utf8) ?? ""
                guard head.contains("101") else {
                    print("[diag] upgrade 失败:", head.split(separator: "\r\n").first ?? "")
                    self.finish(error: NSError(domain: "WebSocketTransport", code: -3,
                                               userInfo: [NSLocalizedDescriptionKey: "HTTP Upgrade rejected"]))
                    return
                }
                upgradeWatchdog?.cancel()
                opened = true
                rxBuffer.removeSubrange(..<range.upperBound)   // 清掉握手头
                print("[diag] ws upgrade ok")
                delegate?.transportOpen(self)
                continue
            }
            guard rxBuffer.count >= 2 else { return }
            let b = rxBuffer
            let fin = (b[0] & 0x80) != 0
            let opcode = b[0] & 0x0f
            var len = Int(b[1] & 0x7f)
            var off = 2
            if len == 126 {
                guard b.count >= 4 else { return }
                len = Int(UInt16(b[off]) << 8 | UInt16(b[off + 1])); off += 2
            } else if len == 127 {
                guard b.count >= 10 else { return }
                var v: UInt64 = 0
                for i in 0..<8 { v = v << 8 | UInt64(b[off + i]) }
                len = Int(v); off += 8
            }
            // server→client 不掩码
            guard b.count >= off + len else { return }
            let payload = b.subdata(in: off..<(off + len))
            rxBuffer = b.subdata(in: (off + len)..<b.count)
            if opcode == 0x1 && fin {
                let text = String(data: payload, encoding: .utf8) ?? ""
                delegate?.transport(self, didReceiveText: text)
            } else if opcode == 0x9 {
                sendFrame(opcode: 0xA, payload: payload)   // pong
            } else if opcode == 0x8 {
                close(); return
            }
        }
    }

    func send(text: String) {
        guard opened else { return }
        sendFrame(opcode: 0x1, payload: Data(text.utf8))
    }

    private func sendFrame(opcode: UInt8, payload: Data) {
        let mask = (0..<4).map { _ in UInt8.random(in: 0...255) }
        var header = Data()
        header.append(0x80 | opcode)
        if payload.count < 126 {
            header.append(0x80 | UInt8(payload.count))
        } else if payload.count < 65536 {
            header.append(0x80 | 126)
            header.append(UInt8((payload.count >> 8) & 0xff))
            header.append(UInt8(payload.count & 0xff))
        } else {
            header.append(0x80 | 127)
            var big = UInt64(payload.count).bigEndian
            withUnsafeBytes(of: &big) { header.append(contentsOf: $0) }
        }
        header.append(contentsOf: mask)
        var masked = Data(payload)
        for i in 0..<masked.count { masked[i] ^= mask[i % 4] }
        sendBytes(header + masked)
    }

    private func sendBytes(_ data: Data) {
        conn?.send(content: data, completion: .contentProcessed { error in
            if let error {
                print("[diag] send 失败:", error)
                self.finish(error: error)
            } else {
                print("[diag] send 成功", data.count, "字节")
            }
        })
    }

    func close() {
        guard !finished else { return }
        if opened { sendFrame(opcode: 0x8, payload: Data()) }
        finish(error: nil)
    }

    private func finish(error: Error?) {
        guard !finished else { return }
        finished = true
        tcpWatchdog?.cancel(); tcpWatchdog = nil
        upgradeWatchdog?.cancel(); upgradeWatchdog = nil
        conn?.cancel()
        conn = nil
        opened = false
        rxBuffer.removeAll()
        if let error { delegate?.transportFailed(self, error: error) }
        else { delegate?.transportClosed(self) }
    }

    private func scheduleTCPWatchdog() {
        tcpWatchdog?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.finished, !self.opened else { return }
            self.finish(error: NSError(domain: "WebSocketTransport", code: -10,
                                       userInfo: [NSLocalizedDescriptionKey: "TCP connect timeout"]))
        }
        tcpWatchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    private func scheduleUpgradeWatchdog() {
        upgradeWatchdog?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.finished, !self.opened else { return }
            self.finish(error: NSError(domain: "WebSocketTransport", code: -11,
                                       userInfo: [NSLocalizedDescriptionKey: "HTTP Upgrade timeout"]))
        }
        upgradeWatchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
    }
}
