// GraphCodec —— JSONValue payload → 领域 DTO（Snapshot / Node / Patch ops 解析）
import Foundation

enum GraphCodec {
    static func node(from dict: [String: JSONValue]) -> GraphNodeDTO? {
        guard let nodeId = dict["node_id"]?.string,
              let kindRaw = dict["kind"]?.string,
              let kind = NodeKind(rawValue: kindRaw) else { return nil }
        let layoutD = dict["layout"]?.dict
        return GraphNodeDTO(
            nodeId: nodeId, kind: kind,
            title: dict["title"]?.string ?? "",
            bodyMarkdown: dict["body_markdown"]?.string ?? "",
            nodeRevision: dict["node_revision"]?.number.map { Int($0) } ?? 1,
            layout: LayoutDTO(
                x: layoutD?["x"]?.number ?? 0.5,
                y: layoutD?["y"]?.number ?? 0.5,
                revision: layoutD?["revision"]?.number.map { Int($0) } ?? 1))
    }

    static func snapshot(from payload: [String: JSONValue]) -> GraphSnapshotDTO? {
        guard let graphId = payload["graph_id"]?.string,
              let center = payload["center_node_id"]?.string,
              let nodesV = payload["nodes"]?.array else { return nil }
        let nodes = nodesV.compactMap { v -> GraphNodeDTO? in
            guard let d = v.dict else { return nil }
            return node(from: d)
        }
        guard nodes.contains(where: { $0.nodeId == center }) else { return nil }
        return GraphSnapshotDTO(graphId: graphId,
                                questionKey: payload["question_key"]?.string ?? "",
                                roundId: payload["round_id"]?.string,
                                revision: payload["revision"]?.number.map { Int($0) } ?? 1,
                                centerNodeId: center, nodes: nodes)
    }
}
