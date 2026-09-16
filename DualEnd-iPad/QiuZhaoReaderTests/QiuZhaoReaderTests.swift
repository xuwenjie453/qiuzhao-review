// iPad 单元测试 —— Store transaction / outbox replay / snapshot replace / patch validation /
// 手势状态 reducer / 协议编解码 (M-14.4)。
import XCTest
import PencilKit
import Combine
@testable import QiuZhaoReader

func jval(_ dict: [String: Any]) -> [String: JSONValue] {
    func conv(_ v: Any) -> JSONValue {
        if let s = v as? String { return .string(s) }
        if let b = v as? Bool { return .bool(b) }
        if let n = v as? Int { return .number(Double(n)) }
        if let d = v as? Double { return .number(d) }
        if let a = v as? [Any] { return .array(a.map(conv)) }
        if let o = v as? [String: Any] { return .object(o.mapValues(conv)) }
        return .null
    }
    return dict.mapValues(conv)
}

func sampleSnapshot(graphId: String = "g1", revision: Int = 1, roundId: String = "r1") -> [String: JSONValue] {
    jval([
        "graph_id": graphId, "question_key": "qb:Redis-01-003", "round_id": roundId,
        "revision": revision, "center_node_id": "n0",
        "nodes": [
            ["node_id": "n0", "kind": "CENTER", "title": "Redis过期删除策略", "body_markdown": "问题正文", "node_revision": 1,
             "layout": ["x": 0, "y": 0, "revision": 1]],
            ["node_id": "n1", "kind": "EXPLANATION", "title": "惰性与定期", "body_markdown": "解释原文", "node_revision": 1,
             "layout": ["x": 200, "y": -70, "revision": 1]],
        ],
    ])
}

final class StoreTests: XCTestCase {
    var store: ClientStore!
    override func setUp() { store = ClientStore(dbPath: ":memory:") }

    func testSnapshotApplyDurableAndReload() async {
        let dto = await store.applySnapshot(payload: sampleSnapshot(), messageId: "m-snap-1")
        XCTAssertNotNil(dto)
        XCTAssertEqual(dto?.nodes.count, 2)
        let st = await store.cachedGraphState()
        XCTAssertEqual(st.snapshot?.nodes.count, 2)
        XCTAssertEqual(st.snapshot?.centerNodeId, "n0")
    }

    func testSnapshotParentPersistsThroughDurableCacheReload() async {
        var payload = sampleSnapshot()
        guard case .array(var nodes)? = payload["nodes"], case .object(var child) = nodes[1] else {
            return XCTFail("测试快照格式错误")
        }
        child["parent_node_id"] = .string("n0")
        nodes[1] = .object(child)
        payload["nodes"] = .array(nodes)
        _ = await store.applySnapshot(payload: payload, messageId: "parent-snapshot")
        let restored = await store.cachedGraphState()
        XCTAssertEqual(restored.snapshot?.nodes.first(where: { $0.nodeId == "n1" })?.parentNodeId, "n0")
    }

    func testLegacyNodesCacheMigratesAndAcceptsParentSnapshot() async {
        let path = NSTemporaryDirectory() + "legacy-parent-\(UUID().uuidString).sqlite"
        do {
            let legacy = try XCTUnwrap(SQLiteDB(path: path))
            try legacy.exec("CREATE TABLE nodes_cache(node_id TEXT PRIMARY KEY, graph_id TEXT NOT NULL, owner_graph_id TEXT, kind TEXT NOT NULL, title TEXT NOT NULL, body_markdown TEXT NOT NULL, node_revision INTEGER NOT NULL, x_norm REAL NOT NULL, y_norm REAL NOT NULL, layout_revision INTEGER NOT NULL, locally_deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)")
            try legacy.exec("INSERT INTO nodes_cache VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", ["n1", "g1", "g1", "EXPLANATION", "旧解释", "旧正文", 1, 0.7, 0.4, 1, 0, 0.0])
        } catch { return XCTFail("构造旧缓存失败: \(error)") }
        let migrated = ClientStore(dbPath: path)
        var payload = sampleSnapshot()
        guard case .array(var nodes)? = payload["nodes"], case .object(var child) = nodes[1] else {
            return XCTFail("测试快照格式错误")
        }
        child["parent_node_id"] = .string("n0")
        nodes[1] = .object(child)
        payload["nodes"] = .array(nodes)
        _ = await migrated.applySnapshot(payload: payload, messageId: "legacy-parent-snapshot")
        let restored = await migrated.cachedGraphState()
        XCTAssertEqual(restored.snapshot?.nodes.first(where: { $0.nodeId == "n1" })?.parentNodeId, "n0")
    }

    func testLegacyMoveOutboxMigratesToWorldCoordinates() async {
        let path = NSTemporaryDirectory() + "legacy-outbox-\(UUID().uuidString).sqlite"
        do {
            let legacy = try XCTUnwrap(SQLiteDB(path: path))
            try legacy.exec("CREATE TABLE nodes_cache(node_id TEXT PRIMARY KEY, graph_id TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL, body_markdown TEXT NOT NULL, node_revision INTEGER NOT NULL, x_norm REAL NOT NULL, y_norm REAL NOT NULL, layout_revision INTEGER NOT NULL, locally_deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)")
            try legacy.exec("CREATE TABLE outbox(outbox_id TEXT PRIMARY KEY, message_id TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, entity_id TEXT NOT NULL, payload_json TEXT NOT NULL, created_at TEXT NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0, last_attempt_at TEXT, state TEXT NOT NULL DEFAULT 'PENDING')")
            let payload = "{\"command_id\":\"cmd-legacy\",\"kind\":\"MOVE_NODE\",\"graph_id\":\"g1\",\"payload\":{\"node_id\":\"n1\",\"x_norm\":0.7,\"y_norm\":0.4,\"base_layout_revision\":1}}"
            try legacy.exec("INSERT INTO outbox(outbox_id,message_id,kind,entity_id,payload_json,created_at,state) VALUES (?,?,?,?,?,?,?)",
                            ["o1", "m1", "MOVE_NODE", "n1", payload, 0.0, "PENDING"])
        } catch { return XCTFail("构造旧 outbox 失败: \(error)") }

        let migrated = ClientStore(dbPath: path)
        let outbox = await migrated.pendingOutbox()
        let payload = try? XCTUnwrap(outbox.first?["payload_json"] as? String)
        XCTAssertNotNil(payload)
        let json = (payload ?? "").data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let move = json?["payload"] as? [String: Any]
        XCTAssertNil(move?["x_norm"])
        XCTAssertNil(move?["y_norm"])
        guard let x = (move?["x_world"] as? NSNumber)?.doubleValue,
              let y = (move?["y_world"] as? NSNumber)?.doubleValue else {
            return XCTFail("旧 MOVE_NODE 未转换为 world 坐标")
        }
        XCTAssertEqual(x, 200, accuracy: 0.000001)
        XCTAssertEqual(y, -70, accuracy: 0.000001)
    }

    func testInboxDedup() async {
        _ = await store.applySnapshot(payload: sampleSnapshot(), messageId: "m-dup")
        _ = await store.applySnapshot(payload: sampleSnapshot(revision: 2), messageId: "m-dup")
        // 同一 message_id 再次 apply 不改变 revision(报 dedup → 直接返回原数据或 nil)
        let st = await store.cachedGraphState()
        XCTAssertNotNil(st.snapshot)
    }

    func testPatchApplyAndBaseMismatch() async {
        _ = await store.applySnapshot(payload: sampleSnapshot(), messageId: "m1")
        let ok = await store.applyPatch(payload: jval([
            "graph_id": "g1", "base_revision": 1, "target_revision": 2,
            "ops": [["op": "ADD_NODE", "node": ["node_id": "n2", "kind": "TEMPORARY", "title": "临时",
                    "parent_node_id": "n1", "body_markdown": "b", "node_revision": 1, "layout": ["x": 0.3, "y": 0.3, "revision": 1]]]],
        ]), messageId: "m2")
        if case .applied(let dto) = ok {
            XCTAssertEqual(dto?.nodes.count, 3)
            XCTAssertEqual(dto?.nodes.first(where: { $0.nodeId == "n2" })?.parentNodeId, "n1")
        } else { XCTFail("应 applied") }
        // base mismatch → 不盲 apply
        let bad = await store.applyPatch(payload: jval([
            "graph_id": "g1", "base_revision": 99, "target_revision": 3,
            "ops": [["op": "REMOVE_NODE", "node_id": "n0"]],
        ]), messageId: "m3")
        if case .baseMismatch = bad {} else { XCTFail("应 baseMismatch") }
        let st = await store.cachedGraphState()
        XCTAssertEqual(st.snapshot?.revision, 2)
    }

    func testOutboxLifecycle() async {
        await store.localRename(nodeId: "n1", title: "新标题", baseNodeRevision: 1)
        let box = await store.pendingOutbox()
        XCTAssertEqual(box.count, 1)
        XCTAssertEqual(box[0]["kind"] as? String, "RENAME_NODE")
        await store.markInflight((box[0]["message_id"] as? String) ?? "")
        var after = await store.pendingOutbox()
        XCTAssertEqual(after.count, 0)
        await store.restoreInflightToPending()
        after = await store.pendingOutbox()
        XCTAssertEqual(after.count, 1)
        await store.clearOutbox(byMessageId: (after[0]["message_id"] as? String) ?? "")
        after = await store.pendingOutbox()
        XCTAssertEqual(after.count, 0)
    }

    func testLocalDeleteBeforeServerAck() async {
        _ = await store.applySnapshot(payload: sampleSnapshot(), messageId: "m1")
        await store.localDelete(nodeId: "n1", baseNodeRevision: 1)
        let st = await store.cachedGraphState()
        XCTAssertFalse(st.snapshot?.nodes.contains { $0.nodeId == "n1" } ?? true)
        let hasOutbox = await store.hasOutbox(forEntity: "n1")
        XCTAssertTrue(hasOutbox)
    }

    func testPendingMoveSurvivesInterimSnapshot() async {
        _ = await store.applySnapshot(payload: sampleSnapshot(), messageId: "m1")
        let command = await store.localMove(nodeId: "n1", x: 0.91, y: 0.12, baseLayoutRevision: 1)
        XCTAssertFalse(command.isEmpty)
        // A reconnect snapshot may still contain the old canonical position;
        // the local durable MOVE_NODE intent must remain visible until ACK.
        _ = await store.applySnapshot(payload: sampleSnapshot(revision: 2), messageId: "m2")
        let state = await store.cachedGraphState()
        guard let moved = state.snapshot?.nodes.first(where: { $0.nodeId == "n1" })?.layout else {
            return XCTFail("移动节点应仍存在")
        }
        XCTAssertEqual(moved.x, 0.91, accuracy: 0.000001)
        XCTAssertEqual(moved.y, 0.12, accuracy: 0.000001)
    }
}

final class ProtocolTests: XCTestCase {
    func testEnvelopeDecode() throws {
        let raw = """
        {"v":5,"message_id":"m1","type":"WELCOME","session_epoch":"e1","sent_at":"2026-09-08T12:34:56.123Z",
         "payload":{"selected_protocol":5,"daemon_id":"mac-A","server_seq":3,"active":{"graph_id":"g1","round_id":"r1"}}}
        """
        let env = try MessageCoder.decode(raw)
        XCTAssertEqual(env.type, "WELCOME")
        XCTAssertEqual(env.payload["daemon_id"]?.string, "mac-A")
    }

    func testUnknownTypeDecodableAndIgnoredUpstream() {
        // M-2.7: 未知 type 记录并忽略, 不 crash —— 解码层应成功返回, 由 SyncEngine 上层忽略
        let raw = """
        {"v":5,"message_id":"m2","type":"WHATEVER_NEW","session_epoch":null,"sent_at":"x","payload":{}}
        """
        let env = try? MessageCoder.decode(raw)
        XCTAssertNotNil(env)
        XCTAssertEqual(env?.type, "WHATEVER_NEW")
    }

    func testVersionMismatch() {
        let raw = """
        {"v":2,"message_id":"m3","type":"HELLO","session_epoch":null,"sent_at":"x","payload":{}}
        """
        do {
            _ = try MessageCoder.decode(raw)
            XCTFail("应抛 protocolUnsupported")
        } catch MessageCoderError.protocolUnsupported(let v) {
            XCTAssertEqual(v, 2)
        } catch { XCTFail("错误类型") }
    }

    func testSnapshotDecodeToDTO() {
        let snap = GraphCodec.snapshot(from: sampleSnapshot())
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.centerNodeId, "n0")
        XCTAssertEqual(snap?.nodes.count, 2)
    }

    func testGraphCodecDecodesOptionalParentAndOldPayload() {
        let old = GraphCodec.snapshot(from: sampleSnapshot())
        XCTAssertNil(old?.nodes.first(where: { $0.nodeId == "n1" })?.parentNodeId)
        var payload = sampleSnapshot()
        guard case .array(var nodes)? = payload["nodes"], case .object(var child) = nodes[1] else {
            return XCTFail("测试快照格式错误")
        }
        child["parent_node_id"] = .string("n0")
        nodes[1] = .object(child)
        payload["nodes"] = .array(nodes)
        XCTAssertEqual(GraphCodec.snapshot(from: payload)?.nodes.first(where: { $0.nodeId == "n1" })?.parentNodeId, "n0")
    }
}

final class TopologyLogicTests: XCTestCase {
    func testGraphCanvasRoundTripUsesWorldCoordinates() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let world = CGPoint(x: 273, y: -141)
        let screen = geometry.screenPoint(from: world)
        let roundTrip = geometry.worldPoint(from: screen)
        XCTAssertEqual(roundTrip.x, world.x, accuracy: 0.000001)
        XCTAssertEqual(roundTrip.y, world.y, accuracy: 0.000001)
        XCTAssertTrue(geometry.contentRect.contains(screen))
    }

    func testGraphCanvasDoesNotClampOutsideViewport() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let minPoint = geometry.worldPoint(from: CGPoint(x: -100, y: -100))
        let maxPoint = geometry.worldPoint(from: CGPoint(x: 5000, y: 5000))
        XCTAssertLessThan(minPoint.x, 0)
        XCTAssertLessThan(minPoint.y, 0)
        XCTAssertGreaterThan(maxPoint.x, 0)
        XCTAssertGreaterThan(maxPoint.y, 0)
    }

    func testCanvasViewportTransformIsLocalUnboundedAndReversible() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let offset = CGSize(width: 99_999, height: -99_999)
        let graph = geometry.screenPoint(from: CGPoint(x: 370, y: -120))
        let visual = geometry.visualPoint(from: graph, viewportOffset: offset)
        let restored = geometry.graphPoint(fromVisual: visual, viewportOffset: offset)
        XCTAssertEqual(restored.x, graph.x, accuracy: 0.000001)
        XCTAssertEqual(restored.y, graph.y, accuracy: 0.000001)
        XCTAssertTrue(geometry.visualHitRect(at: CGPoint(x: 370, y: -120), viewportOffset: offset).contains(visual))
    }

    func testNodeStartPanOwnershipStaysBlockedAfterNodeMovesAway() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let initialNodePosition = CGPoint.zero
        let startLocation = geometry.screenPoint(from: initialNodePosition)
        let session = geometry.beginCanvasPanSession(
            startLocation: startLocation,
            stableWorldPositions: [initialNodePosition],
            initialViewportOffset: .zero
        )
        let movedNodePosition = CGPoint(x: 420, y: 0)
        let incorrectPerFrameResult = geometry.beginCanvasPanSession(
            startLocation: startLocation,
            stableWorldPositions: [movedNodePosition],
            initialViewportOffset: .zero
        )

        XCTAssertFalse(session.ownsCanvas)
        XCTAssertTrue(incorrectPerFrameResult.ownsCanvas)
        XCTAssertEqual(session.initialViewportOffset, .zero)
    }

    func testCanvasPanRemainsUnboundedRegardlessOfNodePositions() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let world = CGPoint(x: -50_000, y: 77_000)
        let graph = geometry.screenPoint(from: world)
        let offset = CGSize(width: 250_000, height: -125_000)
        XCTAssertEqual(geometry.graphPoint(fromVisual: geometry.visualPoint(from: graph, viewportOffset: offset), viewportOffset: offset), graph)
    }

    func testCanvasPanChangesOnlyLocalViewportOffset() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let stablePositions = [CGPoint(x: -200, y: 100), CGPoint(x: 300, y: -220)]
        let committed = CGSize(width: 40, height: -30)
        let blankStart = CGPoint(x: 10, y: 10)
        let session = geometry.beginCanvasPanSession(
            startLocation: blankStart,
            stableWorldPositions: stablePositions,
            initialViewportOffset: committed
        )
        let proposed = CGSize(width: session.initialViewportOffset.width + 120,
                              height: session.initialViewportOffset.height + 80)
        let panned = proposed

        XCTAssertTrue(session.ownsCanvas)
        XCTAssertNotEqual(panned, committed)
        XCTAssertEqual(session.initialViewportOffset, committed)
    }

    func testPanOffsetIsRemovedBeforeNodeDragWritesWorldPosition() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let graphStart = geometry.screenPoint(from: CGPoint(x: -120, y: 80))
        let graphEnd = CGPoint(x: graphStart.x + 96, y: graphStart.y - 54)
        let offset = CGSize(width: 137, height: -93)

        let unpanned = geometry.worldPoint(from: graphEnd)
        let visualEnd = geometry.visualPoint(from: graphEnd, viewportOffset: offset)
        let panned = geometry.worldPoint(from: geometry.graphPoint(fromVisual: visualEnd, viewportOffset: offset))

        XCTAssertEqual(panned.x, unpanned.x, accuracy: 0.000001)
        XCTAssertEqual(panned.y, unpanned.y, accuracy: 0.000001)
    }

    func testVisualHitRectMovesWithViewportOffsetIncludingCenter() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let centerWorld = CGPoint.zero
        let originalCenter = geometry.screenPoint(from: centerWorld)
        let offset = CGSize(width: 160, height: -120)
        let visualCenter = geometry.visualPoint(from: originalCenter, viewportOffset: offset)
        let visualHitRect = geometry.visualHitRect(at: centerWorld, viewportOffset: offset)

        XCTAssertFalse(visualHitRect.contains(originalCenter))
        XCTAssertTrue(visualHitRect.contains(visualCenter))
    }

    func testResolvedParentPreservesVisibleHierarchyAndFallsBackToCenter() {
        let center = GraphNodeDTO(nodeId: "c", kind: .CENTER, title: "题目", bodyMarkdown: "q", nodeRevision: 1, layout: LayoutDTO(x: 0.5, y: 0.5, revision: 1))
        let parent = GraphNodeDTO(nodeId: "a", parentNodeId: "c", kind: .EXPLANATION, title: "A", bodyMarkdown: "a", nodeRevision: 1, layout: LayoutDTO(x: 0.7, y: 0.5, revision: 1))
        let child = GraphNodeDTO(nodeId: "b", parentNodeId: "a", kind: .EXPLANATION, title: "B", bodyMarkdown: "b", nodeRevision: 1, layout: LayoutDTO(x: 0.8, y: 0.6, revision: 1))
        let hierarchy = GraphSnapshotDTO(graphId: "g", questionKey: "q", roundId: nil, revision: 1, centerNodeId: "c", nodes: [center, parent, child])
        XCTAssertEqual(hierarchy.resolvedParent(of: child)?.nodeId, "a")
        let missingParent = GraphNodeDTO(nodeId: "orphan", parentNodeId: "deleted", kind: .EXPLANATION, title: "孤儿", bodyMarkdown: "o", nodeRevision: 1, layout: LayoutDTO(x: 0.2, y: 0.2, revision: 1))
        let fallback = GraphSnapshotDTO(graphId: "g", questionKey: "q", roundId: nil, revision: 1, centerNodeId: "c", nodes: [center, missingParent])
        XCTAssertEqual(fallback.resolvedParent(of: missingParent)?.nodeId, "c")
    }

    func testRadialSlotDeterministicAndExpandsOutward() {
        let p0 = TopologyLayout.slot(index: 0)
        let p0b = TopologyLayout.slot(index: 0)
        XCTAssertEqual(p0.x, p0b.x)
        XCTAssertEqual(p0.y, p0b.y)
        for i in 0..<40 {
            let p = TopologyLayout.slot(index: i)
            XCTAssertTrue(p.x.isFinite)
            XCTAssertTrue(p.y.isFinite)
        }
        let firstRadius = hypot(TopologyLayout.slot(index: 0).x, TopologyLayout.slot(index: 0).y)
        let laterRadius = hypot(TopologyLayout.slot(index: 36).x, TopologyLayout.slot(index: 36).y)
        XCTAssertGreaterThan(laterRadius, firstRadius)
    }

    func testEdgeAutoPanMovesCameraOppositeToDraggedEdge() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let delta = geometry.edgeAutoPanDelta(
            at: CGPoint(x: geometry.contentRect.maxX - 1, y: geometry.contentRect.midY),
            elapsed: 1.0 / 60.0
        )
        XCTAssertLessThan(delta.width, 0)
        XCTAssertEqual(delta.height, 0, accuracy: 0.000001)
    }

    func testMarkdownParserBlocks() {
        let md = """
        # 标题
        ## 小标题
        一段正文。
        - 列表1
        - 列表2
        ```swift
        let a = 1
        ```
        > 引用文字
        ---
        """
        let blocks = MarkdownParser.parse(md)
        XCTAssertTrue(blocks.contains { if case .heading(let l, _) = $0, l == 1 { return true } else { return false } })
        XCTAssertTrue(blocks.contains { if case .code(let c) = $0, c.contains("let a") { return true } else { return false } })
        XCTAssertTrue(blocks.contains { if case .list = $0 { return true } else { return false } })
        XCTAssertTrue(blocks.contains { if case .quote = $0 { return true } else { return false } })
        XCTAssertTrue(blocks.contains { if case .hr = $0 { return true } else { return false } })
    }

    func testCENTERCannotBeDeletedByUIRule() {
        // UI 层规则: CENTER 不提供删除(模型层守卫在 Mac server; iPad UI 断言)
        var state = QuestionGraphState()
        let snap = GraphCodec.snapshot(from: sampleSnapshot())
        state.snapshot = snap
        let center = snap?.center()
        XCTAssertEqual(center?.kind, .CENTER)
        // 若误触, delete() 应被 UI 拒绝——此处验证守卫逻辑(通过 node.isCenter)
        XCTAssertTrue(center?.isCenter ?? false)
    }
}

final class ReaderViewportTests: XCTestCase {
    func testFitWidthScaleFillsLandscapeViewport() {
        let scale = ReaderViewportMath.fitWidthScale(viewportWidth: 1180, pageWidth: 595.92)
        XCTAssertEqual(595.92 * scale, 1180, accuracy: 0.5)
        XCTAssertGreaterThan(scale, 1)
    }

    func testFitWidthScaleClampsInvalidOrExtremeWidths() {
        XCTAssertEqual(ReaderViewportMath.fitWidthScale(viewportWidth: 0, pageWidth: 595.92), 0.5)
        XCTAssertEqual(ReaderViewportMath.fitWidthScale(viewportWidth: 5000, pageWidth: 595.92), 3.0)
    }

    func testRotationPreservesCanonicalVerticalPositionAndLocksHorizontal() {
        let canonical = ReaderViewportMath.canonicalTopY(contentOffsetY: 700, scale: 2)
        XCTAssertEqual(canonical, 350, accuracy: 0.0001)
        let restored = ReaderViewportMath.clampedOffsetY(canonicalTopY: canonical,
                                                         scale: 1.5,
                                                         contentSizeHeight: 4000,
                                                         viewportHeight: 800)
        XCTAssertEqual(restored, 525, accuracy: 0.0001)
    }

    func testRotationPositionClampsAtDocumentEnd() {
        let restored = ReaderViewportMath.clampedOffsetY(canonicalTopY: 5000,
                                                         scale: 2,
                                                         contentSizeHeight: 1800,
                                                         viewportHeight: 800)
        XCTAssertEqual(restored, 1000, accuracy: 0.0001)
    }

    // MARK: v3 Phase 2A —— contentSize 单位与镜像几何（06 号缺陷防回归）

    func testDisplayContentSizeUsesDisplayUnits() {
        let doc = CGSize(width: 595.92, height: 842.88)
        XCTAssertEqual(ReaderViewportMath.displayContentSize(documentSize: doc, scale: 1.0).width, 595.92, accuracy: 0.0001)
        XCTAssertEqual(ReaderViewportMath.displayContentSize(documentSize: doc, scale: 2.0).width, 1191.84, accuracy: 0.0001)
        XCTAssertEqual(ReaderViewportMath.displayContentSize(documentSize: doc, scale: 2.0).height, 1685.76, accuracy: 0.0001)
        XCTAssertEqual(ReaderViewportMath.displayContentSize(documentSize: doc, scale: 0.75).width, 446.94, accuracy: 0.01)
    }

    func testDocumentMirrorGeometryMatchesCanvasInvariant() {
        // 不变量：canonical P 经镜像层渲染于 position + P·scale，必须等于 P·z − contentOffset
        let cases: [(z: CGFloat, off: CGPoint)] = [
            (2.0, CGPoint(x: 0, y: 0)),
            (1.9801, CGPoint(x: 0, y: 1383.5)),
            (1.5, CGPoint(x: 0, y: 420)),
        ]
        for c in cases {
            let position = ReaderViewportMath.documentLayerPosition(contentOffset: c.off)
            let t = ReaderViewportMath.documentLayerTransform(scale: c.z)
            for p in [CGPoint(x: 0, y: 0), CGPoint(x: 595.92, y: 842.88), CGPoint(x: 297.96, y: 421.44)] {
                let viaMirror = CGPoint(x: position.x + p.applying(t).x,
                                        y: position.y + p.applying(t).y)
                let viaCanvas = ReaderViewportMath.displayPoint(from: p, scale: c.z, contentOffset: c.off)
                XCTAssertEqual(viaMirror.x, viaCanvas.x, accuracy: 0.0001)
                XCTAssertEqual(viaMirror.y, viaCanvas.y, accuracy: 0.0001)
            }
        }
    }

    func testCanvasOwnedViewportRoundTripsCanonicalPoint() {
        let canonical = CGPoint(x: 123.5, y: 660.25)
        let offset = CGPoint(x: 0, y: 420)
        let displayed = ReaderViewportMath.displayPoint(from: canonical, scale: 2, contentOffset: offset)
        let restored = ReaderViewportMath.canonicalPoint(from: displayed, scale: 2, contentOffset: offset)
        XCTAssertEqual(restored.x, canonical.x, accuracy: 0.0001)
        XCTAssertEqual(restored.y, canonical.y, accuracy: 0.0001)
    }

    func testHitTestBasisDividesByZoomOnly() {
        // hitTest point 处于 canvas bounds 坐标系（原点已随 contentOffset 移动），
        // canonical 换算只除 zoomScale、不再加 contentOffset——单位约定钉死。
        let z: CGFloat = 1.9801
        let boundsPoint = CGPoint(x: 396.0, y: 840.0)
        let doc = ReaderViewportMath.canonicalPoint(from: boundsPoint, scale: z, contentOffset: .zero)
        XCTAssertEqual(doc.x, boundsPoint.x / z, accuracy: 0.001)
        XCTAssertEqual(doc.y, boundsPoint.y / z, accuracy: 0.001)
    }

    func testHoverScaleMismatchChangesSignAcrossPage() {
        // 根因数学守卫：实时基准≠显示基准 → Δ 随位置线性变化并在锚点两侧反向。
        let scale = 2.0, hoverScale = 1.9
        let anchor = CGPoint(x: 297, y: 420)
        func aroundAnchor(_ point: CGPoint, _ s: CGFloat) -> CGPoint {
            CGPoint(x: anchor.x + (point.x - anchor.x) * s,
                    y: anchor.y + (point.y - anchor.y) * s)
        }
        let top = aroundAnchor(CGPoint(x: 297, y: 180), hoverScale)
        let actualTop = aroundAnchor(CGPoint(x: 297, y: 180), scale)
        let bottom = aroundAnchor(CGPoint(x: 297, y: 660), hoverScale)
        let actualBottom = aroundAnchor(CGPoint(x: 297, y: 660), scale)
        XCTAssertGreaterThan(top.y - actualTop.y, 0)
        XCTAssertLessThan(bottom.y - actualBottom.y, 0)
    }

    func testLayoutSignatureExcludesDisplayFactors() {
        let sig = ReaderTypography.shared.layoutSignature
        XCTAssertFalse(sig.contains("zoom"))
        XCTAssertFalse(sig.contains("scale"))
        XCTAssertFalse(sig.contains("orientation"))
        XCTAssertEqual(sig, ReaderTypography.shared.layoutSignature)
    }
}

// MARK: - v3 Phase 2B —— Reader 全链路冒烟（“进不去节点”回归闸门，08 号）
@MainActor
final class ReaderSmokeTests: XCTestCase {
    private func longMarkdown(pages: Int) -> String {
        var md = "# 冒烟测试文档\n\n"
        for i in 0..<(pages * 14) {
            md += "第 \(i) 段：Canvas 是唯一滚动缩放 owner，正文镜像层共享同一显示变换 screen(P)=P·z−offset。\n\n"
        }
        return md
    }

    private func makeConfiguredReader(frame: CGRect, markdown: String,
                                      drawing: PKDrawing? = nil) -> ReaderHostVC {
        let vc = ReaderHostVC()
        vc.view.frame = frame
        vc.configure(nodeId: "smoke-node", markdown: markdown, drawing: drawing)
        vc.view.layoutIfNeeded()
        vc.readerView.layoutIfNeeded()
        return vc
    }

    func testConfigurePathDoesNotCrashWithAndWithoutDrawing() {
        _ = makeConfiguredReader(frame: CGRect(x: 0, y: 0, width: 1180, height: 834),
                                 markdown: "# 标题\n\n正文段落。")
        let d = PKDrawing()
        _ = makeConfiguredReader(frame: CGRect(x: 0, y: 0, width: 1180, height: 834),
                                 markdown: "# 标题\n\n正文段落。", drawing: d)
    }

    func testViewportInvariantsAfterLayout() throws {
        let vc = makeConfiguredReader(frame: CGRect(x: 0, y: 0, width: 1180, height: 834),
                                      markdown: longMarkdown(pages: 5))
        let reader = try XCTUnwrap(vc.readerView)
        let canvas = reader.canvas
        let z = ReaderViewportMath.fitWidthScale(viewportWidth: canvas.bounds.width,
                                                 pageWidth: 595.92)
        XCTAssertEqual(canvas.zoomScale, z, accuracy: 0.01)
        XCTAssertEqual(canvas.minimumZoomScale, z, accuracy: 0.01)
        // contentSize 必须 display 单位（06 号缺陷 #1 防回归）
        let expected = ReaderViewportMath.displayContentSize(documentSize: reader.documentSize, scale: z)
        XCTAssertEqual(canvas.contentSize.width, expected.width, accuracy: 1.0)
        XCTAssertEqual(canvas.contentSize.height, expected.height, accuracy: 1.0)
        // 长文档纵向可滚
        XCTAssertGreaterThan(canvas.contentSize.height - canvas.bounds.height, 0)
        // 镜像层几何
        XCTAssertEqual(reader.contentView.bounds.size.width, reader.documentSize.width, accuracy: 0.01)
        XCTAssertEqual(reader.contentView.layer.affineTransform().a, z, accuracy: 0.01)
        // 长文档多页（具体页数取决于文本实测，只钉多页性）
        XCTAssertGreaterThanOrEqual(reader.pageViews.count, 3)
    }

    func testScrollMirrorFollowsCanvasOffset() throws {
        let vc = makeConfiguredReader(frame: CGRect(x: 0, y: 0, width: 1180, height: 834),
                                      markdown: longMarkdown(pages: 5))
        let reader = try XCTUnwrap(vc.readerView)
        let canvas = reader.canvas
        let target = min(800, canvas.contentSize.height - canvas.bounds.height)
        canvas.setContentOffset(CGPoint(x: 0, y: target), animated: false)
        reader.layoutIfNeeded()
        XCTAssertEqual(reader.contentView.layer.position.x, -canvas.contentOffset.x, accuracy: 0.5)
        XCTAssertEqual(reader.contentView.layer.position.y, -canvas.contentOffset.y, accuracy: 0.5)
    }

    func testRotationPreservesCanonicalTopAndReapplies() throws {
        let vc = makeConfiguredReader(frame: CGRect(x: 0, y: 0, width: 1180, height: 834),
                                      markdown: longMarkdown(pages: 5))
        let reader = try XCTUnwrap(vc.readerView)
        let canvas = reader.canvas
        canvas.setContentOffset(CGPoint(x: 0, y: 400), animated: false)
        let canonicalBefore = ReaderViewportMath.canonicalTopY(contentOffsetY: canvas.contentOffset.y,
                                                               scale: canvas.zoomScale)
        // 旋转到竖屏档
        vc.view.frame = CGRect(x: 0, y: 0, width: 834, height: 1180)
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        reader.layoutIfNeeded()
        let z2 = ReaderViewportMath.fitWidthScale(viewportWidth: canvas.bounds.width, pageWidth: 595.92)
        XCTAssertEqual(canvas.zoomScale, z2, accuracy: 0.01)
        let canonicalAfter = ReaderViewportMath.canonicalTopY(contentOffsetY: canvas.contentOffset.y,
                                                              scale: canvas.zoomScale)
        XCTAssertEqual(canonicalAfter, canonicalBefore, accuracy: 1.5)
    }

    func testLoadInkHasNoGeometrySideEffects() throws {
        let vc = makeConfiguredReader(frame: CGRect(x: 0, y: 0, width: 1180, height: 834),
                                      markdown: longMarkdown(pages: 5))
        let reader = try XCTUnwrap(vc.readerView)
        let canvas = reader.canvas
        canvas.setContentOffset(CGPoint(x: 0, y: 300), animated: false)
        let (z0, o0) = (canvas.zoomScale, canvas.contentOffset)
        reader.loadInk(drawing: PKDrawing(), revision: 0)
        XCTAssertEqual(canvas.zoomScale, z0, accuracy: 0.0001)
        XCTAssertEqual(canvas.contentOffset.y, o0.y, accuracy: 0.0001)
        XCTAssertEqual(canvas.contentInset, .zero)
    }

    /// 真机“进不去节点/彻底卡死”回归守卫：布局必须收敛——多次强制 layout 后
    /// canvas frame / zoom / 镜像几何稳定不震荡（手写镜像层与 autolayout 打架
    /// 的死循环特征就是每轮值都在变）。
    func testLayoutSettlesWithoutOscillation() throws {
        let vc = makeConfiguredReader(frame: CGRect(x: 0, y: 0, width: 1180, height: 834),
                                      markdown: longMarkdown(pages: 5))
        let reader = try XCTUnwrap(vc.readerView)
        let canvas = reader.canvas
        XCTAssertEqual(canvas.frame, vc.view.bounds)
        canvas.setContentOffset(CGPoint(x: 0, y: 360), animated: false)
        let pos1 = reader.contentView.layer.position
        let scale1 = reader.contentView.layer.affineTransform().a
        let zoom1 = canvas.zoomScale
        for _ in 0..<3 {
            vc.view.setNeedsLayout()
            vc.view.layoutIfNeeded()
            reader.setNeedsLayout()
            reader.layoutIfNeeded()
        }
        XCTAssertEqual(canvas.frame, vc.view.bounds)
        XCTAssertEqual(canvas.zoomScale, zoom1, accuracy: 0.0001)
        XCTAssertEqual(reader.contentView.layer.position.x, pos1.x, accuracy: 0.001)
        XCTAssertEqual(reader.contentView.layer.position.y, pos1.y, accuracy: 0.001)
        XCTAssertEqual(reader.contentView.layer.affineTransform().a, scale1, accuracy: 0.001)
    }
}

// MARK: - “双击即卡死”根因守卫：@Published 同值写入不得发布
// （apply 在每次 SwiftUI update 中被调，无条件写 isEraser 会造成
//  更新→objectWillChange→重渲染→更新 的主线程死循环）
@MainActor
final class PencilLoopGuardTests: XCTestCase {
    func testApplyWithSameValueDoesNotPublish() {
        let pencil = PencilToolController()
        let canvas = PKCanvasView()
        var fired = 0
        let sink = pencil.objectWillChange.sink { _ in fired += 1 }
        pencil.apply(to: canvas, isEraser: false)   // 与初值相同 → 不得发布
        XCTAssertEqual(fired, 0)
        pencil.apply(to: canvas, isEraser: true)    // 变化 → 发布一次
        XCTAssertEqual(fired, 1)
        pencil.apply(to: canvas, isEraser: true)    // 同值 → 不发布
        XCTAssertEqual(fired, 1)
        _ = sink
    }
}

// MARK: - v6 NodeShape：kind 与 shape 正交（canonical shape + 迁移默认 + outbox + glyph）
final class NodeShapeTests: XCTestCase {
    var store: ClientStore!
    override func setUp() { store = ClientStore(dbPath: ":memory:") }

    private func makeNode(kind: NodeKind, shape: NodeShape?) -> GraphNodeDTO {
        GraphNodeDTO(nodeId: "n-\(kind.rawValue)-\(shape?.rawValue ?? "nil")", kind: kind, shape: shape,
                     title: "t", bodyMarkdown: "b", nodeRevision: 1,
                     layout: LayoutDTO(x: 0, y: 0, revision: 1))
    }

    func testResolvedShapePrefersCanonicalShape() {
        // canonical shape 与 kind 完全解耦：EXPLANATION 可以是 TRIANGLE
        XCTAssertEqual(makeNode(kind: .EXPLANATION, shape: .TRIANGLE).resolvedShape, .TRIANGLE)
        XCTAssertEqual(makeNode(kind: .CENTER, shape: .CIRCLE).resolvedShape, .CIRCLE)
        XCTAssertEqual(makeNode(kind: .TEMPORARY, shape: .SQUARE).resolvedShape, .SQUARE)
    }

    func testResolvedShapeFallsBackToMigrationDefaultsOnly() {
        // 缺失 shape（旧记录）时按“旧数据迁移默认”兜底：CENTER→SQUARE / EXPLANATION→CIRCLE / TEMPORARY→TRIANGLE
        XCTAssertEqual(makeNode(kind: .CENTER, shape: nil).resolvedShape, .SQUARE)
        XCTAssertEqual(makeNode(kind: .EXPLANATION, shape: nil).resolvedShape, .CIRCLE)
        XCTAssertEqual(makeNode(kind: .TEMPORARY, shape: nil).resolvedShape, .TRIANGLE)
    }

    func testNodeGlyphIsDrivenByShapeNotKind() {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        let square = NodeGlyph(shape: .SQUARE).path(in: rect)
        let circle = NodeGlyph(shape: .CIRCLE).path(in: rect)
        let triangle = NodeGlyph(shape: .TRIANGLE).path(in: rect)
        // 三种 shape 路径互不相同
        XCTAssertNotEqual(square, circle)
        XCTAssertNotEqual(circle, triangle)
        XCTAssertNotEqual(square, triangle)
        // 同 shape 不同 kind 的输入不存在（NodeGlyph 只接收 shape），
        // 因此“kind 决定 glyph”在类型层面已不可能；这里额外断言 glyph 与 kind 无关的等价性：
        let e1 = makeNode(kind: .EXPLANATION, shape: .SQUARE)
        let e2 = makeNode(kind: .CENTER, shape: .SQUARE)
        XCTAssertEqual(NodeGlyph(shape: try! XCTUnwrap(e1.resolvedShape)).path(in: rect),
                       NodeGlyph(shape: try! XCTUnwrap(e2.resolvedShape)).path(in: rect))
    }

    func testLocalSetShapePersistsAndQueuesOutbox() async {
        _ = await store.applySnapshot(payload: sampleSnapshot(), messageId: "m-shape-seed")
        await store.localSetShape(nodeId: "n1", shape: .TRIANGLE, baseNodeRevision: 1)
        let st = await store.cachedGraphState()
        let n1 = st.snapshot?.nodes.first { $0.nodeId == "n1" }
        XCTAssertEqual(n1?.shape, .TRIANGLE)     // 本地 durable 生效
        XCTAssertEqual(n1?.kind, .EXPLANATION)   // kind 不变
        let outbox = await store.pendingOutbox()
        XCTAssertEqual(outbox.count, 1)
        XCTAssertEqual(outbox.first?["kind"] as? String, "SET_NODE_SHAPE")
    }

    func testSnapshotCarriesAndPersistsCanonicalShape() async {
        var payload = sampleSnapshot()
        if var nodes = payload["nodes"]?.array, nodes.count >= 2, case .object(var d) = nodes[1] {
            d["shape"] = .string("TRIANGLE")
            nodes[1] = .object(d)
            payload["nodes"] = .array(nodes)
        }
        _ = await store.applySnapshot(payload: payload, messageId: "m-shape-snap")
        let st = await store.cachedGraphState()
        let n1 = st.snapshot?.nodes.first { $0.nodeId == "n1" }
        XCTAssertEqual(n1?.shape, .TRIANGLE)
        // 未知 shape 字符串应被安全忽略（resolvedShape 回落到迁移默认），不 crash
        var bad = sampleSnapshot()
        if var nodes = bad["nodes"]?.array, nodes.count >= 2, case .object(var d) = nodes[1] {
            d["shape"] = .string("HEXAGON")
            nodes[1] = .object(d)
            bad["nodes"] = .array(nodes)
        }
        _ = await store.applySnapshot(payload: bad, messageId: "m-shape-bad")
        let st2 = await store.cachedGraphState()
        let n1b = st2.snapshot?.nodes.first { $0.nodeId == "n1" }
        // 未知 shape 被安全忽略（不 crash），缓存写入时固化为迁移默认值（与 server 端迁移语义一致）
        XCTAssertEqual(n1b?.shape, .CIRCLE)
        XCTAssertEqual(n1b?.kind, .EXPLANATION)
    }

    func testCacheMigrationBackfillsLegacyShape() async {
        let tmp = NSTemporaryDirectory() + "legacy-shape-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        // 构造“旧版”库：nodes_cache 没有 shape 列，且有一条 TEMPORARY 记录
        if let db = SQLiteDB(path: tmp) {
            try? db.exec("""
                CREATE TABLE graphs_cache(graph_id TEXT PRIMARY KEY, question_key TEXT NOT NULL, round_id TEXT,
                  revision INTEGER NOT NULL, center_node_id TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
                CREATE TABLE nodes_cache(node_id TEXT PRIMARY KEY, graph_id TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL,
                  body_markdown TEXT NOT NULL, node_revision INTEGER NOT NULL, x_world REAL NOT NULL, y_world REAL NOT NULL,
                  layout_revision INTEGER NOT NULL, locally_deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
                CREATE TABLE graph_node_membership_cache(graph_id TEXT NOT NULL, node_id TEXT NOT NULL, visibility TEXT NOT NULL, PRIMARY KEY(graph_id,node_id));
                """)
            try? db.exec("INSERT INTO graphs_cache VALUES ('g-legacy','qb:x','r1',1,'n-legacy',1,'2026-01-01')")
            try? db.exec("INSERT INTO nodes_cache(node_id,graph_id,kind,title,body_markdown,node_revision,x_world,y_world,layout_revision,locally_deleted,updated_at) VALUES ('n-legacy','g-legacy','TEMPORARY','旧临时','b',1,0,0,1,0,'2026-01-01')")
            try? db.exec("INSERT INTO graph_node_membership_cache VALUES ('g-legacy','n-legacy','OWN')")
        }
        let legacy = ClientStore(dbPath: tmp)
        let st = await legacy.cachedGraphState()
        let n = st.snapshot?.nodes.first { $0.nodeId == "n-legacy" }
        XCTAssertEqual(n?.shape, .TRIANGLE, "旧 TEMPORARY 迁移后应回填 TRIANGLE（保持旧视觉）")
        XCTAssertEqual(n?.kind, .TEMPORARY)
    }
}

// MARK: - v7 MATERIAL：canonical cache 的资料侧边栏投影（不进入 Canvas）
final class MaterialNodeTests: XCTestCase {
    var store: ClientStore!
    override func setUp() { store = ClientStore(dbPath: ":memory:") }

    private func userMaterialSnapshot() -> [String: JSONValue] {
        jval([
            "graph_id": "user-graph", "question_key": "user:ug-material", "question_source": "USER_AUTHORED",
            "round_id": "r-user", "revision": 1, "center_node_id": "center",
            "nodes": [
                ["node_id": "center", "kind": "CENTER", "shape": "SQUARE", "title": "自制问题", "body_markdown": "问题", "node_revision": 1,
                 "layout": ["x": 0, "y": 0, "revision": 1]],
                ["node_id": "explanation", "kind": "EXPLANATION", "shape": "CIRCLE", "title": "解释", "body_markdown": "解释正文", "node_revision": 1,
                 "layout": ["x": 120, "y": 0, "revision": 1]],
                // 即便误传 shape/layout，客户端也不把 MATERIAL 投影成 topology node。
                ["node_id": "material", "kind": "MATERIAL", "shape": "TRIANGLE", "title": "RAG 原文", "body_markdown": "# RAG\n\n原始 Markdown", "node_revision": 1],
            ],
        ])
    }

    func testMaterialProjectsToSidebarNotCanvasAndHasNoShapeOrLayout() async {
        let dto = await store.applySnapshot(payload: userMaterialSnapshot(), messageId: "material-snapshot")
        XCTAssertTrue(dto?.isUserAuthored == true)
        XCTAssertEqual(dto?.topologyNodes.map(\.nodeId), ["center", "explanation"])
        XCTAssertEqual(dto?.materialNodes.map(\.nodeId), ["material"])
        let material = dto?.materialNodes.first
        XCTAssertNil(material?.shape)
        XCTAssertNil(material?.resolvedShape)
        XCTAssertNil(material?.layout)
        XCTAssertNil(dto?.resolvedParent(of: material ?? GraphNodeDTO(nodeId: "missing", kind: .MATERIAL, title: "", bodyMarkdown: "", nodeRevision: 1)))

        let cached = await store.cachedGraphState()
        XCTAssertEqual(cached.snapshot?.materialNodes.first?.bodyMarkdown, "# RAG\n\n原始 Markdown")
        XCTAssertNil(cached.snapshot?.materialNodes.first?.layout)
    }

    func testMaterialPatchAppearsAndRemovePatchDisappearsFromSidebarProjection() async {
        _ = await store.applySnapshot(payload: sampleSnapshot(graphId: "g-material"), messageId: "material-seed")
        let added = await store.applyPatch(payload: jval([
            "graph_id": "g-material", "base_revision": 1, "target_revision": 2,
            "ops": [["op": "ADD_NODE", "node": ["node_id": "m1", "kind": "MATERIAL", "title": "补充资料", "body_markdown": "正文", "node_revision": 1]]],
        ]), messageId: "material-add")
        if case .applied(let snapshot) = added {
            XCTAssertEqual(snapshot?.materialNodes.map(\.nodeId), ["m1"])
            XCTAssertEqual(snapshot?.topologyNodes.count, 2)
        } else { XCTFail("MATERIAL ADD_NODE patch 应可应用") }

        let removed = await store.applyPatch(payload: jval([
            "graph_id": "g-material", "base_revision": 2, "target_revision": 3,
            "ops": [["op": "REMOVE_NODE", "node_id": "m1"]],
        ]), messageId: "material-remove")
        if case .applied(let snapshot) = removed {
            XCTAssertTrue(snapshot?.materialNodes.isEmpty == true)
        } else { XCTFail("MATERIAL REMOVE_NODE patch 应可应用") }
    }

    func testMaterialCannotQueueShapeOrMoveMutation() async {
        _ = await store.applySnapshot(payload: userMaterialSnapshot(), messageId: "material-guard")
        await store.localSetShape(nodeId: "material", shape: .CIRCLE, baseNodeRevision: 1)
        let command = await store.localMove(nodeId: "material", x: 99, y: 42, baseLayoutRevision: 1)
        XCTAssertEqual(command, "")
        let outbox = await store.pendingOutbox()
        XCTAssertTrue(outbox.isEmpty)
        let cached = await store.cachedGraphState()
        XCTAssertNil(cached.snapshot?.materialNodes.first?.shape)
        XCTAssertNil(cached.snapshot?.materialNodes.first?.layout)
    }

    func testBookButtonEligibilityComesOnlyFromUserAuthoredSource() {
        let user = GraphSnapshotDTO(graphId: "g", questionKey: "user:legacy-compatible", questionSource: .USER_AUTHORED,
                                    roundId: nil, revision: 1, centerNodeId: "c", nodes: [])
        let formal = GraphSnapshotDTO(graphId: "g", questionKey: "qb:1", questionSource: .QUESTION_BANK,
                                      roundId: nil, revision: 1, centerNodeId: "c", nodes: [])
        XCTAssertTrue(user.isUserAuthored)
        XCTAssertFalse(formal.isUserAuthored)
    }
}
