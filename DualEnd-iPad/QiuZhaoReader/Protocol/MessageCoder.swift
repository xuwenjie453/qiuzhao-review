// MessageCoder —— Envelope 编解码 + payload 结构化读取；未知 type / 版本不符安全处理。
import Foundation

enum MessageCoderError: Error {
    case jsonParse
    case protocolUnsupported(Int?)
    case unknownType(String)
}

struct DecodedEnvelope {
    let messageId: String
    let type: String
    let sessionEpoch: String?
    let payload: [String: JSONValue]
}

enum MessageCoder {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }()

    /// 解析原始文本帧; 未知 type → throw unknownType(由调用方记录忽略)
    static func decode(_ raw: String) throws -> DecodedEnvelope {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MessageCoderError.jsonParse
        }
        guard let v = obj["v"] as? Int, v == WireV1.version else {
            throw MessageCoderError.protocolUnsupported(obj["v"] as? Int)
        }
        guard let type = obj["type"] as? String else { throw MessageCoderError.unknownType("") }
        let json = try JSONSerialization.data(withJSONObject: obj)
        let env = try JSONDecoder().decode(Envelope.self, from: json)
        let payload = env.payload ?? [:]
        return DecodedEnvelope(messageId: env.messageId, type: type,
                               sessionEpoch: env.sessionEpoch, payload: payload)
    }

    /// 构造客户端消息 envelope
    static func make(_ type: String, payload: [String: Any]) -> String {
        var dict: [String: Any] = [
            "v": WireV1.version,
            "message_id": UUID().uuidString.lowercased(),
            "type": type,
            "session_epoch": NSNull(),
            "sent_at": Self.isoNow(),
        ]
        dict["payload"] = payload
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// session_epoch 隔离: 旧会话消息一律作废 (M-5.5)
    static func make(_ type: String, payload: [String: Any], epoch: String?) -> String {
        var dict: [String: Any] = [
            "v": WireV1.version,
            "message_id": UUID().uuidString.lowercased(),
            "type": type,
            "session_epoch": epoch ?? NSNull(),
            "sent_at": Self.isoNow(),
        ]
        dict["payload"] = payload
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }
}

// payload 便利读取
extension [String: JSONValue] {
    func string(_ k: String) -> String? { self[k]?.string }
    func int(_ k: String) -> Int? { self[k]?.number.map { Int($0) } }
    func double(_ k: String) -> Double? { self[k]?.number }
    func bool(_ k: String) -> Bool? { self[k]?.bool }
    func dict(_ k: String) -> [String: JSONValue]? { self[k]?.dict }
    func arr(_ k: String) -> [JSONValue]? { self[k]?.array }
}
