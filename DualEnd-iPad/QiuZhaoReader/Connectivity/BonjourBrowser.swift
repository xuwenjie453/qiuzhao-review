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

    private var browser: NWBrowser?
    private var candidates: [String] = []           // 服务名(daemon 标识), 稳定排序
    private let serviceNamePrefix = "qiuzao-review-"
    let preferredProvider: () -> String?
    let onDenied: () -> Void

    init(preferredProvider: @escaping () -> String?, onDenied: @escaping () -> Void) {
        self.preferredProvider = preferredProvider
        self.onDenied = onDenied
    }

    func start() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        let b = NWBrowser(for: .bonjour(type: "_qiuzhaoreview._tcp.", domain: nil), using: params)
        b.stateUpdateHandler = { [weak self] state in
            if case .waiting(let error) = state {
                // 本地网络权限被拒 → 明示, 不伪装"Mac 不在线"
                if case .dns = error { DispatchQueue.main.async { self?.onDenied() } }
            }
        }
        b.browseResultsChangedHandler = { [weak self] results, _ in
            var names: [String] = []
            for r in results {
                if case .service(let name, _, _, _) = r.endpoint { names.append(name) }
            }
            names.sort()          // daemon_id 稳定排序
            print("[diag] browse results:", names)
            DispatchQueue.main.async { self?.candidates = names }
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
        var picked: String?
        if let p = preferred,
           let match = candidates.first(where: { $0 == p || self.extractDaemonId(from: $0) == p }) {
            // preferredDaemonId 是 WELCOME 返回的 daemon_id，而 browse result 是
            // qiuzao-review-<daemon_id> 的 service instance name；两者都要支持。
            picked = match
        } else {
            picked = candidates.first
        }
        guard let name = picked else {
            print("[diag] 无候选 candidates=", candidates)
            return nil
        }
        let endpoint = NWEndpoint.service(
            name: name,
            type: "_qiuzhaoreview._tcp.",
            domain: "local",
            interface: nil
        )
        return (name, endpoint)
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
        browser?.cancel()
        browser = nil
        candidates = []
    }

    var hasCandidates: Bool { !candidates.isEmpty }
}
