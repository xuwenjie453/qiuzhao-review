// Wire Protocol v1 —— Envelope + 全部消息 payload 结构（与 Mac protocol/envelope.mjs、fixtures 同步）。
import Foundation

/// 顶层信封 (M-2.1)。所有字段与 wire 精确对应；解码未知 type 时忽略整条消息，不 crash。
struct Envelope: Codable {
    let v: Int
    let messageId: String
    let type: String
    let sessionEpoch: String?
    let sentAt: String
    let payload: [String: JSONValue]?
    enum CodingKeys: String, CodingKey {
        case v, type, payload
        case messageId = "message_id"
        case sessionEpoch = "session_epoch"
        case sentAt = "sent_at"
    }
}

/// 轻量 JSON 容器（避免 Codable 对未知字段敏感）
enum JSONValue: Codable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s) }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .null }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }
    var string: String? { if case .string(let s) = self { return s } else { return nil } }
    var number: Double? { if case .number(let n) = self { return n } else { return nil } }
    var bool: Bool? { if case .bool(let b) = self { return b } else { return nil } }
    var dict: [String: JSONValue]? { if case .object(let o) = self { return o } else { return nil } }
    var array: [JSONValue]? { if case .array(let a) = self { return a } else { return nil } }
}

// 服务端→客户端消息类型（大小写精确）
enum ServerMessageType: String {
    case WELCOME, ACTIVE_GRAPH_CHANGED, GRAPH_SNAPSHOT, GRAPH_PATCH,
         INK_SNAPSHOT, COMMAND_ACK, COMMAND_REJECTED, PING
}
// 客户端→服务端
enum ClientMessageType: String {
    case HELLO, SNAPSHOT_REQUEST, CLIENT_COMMAND, INK_PUT, ACK, PONG
}

// ---- 结构化 payload（用于解码关键消息）----
struct WelcomePayload: Codable {
    let selectedProtocol: Int
    let daemonId: String
    let sessionEpoch: String
    let serverSeq: Int
    let active: ActiveGraphInfo?
    enum CodingKeys: String, CodingKey {
        case selectedProtocol = "selected_protocol", daemonId = "daemon_id",
             sessionEpoch = "session_epoch", serverSeq = "server_seq", active
    }
}

struct HelloPayload: Codable {
    let deviceId: String
    let clientBuild: String
    let supportedProtocols: [Int]
    let lastServerSeq: Int
    let cachedGraph: CachedGraphInfo?
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id", clientBuild = "client_build",
             supportedProtocols = "supported_protocols", lastServerSeq = "last_server_seq",
             cachedGraph = "cached_graph"
    }
}
struct CachedGraphInfo: Codable {
    let graphId: String
    let revision: Int
}

/// 协议版本常量（与 Mac PROTOCOL_VERSION 对齐）
enum WireV1 {
    static let version = 1
    static let bonjourService = "_qiuzhaoreview._tcp"
    static let clientBuild = "1.0.0"
}
