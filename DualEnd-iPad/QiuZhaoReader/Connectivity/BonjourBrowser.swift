// BonjourBrowser —— 自动发现 + 自动选择 + service 解析（M-1.x 零配对）。
// NWBrowser 浏览 `_qiuzhaoreview._tcp`; 自动选择: preferred_daemon_id 在线优先 → 稳定排序取一;
// 端口经 NWConnection(.service) 系统解析(零 IP/端口输入); 权限被拒必须明示(M-1.5)。
import Foundation
import Network

struct ResolvedDaemon {
    let daemonId: String
    let host: String
    let port: UInt16
}

enum BonjourError: Error {
    case localNetworkDenied
    case resolveFailed(String)
}

final class BonjourBrowser {
    typealias ResolveCallback = (Result<ResolvedDaemon, BonjourError>) -> Void

    private struct Candidate {
        let name: String
        let endpoint: NWEndpoint
        let discoveredAt: Date
        let generation: UInt64
    }

    private var browser: NWBrowser?
    private var candidates: [Candidate] = []
    private var generation: UInt64 = 0
    private var waitingWatchdog: DispatchWorkItem?
    private let serviceNamePrefix = "qiuzao-review-"
    let preferredProvider: () -> String?
    let onDenied: () -> Void
    var onCandidatesChanged: (() -> Void)?

    init(preferredProvider: @escaping () -> String?, onDenied: @escaping () -> Void) {
        self.preferredProvider = preferredProvider
        self.onDenied = onDenied
    }

    func start() {
        guard browser == nil else { return }
        generation &+= 1
        let myGeneration = generation
        let params = NWParameters()
        params.includePeerToPeer = true
        let b = NWBrowser(for: .bonjour(type: "_qiuzhaoreview._tcp.", domain: nil), using: params)
        b.stateUpdateHandler = { [weak self] state in
            guard let self, myGeneration == self.generation else { return }
            if case .waiting(let error) = state {
                // 本地网络权限被拒 → 明示, 不伪装"Mac 不在线"
                if case .dns = error { DispatchQueue.main.async { self.onDenied() } }
                self.waitingWatchdog?.cancel()
                let item = DispatchWorkItem { [weak self] in
                    guard let self, myGeneration == self.generation, self.browser != nil else { return }
                    self.rebuild()
                }
                self.waitingWatchdog = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
            } else if case .ready = state {
                self.waitingWatchdog?.cancel()
            } else if case .failed(_) = state {
                self.scheduleRebuild(for: myGeneration)
            } else if case .cancelled = state {
                self.scheduleRebuild(for: myGeneration)
            }
        }
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, myGeneration == self.generation else { return }
            var found: [Candidate] = []
            for r in results {
                if case .service(let name, _, _, _) = r.endpoint {
                    found.append(Candidate(name: name, endpoint: r.endpoint,
                                           discoveredAt: Date(), generation: myGeneration))
                }
            }
            found.sort { $0.name < $1.name }
            print("[diag] browse results:", found.map(\.name))
            DispatchQueue.main.async {
                guard myGeneration == self.generation else { return }
                self.candidates = found
                self.onCandidatesChanged?()
            }
        }
        self.browser = b
        b.start(queue: .main)
    }

    /// M-1.6 自动选择候选端点(不弹选择页); 解析由 NWConnection(.service) 系统完成。
    ///
    /// 这里必须把 Bonjour service endpoint 原样交给 Network.framework，不能把
    /// 服务名替换成手工配置的 host/port；否则零配置自动发现会被绕过。
    func preferredEndpoint() -> (name: String, endpoint: NWEndpoint)? {
        let preferred = preferredProvider()
        var picked: Candidate?
        if let p = preferred,
           let match = candidates.first(where: { $0.name == p || self.extractDaemonId(from: $0.name) == p }) {
            // preferredDaemonId 是 WELCOME 返回的 daemon_id，而 browse result 是
            // qiuzao-review-<daemon_id> 的 service instance name；两者都要支持。
            picked = match
        } else {
            picked = candidates.first
        }
        guard let picked else {
            print("[diag] 无候选 candidates=", candidates.map(\.name))
            return nil
        }
        return (picked.name, picked.endpoint)
    }

    private func extractDaemonId(from serviceName: String) -> String {
        serviceName.hasPrefix(serviceNamePrefix)
            ? String(serviceName.dropFirst(serviceNamePrefix.count))
            : serviceName
    }

    private static func hostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let ip): return "\(ip)"
        case .ipv6(let ip): return "[\(ip)]"
        case .name(let name, _): return name
        @unknown default: return "127.0.0.1"
        }
    }

    func stop() {
        generation &+= 1
        waitingWatchdog?.cancel(); waitingWatchdog = nil
        browser?.cancel()
        browser = nil
        candidates = []
    }

    /// 丢弃旧 NWBrowser 及其回调，下一次 start 创建全新 generation。
    func rebuild() {
        stop()
        start()
    }

    private func scheduleRebuild(for oldGeneration: UInt64) {
        guard oldGeneration == generation else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == oldGeneration else { return }
            self.rebuild()
        }
    }

    var hasCandidates: Bool { !candidates.isEmpty }
}
