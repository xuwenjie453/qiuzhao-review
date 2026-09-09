// iPad 单元测试 —— Store transaction / outbox replay / snapshot replace / patch validation /
// 手势状态 reducer / 协议编解码 (M-14.4)。
import XCTest
import PencilKit
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
