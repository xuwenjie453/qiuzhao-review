// ClientStore —— iPad 交互侧 durable cache / outbox / inbox dedup（单 actor 串行 SQLite）。
// 规则 (M-5.2/M-3.5): 每次用户 mutation 先 durable 再发网络; snapshot/patch 落盘后才 ACK;
// outbox 仅凭 server ACK 清除; 断连 INFLIGHT→PENDING。
import Foundation
import CryptoKit

enum OutboxState: String { case PENDING, INFLIGHT }

final actor ClientStore {
    private let db: SQLiteDB
    static let schema = """
    CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS daemon_identity(daemon_id TEXT PRIMARY KEY, last_seen_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS graphs_cache(
      graph_id TEXT PRIMARY KEY, question_key TEXT NOT NULL, round_id TEXT,
      revision INTEGER NOT NULL, center_node_id TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS nodes_cache(
      node_id TEXT PRIMARY KEY, graph_id TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL,
      body_markdown TEXT NOT NULL, node_revision INTEGER NOT NULL,
      x_norm REAL NOT NULL, y_norm REAL NOT NULL, layout_revision INTEGER NOT NULL,
      locally_deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS ink_cache(
      node_id TEXT PRIMARY KEY, ink_revision INTEGER NOT NULL DEFAULT 0, format TEXT NOT NULL,
      blob BLOB, blob_sha256 TEXT, dirty INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS active_state(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS inbox_dedup(message_id TEXT PRIMARY KEY, kind TEXT NOT NULL, applied_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS outbox(
      outbox_id TEXT PRIMARY KEY, message_id TEXT NOT NULL UNIQUE, kind TEXT NOT NULL,
      entity_id TEXT NOT NULL, payload_json TEXT NOT NULL, created_at TEXT NOT NULL,
      attempt_count INTEGER NOT NULL DEFAULT 0, last_attempt_at TEXT,
      state TEXT NOT NULL DEFAULT 'PENDING');
    """

    init(dbPath: String) {
        guard let db = SQLiteDB(path: dbPath) else { fatalError("cannot open store \(dbPath)") }
        self.db = db
        try? db.exec(ClientStore.schema)
    }

    static func inMemory() -> ClientStore { ClientStore(dbPath: ":memory:") }

    // MARK: - identity
    func preferredDaemonId() -> String? {
        try? db.query("SELECT daemon_id FROM daemon_identity LIMIT 1").first?["daemon_id"] as? String
    }
    func rememberDaemon(_ daemonId: String) {
        try? db.exec("INSERT INTO daemon_identity(daemon_id,last_seen_at) VALUES (?,?) ON CONFLICT(daemon_id) DO UPDATE SET last_seen_at=excluded.last_seen_at",
                     [daemonId, Date().timeIntervalSince1970])
    }

    // MARK: - cache 读取
    func cachedGraphState() -> QuestionGraphState {
        var st = QuestionGraphState()
        guard let g = try? db.query("SELECT * FROM graphs_cache WHERE active=1 LIMIT 1").first else { return st }
        let graphId = g["graph_id"] as? String ?? ""
        st.activeRoundId = g["round_id"] as? String
        st.snapshot = loadSnapshot(graphId: graphId)
        return st
    }

    func loadSnapshot(graphId: String) -> GraphSnapshotDTO? {
        guard let g = try? db.query("SELECT * FROM graphs_cache WHERE graph_id=?", [graphId]).first else { return nil }
        let nodes = (try? db.query("SELECT * FROM nodes_cache WHERE graph_id=? AND locally_deleted=0 ORDER BY rowid",
                                   [graphId]))?.compactMap { row -> GraphNodeDTO? in
            guard let kind = NodeKind(rawValue: row["kind"] as? String ?? "") else { return nil }
            return GraphNodeDTO(nodeId: row["node_id"] as! String, kind: kind,
                                title: row["title"] as? String ?? "",
                                bodyMarkdown: row["body_markdown"] as? String ?? "",
                                nodeRevision: (row["node_revision"] as? Int64).map(Int.init) ?? 1,
                                layout: LayoutDTO(x: row["x_norm"] as? Double ?? 0.5,
                                                  y: row["y_norm"] as? Double ?? 0.5,
                                                  revision: (row["layout_revision"] as? Int64).map(Int.init) ?? 1))
        } ?? []
        return GraphSnapshotDTO(graphId: graphId,
                                questionKey: g["question_key"] as? String ?? "",
                                roundId: g["round_id"] as? String,
                                revision: (g["revision"] as? Int64).map(Int.init) ?? 1,
                                centerNodeId: g["center_node_id"] as? String ?? "",
                                nodes: nodes)
    }

    // MARK: - snapshot replace（transaction; durable-before-ACK）
    func applySnapshot(payload: [String: JSONValue], messageId: String) -> GraphSnapshotDTO? {
        guard let dto = GraphCodec.snapshot(from: payload) else { return nil }
        db.begin()
        defer { db.rollback() }
        try? db.exec("INSERT OR REPLACE INTO graphs_cache(graph_id,question_key,round_id,revision,center_node_id,active,updated_at) VALUES (?,?,?,?,?,1,?)",
                     [dto.graphId, dto.questionKey, dto.roundId ?? "", dto.revision, dto.centerNodeId, Date().timeIntervalSince1970])
        // 保留本地未发送 outbox 意图的节点(不标删除): 简单策略——标记 server-absent 的本地 clean 节点为删除
        let existing = (try? db.query("SELECT node_id FROM nodes_cache WHERE graph_id=?", [dto.graphId])) ?? []
        let serverIds = Set(dto.nodes.map(\.nodeId))
        for row in existing {
            let nid = row["node_id"] as? String ?? ""
            let deletedLocal = (row["locally_deleted"] as? Int64 ?? 0) > 0
            let hasOutbox = (try? db.query("SELECT 1 FROM outbox WHERE entity_id=? AND state!='' LIMIT 1", [nid]).first) != nil
            if !serverIds.contains(nid) && !deletedLocal && !hasOutbox {
                try? db.exec("UPDATE nodes_cache SET locally_deleted=1 WHERE node_id=?", [nid])
            }
        }
        // upsert nodes（保留本地未同步 title/layout 意图）
        for n in dto.nodes {
            let local = try? db.query("SELECT title,x_norm,y_norm,node_revision,layout_revision FROM nodes_cache WHERE node_id=?", [n.nodeId]).first
            let pendingRow = try? db.query("SELECT kind FROM outbox WHERE entity_id=? ORDER BY rowid LIMIT 1", [n.nodeId]).first
            let pending = pendingRow != nil
            let pendingMove = (pendingRow?["kind"] as? String) == "MOVE_NODE"
            let title = (pending && local?["title"] != nil) ? (local?["title"] as? String ?? n.title) : n.title
            let x = (pendingMove ? local?["x_norm"] as? Double : nil) ?? n.layout.x
            let y = (pendingMove ? local?["y_norm"] as? Double : nil) ?? n.layout.y
            try? db.exec("INSERT OR REPLACE INTO nodes_cache (node_id,graph_id,kind,title,body_markdown,node_revision,x_norm,y_norm,layout_revision,locally_deleted,updated_at) VALUES (?,?,?,?,?,?,?,?,?,0,?)",
                [n.nodeId, dto.graphId, n.kind.rawValue, title, n.bodyMarkdown, n.nodeRevision,
                 x, y, n.layout.revision, Date().timeIntervalSince1970])
        }
        try? db.exec("INSERT INTO inbox_dedup(message_id,kind,applied_at) VALUES (?,?,?)", [messageId, "GRAPH_SNAPSHOT", Date().timeIntervalSince1970])
        db.commit()
        return dto
    }

    // MARK: - patch apply（base_revision 校验; mismatch → 由 SyncEngine 请求 snapshot）
    enum PatchResult { case applied(GraphSnapshotDTO?), baseMismatch, dedup, malformed }
    func applyPatch(payload: [String: JSONValue], messageId: String) -> PatchResult {
        if (try? db.query("SELECT 1 FROM inbox_dedup WHERE message_id=?", [messageId]).first) != nil {
            return .dedup
        }
        guard let graphId = payload.string("graph_id"),
              let base = payload.int("base_revision"),
              let target = payload.int("target_revision"),
              let ops = payload.arr("ops") else { return .malformed }
        guard let cur = try? db.query("SELECT revision FROM graphs_cache WHERE graph_id=?", [graphId]).first,
              (cur["revision"] as? Int64).map(Int.init) == base else {
            return .baseMismatch
        }
        db.begin()
        defer { db.rollback() }
        var nodeDirty = false
        for opVal in ops {
            guard let op = opVal.dict, let opName = op["op"]?.string else { continue }
            switch opName {
            case "ADD_NODE":
                guard let nv = op["node"]?.dict, let n = GraphCodec.node(from: nv) else { continue }
                try? db.exec("INSERT OR REPLACE INTO nodes_cache (node_id,graph_id,kind,title,body_markdown,node_revision,x_norm,y_norm,layout_revision,locally_deleted,updated_at) VALUES (?,?,?,?,?,?,?,?,?,0,?)",
                    [n.nodeId, graphId, n.kind.rawValue, n.title, n.bodyMarkdown, n.nodeRevision,
                     n.layout.x, n.layout.y, n.layout.revision, Date().timeIntervalSince1970])
                nodeDirty = true
            case "UPDATE_TITLE":
                guard let nid = op["node_id"]?.string, let title = op["title"]?.string else { continue }
                try? db.exec("UPDATE nodes_cache SET title=?, updated_at=? WHERE node_id=?", [title, Date().timeIntervalSince1970, nid])
            case "UPDATE_LAYOUT":
                guard let nid = op["node_id"]?.string, let lv = op["layout"]?.dict else { continue }
                try? db.exec("UPDATE nodes_cache SET x_norm=?, y_norm=?, layout_revision=? WHERE node_id=?",
                             [lv["x"]?.number ?? 0.5, lv["y"]?.number ?? 0.5, lv["revision"]?.number.map { Int($0) } ?? 1, nid])
            case "REMOVE_NODE":
                guard let nid = op["node_id"]?.string else { continue }
                try? db.exec("UPDATE nodes_cache SET locally_deleted=1, updated_at=? WHERE node_id=?", [Date().timeIntervalSince1970, nid])
                nodeDirty = true
            default: break
            }
        }
        _ = nodeDirty
        try? db.exec("UPDATE graphs_cache SET revision=?, round_id=?, updated_at=? WHERE graph_id=?",
                     [target, payload.string("round_id") ?? "", Date().timeIntervalSince1970, graphId])
        try? db.exec("INSERT INTO inbox_dedup(message_id,kind,applied_at) VALUES (?,?,?)", [messageId, "GRAPH_PATCH", Date().timeIntervalSince1970])
        db.commit()
        return .applied(loadSnapshot(graphId: graphId))
    }

    // MARK: - outbox
    func queueOutbox(messageId: String, kind: String, entityId: String, payload: [String: Any]) {
        let json = (try? JSONSerialization.data(withJSONObject: payload)).map { String(data: $0, encoding: .utf8) } ?? "{}"
        try? db.exec("INSERT INTO outbox(outbox_id,message_id,kind,entity_id,payload_json,created_at,state) VALUES (?,?,?,?,?,?,'PENDING')",
                     [UUID().uuidString, messageId, kind, entityId, json ?? "{}", Date().timeIntervalSince1970])
    }
    func pendingOutbox() -> [[String: Any]] {
        (try? db.query("SELECT * FROM outbox WHERE state='PENDING' ORDER BY rowid")) ?? []
    }
    func markInflight(_ messageId: String) {
        try? db.exec("UPDATE outbox SET state='INFLIGHT', attempt_count=attempt_count+1, last_attempt_at=? WHERE message_id=?",
                     [Date().timeIntervalSince1970, messageId])
    }
    func restoreInflightToPending() {
        try? db.exec("UPDATE outbox SET state='PENDING' WHERE state='INFLIGHT'")
    }
    /// ACK 清除（唯一删除依据）
    func clearOutbox(byMessageId messageId: String? = nil, byCommandId commandId: String? = nil) {
        if let m = messageId {
            try? db.exec("DELETE FROM outbox WHERE message_id=?", [m])
        }
        if let c = commandId {
            // CLIENT_COMMAND ack 通过 command_id 关联 payload_json 内含 command_id
            try? db.exec("DELETE FROM outbox WHERE payload_json LIKE ?", ["%\"\(c)\"%"])
        }
    }
    func hasOutbox(forEntity entityId: String) -> Bool {
        (try? db.query("SELECT 1 FROM outbox WHERE entity_id=? LIMIT 1", [entityId]).first) != nil
    }

    // MARK: - local mutations（先 durable）
    func localRename(nodeId: String, title: String, baseNodeRevision: Int) {
        db.begin(); defer { db.rollback() }
        try? db.exec("UPDATE nodes_cache SET title=?, updated_at=? WHERE node_id=? AND locally_deleted=0",
                     [title, Date().timeIntervalSince1970, nodeId])
        let messageId = UUID().uuidString.lowercased()
        queueOutboxInTx(messageId: messageId, kind: "RENAME_NODE", entityId: nodeId,
                        payload: ["command_id": messageId, "kind": "RENAME_NODE",
                                  "graph_id": currentGraphId() ?? "",
                                  "payload": ["node_id": nodeId, "title": title, "base_node_revision": baseNodeRevision]])
        db.commit()
    }
    /// Persists the move and returns the generated command id so the UI can
    /// keep the optimistic position until the matching server snapshot arrives.
    func localMove(nodeId: String, x: Double, y: Double, baseLayoutRevision: Int) -> String {
        db.begin(); defer { db.rollback() }
        try? db.exec("UPDATE nodes_cache SET x_norm=?, y_norm=?, updated_at=? WHERE node_id=? AND locally_deleted=0",
                     [x, y, Date().timeIntervalSince1970, nodeId])
        let messageId = UUID().uuidString.lowercased()
        queueOutboxInTx(messageId: messageId, kind: "MOVE_NODE", entityId: nodeId,
                        payload: ["command_id": messageId, "kind": "MOVE_NODE",
                                  "graph_id": currentGraphId() ?? "",
                                  "payload": ["node_id": nodeId, "x_norm": x, "y_norm": y, "base_layout_revision": baseLayoutRevision]])
        db.commit()
        return messageId
    }
    func localDelete(nodeId: String, baseNodeRevision: Int) {
        db.begin(); defer { db.rollback() }
        try? db.exec("UPDATE nodes_cache SET locally_deleted=1, updated_at=? WHERE node_id=?",
                     [Date().timeIntervalSince1970, nodeId])
        let messageId = UUID().uuidString.lowercased()
        queueOutboxInTx(messageId: messageId, kind: "DELETE_NODE", entityId: nodeId,
                        payload: ["command_id": messageId, "kind": "DELETE_NODE",
                                  "graph_id": currentGraphId() ?? "",
                                  "payload": ["node_id": nodeId, "base_node_revision": baseNodeRevision]])
        db.commit()
    }
    func localInkSave(nodeId: String, revision: Int, blob: Data) {
        db.begin(); defer { db.rollback() }
        let sha = blob.sha256Hex()
        try? db.exec("INSERT INTO ink_cache(node_id,ink_revision,format,blob,blob_sha256,dirty,updated_at) VALUES (?,?,?,?,?,1,?) ON CONFLICT(node_id) DO UPDATE SET ink_revision=excluded.ink_revision, format=excluded.format, blob=excluded.blob, blob_sha256=excluded.blob_sha256, dirty=1, updated_at=excluded.updated_at",
                     [nodeId, revision, "pkdrawing-v1", blob, sha, Date().timeIntervalSince1970])
        let messageId = UUID().uuidString.lowercased()
        queueOutboxInTx(messageId: messageId, kind: "INK_PUT", entityId: nodeId,
                        payload: ["command_id": messageId, "kind": "INK_PUT",
                                  "node_id": nodeId, "ink_revision": revision,
                                  "format": "pkdrawing-v1", "blob_sha256": sha,
                                  "blob": blob.base64EncodedString(),
                                  "graph_id": currentGraphId() ?? ""])
        db.commit()
    }
    private func queueOutboxInTx(messageId: String, kind: String, entityId: String, payload: [String: Any]) {
        let json = (try? JSONSerialization.data(withJSONObject: payload)).map { String(data: $0, encoding: .utf8) } ?? "{}"
        try? db.exec("INSERT INTO outbox(outbox_id,message_id,kind,entity_id,payload_json,created_at,state) VALUES (?,?,?,?,?,?,'PENDING')",
                     [UUID().uuidString, messageId, kind, entityId, json ?? "{}", Date().timeIntervalSince1970])
    }
    private func currentGraphId() -> String? {
        (try? db.query("SELECT graph_id FROM graphs_cache WHERE active=1 LIMIT 1").first)?["graph_id"] as? String
    }

    // MARK: - ink 读取 / flush
    func inkRevision(nodeId: String) -> Int {
        let r = try? db.query("SELECT ink_revision FROM ink_cache WHERE node_id=?", [nodeId]).first
        return (r?["ink_revision"] as? Int64).map(Int.init) ?? 0
    }
    func inkBlob(nodeId: String) -> Data? {
        (try? db.query("SELECT blob FROM ink_cache WHERE node_id=?", [nodeId]).first)?["blob"] as? Data
    }

    func setActive(graphId: String?, roundId: String?) {
        try? db.exec("UPDATE graphs_cache SET active=0")
        if let graphId {
            try? db.exec("UPDATE graphs_cache SET active=1, round_id=? WHERE graph_id=?", [roundId ?? "", graphId])
        }
    }
}

extension Data {
    func sha256Hex() -> String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
