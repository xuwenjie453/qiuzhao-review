// Domain —— QuestionGraph 双端领域模型（与 Mac canonical schema 对齐）。
import Foundation

enum QuestionSource: String, Codable {
    case QUESTION_BANK
    case REVIEW_CAPSULE
    case USER_AUTHORED
}

/// question_key: "qb:<question_id>"、"capsule:<capsule_id>" 或 "user:<custom_id>"；Review 的 probe_key 仅描述本轮问法，不参与图身份。
struct QuestionRef: Codable, Equatable {
    let source: QuestionSource
    let questionKey: String
    let sourceId: String
    let probeKey: String?

    static func questionBank(_ id: String) -> QuestionRef {
        QuestionRef(source: .QUESTION_BANK, questionKey: "qb:\(id)", sourceId: id, probeKey: nil)
    }
    static func capsule(_ capsuleId: String, probeKey: String) -> QuestionRef {
        QuestionRef(source: .REVIEW_CAPSULE, questionKey: "capsule:\(capsuleId)",
                    sourceId: capsuleId, probeKey: probeKey)
    }
    static func userAuthored(_ customId: String) -> QuestionRef {
        QuestionRef(source: .USER_AUTHORED, questionKey: "user:\(customId)",
                    sourceId: customId, probeKey: nil)
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
    let ownerGraphId: String?
    let visibility: NodeVisibility
    let kind: NodeKind
    var title: String
    let bodyMarkdown: String
    let parentNodeId: String?
    var nodeRevision: Int
    var layout: LayoutDTO

    var isCenter: Bool { kind == .CENTER }
    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id", ownerGraphId = "owner_graph_id", visibility, kind, title,
             bodyMarkdown = "body_markdown", parentNodeId = "parent_node_id",
             nodeRevision = "node_revision", layout
    }

    init(nodeId: String, ownerGraphId: String? = nil, visibility: NodeVisibility = .OWN,
         kind: NodeKind, title: String, bodyMarkdown: String, parentNodeId: String? = nil,
         nodeRevision: Int, layout: LayoutDTO) {
        self.nodeId = nodeId; self.ownerGraphId = ownerGraphId; self.visibility = visibility
        self.kind = kind; self.title = title; self.bodyMarkdown = bodyMarkdown
        self.parentNodeId = parentNodeId
        self.nodeRevision = nodeRevision; self.layout = layout
    }
}

enum NodeVisibility: String, Codable { case OWN, INHERITED }

struct GraphSnapshotDTO: Codable, Equatable {
    let graphId: String
    let questionKey: String
    let roundId: String?
    var revision: Int
    let centerNodeId: String
    let parentGraphs: [ParentGraphInfo]
    var nodes: [GraphNodeDTO]

    init(graphId: String, questionKey: String, roundId: String?, revision: Int,
         centerNodeId: String, parentGraphs: [ParentGraphInfo] = [], nodes: [GraphNodeDTO]) {
        self.graphId = graphId; self.questionKey = questionKey; self.roundId = roundId
        self.revision = revision; self.centerNodeId = centerNodeId; self.parentGraphs = parentGraphs; self.nodes = nodes
    }

    func center() -> GraphNodeDTO? { nodes.first { $0.nodeId == centerNodeId } }
    func visibleChildren() -> [GraphNodeDTO] { nodes.filter { $0.nodeId != centerNodeId } }

    /// Canonical parent id is preserved on the node. Rendering alone falls back to
    /// the current graph CENTER when an old/missing/deleted/inherited parent is not visible.
    func resolvedParent(of node: GraphNodeDTO) -> GraphNodeDTO? {
        guard !node.isCenter else { return nil }
        if let parentNodeId = node.parentNodeId,
           let visibleParent = nodes.first(where: { $0.nodeId == parentNodeId }) {
            return visibleParent
        }
        return center()
    }

    enum CodingKeys: String, CodingKey {
        case graphId = "graph_id", questionKey = "question_key", roundId = "round_id",
             revision, centerNodeId = "center_node_id", parentGraphs = "parent_graphs", nodes
    }
}

struct ParentGraphInfo: Codable, Equatable {
    let graphId: String
    let inheritanceKind: String
    enum CodingKeys: String, CodingKey { case graphId = "graph_id", inheritanceKind = "inheritance_kind" }
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
