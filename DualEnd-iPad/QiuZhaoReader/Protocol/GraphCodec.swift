// GraphCodec —— JSONValue payload → 领域 DTO（Snapshot / Node / Patch ops 解析）
import Foundation

enum GraphCodec {
    static func node(from dict: [String: JSONValue]) -> GraphNodeDTO? {
        guard let nodeId = dict["node_id"]?.string,
              let kindRaw = dict["kind"]?.string,
              let kind = NodeKind(rawValue: kindRaw) else { return nil }
        let layoutD = dict["layout"]?.dict
        let visibility: NodeVisibility
        if let raw = dict["visibility"]?.string { guard let parsed = NodeVisibility(rawValue: raw) else { return nil }; visibility = parsed }
        else { visibility = .OWN }
        return GraphNodeDTO(
            nodeId: nodeId, ownerGraphId: dict["owner_graph_id"]?.string,
            parentNodeId: dict["parent_node_id"]?.string,
            visibility: visibility,
            kind: kind,
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
        let parentValues = payload["parent_graphs"]?.array ?? []
        let parents = parentValues.compactMap { v -> ParentGraphInfo? in
            guard let d = v.dict, let gid = d["graph_id"]?.string,
                  let kind = d["inheritance_kind"]?.string, kind == "SHARED_EXPLANATIONS" else { return nil }
            return ParentGraphInfo(graphId: gid, inheritanceKind: kind)
        }
        guard parents.count == parentValues.count else { return nil }
        return GraphSnapshotDTO(graphId: graphId,
                                questionKey: payload["question_key"]?.string ?? "",
                                roundId: payload["round_id"]?.string,
                                revision: payload["revision"]?.number.map { Int($0) } ?? 1,
                                centerNodeId: center,
                                parentGraphs: parents,
                                nodes: nodes)
    }
}
