// Domain —— QuestionGraph 双端领域模型（与 Mac canonical schema 对齐）。
import Foundation

enum QuestionSource: String, Codable {
    case QUESTION_BANK
    case REVIEW_CAPSULE
}

/// question_key: "qb:<question_id>" 或 "capsule:<capsule_id>:<probe_key>"；graph_id = 稳定派生。
struct QuestionRef: Codable, Equatable {
    let source: QuestionSource
    let questionKey: String
    let sourceId: String
    let probeKey: String?

    static func questionBank(_ id: String) -> QuestionRef {
        QuestionRef(source: .QUESTION_BANK, questionKey: "qb:\(id)", sourceId: id, probeKey: nil)
    }
    static func capsule(_ capsuleId: String, probeKey: String) -> QuestionRef {
        QuestionRef(source: .REVIEW_CAPSULE, questionKey: "capsule:\(capsuleId):\(probeKey)",
                    sourceId: capsuleId, probeKey: probeKey)
    }
}

enum NodeKind: String, Codable, CaseIterable {
    case CENTER
    case EXPLANATION
    case TEMPORARY
}

struct LayoutDTO: Codable, Equatable {
    var x: Double
    var y: Double
    var revision: Int
}

struct GraphNodeDTO: Codable, Identifiable, Equatable {
    var id: String { nodeId }
    let nodeId: String
    let kind: NodeKind
    var title: String
    let bodyMarkdown: String
    var nodeRevision: Int
    var layout: LayoutDTO

    var isCenter: Bool { kind == .CENTER }
}

struct GraphSnapshotDTO: Codable, Equatable {
    let graphId: String
    let questionKey: String
    let roundId: String?
    var revision: Int
    let centerNodeId: String
    var nodes: [GraphNodeDTO]

    func center() -> GraphNodeDTO? { nodes.first { $0.nodeId == centerNodeId } }
    func visibleChildren() -> [GraphNodeDTO] { nodes.filter { $0.nodeId != centerNodeId } }
}

struct ActiveGraphInfo: Codable, Equatable {
    let graphId: String
    let roundId: String
}

/// iPad 本地交互状态视图（cache 顶层）。所有 canonical 数据经 ClientStore。
struct QuestionGraphState: Equatable {
    var snapshot: GraphSnapshotDTO?
    var activeRoundId: String?
    var selectedNodeId: String?
    /// 拖动过程中的瞬时位置（server 确认前不覆盖 canonical layout）
    var dragTransient: [String: CGPoint] = [:]
    /// 本地已 durable、等待 Mac ACK 的位置；显示优先级高于 canonical layout。
    var pendingPositions: [String: CGPoint] = [:]
    var managedNodeId: String?          // single-tap sheet
    var readerRoute: String?            // double-tap 进入 node
}
