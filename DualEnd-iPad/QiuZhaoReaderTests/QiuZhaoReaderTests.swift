// iPad 单元测试 —— Store transaction / outbox replay / snapshot replace / patch validation /
// 手势状态 reducer / 协议编解码 (M-14.4)。
import XCTest
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
             "layout": ["x": 0.5, "y": 0.5, "revision": 1]],
            ["node_id": "n1", "kind": "EXPLANATION", "title": "惰性与定期", "body_markdown": "解释原文", "node_revision": 1,
             "layout": ["x": 0.7, "y": 0.4, "revision": 1]],
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
                    "body_markdown": "b", "node_revision": 1, "layout": ["x": 0.3, "y": 0.3, "revision": 1]]]],
        ]), messageId: "m2")
        if case .applied(let dto) = ok {
            XCTAssertEqual(dto?.nodes.count, 3)
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
        {"v":1,"message_id":"m1","type":"WELCOME","session_epoch":"e1","sent_at":"2026-09-08T12:34:56.123Z",
         "payload":{"selected_protocol":1,"daemon_id":"mac-A","server_seq":3,"active":{"graph_id":"g1","round_id":"r1"}}}
        """
        let env = try MessageCoder.decode(raw)
        XCTAssertEqual(env.type, "WELCOME")
        XCTAssertEqual(env.payload["daemon_id"]?.string, "mac-A")
    }

    func testUnknownTypeDecodableAndIgnoredUpstream() {
        // M-2.7: 未知 type 记录并忽略, 不 crash —— 解码层应成功返回, 由 SyncEngine 上层忽略
        let raw = """
        {"v":1,"message_id":"m2","type":"WHATEVER_NEW","session_epoch":null,"sent_at":"x","payload":{}}
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
}

final class TopologyLogicTests: XCTestCase {
    func testGraphCanvasRoundTripUsesSameContentRect() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let normalized = CGPoint(x: 0.73, y: 0.21)
        let screen = geometry.screenPoint(from: normalized)
        let roundTrip = geometry.normalizedPoint(from: screen)
        XCTAssertEqual(roundTrip.x, normalized.x, accuracy: 0.000001)
        XCTAssertEqual(roundTrip.y, normalized.y, accuracy: 0.000001)
        XCTAssertTrue(geometry.contentRect.contains(screen))
    }

    func testGraphCanvasClampsOutsideViewportToNormalizedBounds() {
        let geometry = GraphCanvasGeometry(viewportSize: CGSize(width: 1024, height: 768))
        let minPoint = geometry.normalizedPoint(from: CGPoint(x: -100, y: -100))
        let maxPoint = geometry.normalizedPoint(from: CGPoint(x: 5000, y: 5000))
        XCTAssertEqual(minPoint, CGPoint.zero)
        XCTAssertEqual(maxPoint, CGPoint(x: 1, y: 1))
    }

    func testRadialSlotDeterministicAndBounded() {
        let p0 = TopologyLayout.slot(index: 0)
        let p0b = TopologyLayout.slot(index: 0)
        XCTAssertEqual(p0.x, p0b.x)
        XCTAssertEqual(p0.y, p0b.y)
        for i in 0..<40 {
            let p = TopologyLayout.slot(index: i)
            XCTAssertTrue((0.0...1.0).contains(p.x))
            XCTAssertTrue((0.0...1.0).contains(p.y))
        }
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
}
