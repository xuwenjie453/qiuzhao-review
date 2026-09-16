// Topology —— SwiftUI 问题图：WORLD_V1 坐标、无限本地相机和确定性手势。
import Foundation
import SwiftUI

enum TopologyLayout {
    /// 与 Mac 的 worldRadialSlot 保持同一确定性初始排布，用于逻辑测试和未来本地预览。
    static func slot(index: Int) -> CGPoint {
        let golden = 2.399963229728653
        let ring = Double(index / 12)
        let radius = 180 + ring * 135
        let angle = golden * Double(index)
        return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
    }
}

/// 节点视觉形状 —— 只由 canonical `shape` 驱动（v4/v6 起 kind 与 shape 正交）。
/// 本类型不得 switch/import NodeKind。
struct NodeGlyph: Shape {
    let shape: NodeShape
    func path(in rect: CGRect) -> Path {
        switch shape {
        case .SQUARE: return Path(rect)
        case .CIRCLE: return Path(ellipseIn: rect)
        case .TRIANGLE:
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
}

struct ChildLink: Shape {
    let start: CGPoint
    let end: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        return p
    }
}

struct NodeShapeView: View {
    let node: GraphNodeDTO
    let world: CGPoint
    let geometry: GraphCanvasGeometry
    let viewportOffset: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onDragBegan: () -> Void
    /// visualCenter 和 touch 由父图层换算为 canonical world point，保证边缘自动平移后不抖动。
    let onDragChanged: (CGPoint, CGPoint, Date) -> Void
    let onDragEnded: (CGPoint, CGPoint, Date) -> Void

    private let glyphSize: CGFloat = 64
    private let hitSize: CGFloat = 88
    @State private var grabOffset = CGSize.zero
    @State private var isDragging = false

    var body: some View {
        let center = geometry.screenPoint(from: world)
        let visualCenter = geometry.visualPoint(from: center, viewportOffset: viewportOffset)
        return ZStack {
            glyph
                .fill(fillColor)
                .overlay(glyph.stroke(Color.black, lineWidth: isSelected ? 3 : 1.5))
                .frame(width: glyphSize, height: glyphSize)

            Text(node.title)
                .font(.caption.weight(.medium))
                .lineLimit(5)
                .multilineTextAlignment(.center)
                .frame(width: 170)
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: -(glyphSize / 2 + 24))
                .allowsHitTesting(false)
            if node.visibility == .INHERITED {
                Image(systemName: "link").font(.caption2).foregroundColor(.blue)
                    .padding(4).background(.thinMaterial, in: Circle())
                    .offset(x: glyphSize / 2 - 4, y: glyphSize / 2 - 4)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: hitSize, height: hitSize)
        .contentShape(Rectangle())
        .position(center)
        .scaleEffect(isDragging ? 1.06 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.22 : 0.08),
                radius: isDragging ? 9 : 3,
                y: isDragging ? 5 : 2)
        .animation(.spring(response: 0.18, dampingFraction: 0.84), value: isDragging)
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named("graph-canvas"))
                .onChanged { value in
                    guard !node.isCenter else { return }
                    if !isDragging {
                        // 保留按下点相对节点中心的偏移，避免节点吸附到触点。
                        grabOffset = CGSize(width: visualCenter.x - value.location.x,
                                            height: visualCenter.y - value.location.y)
                        isDragging = true
                        onDragBegan()
                    }
                    let newVisualCenter = CGPoint(x: value.location.x + grabOffset.width,
                                                   y: value.location.y + grabOffset.height)
                    onDragChanged(newVisualCenter, value.location, value.time)
                }
                .onEnded { value in
                    guard !node.isCenter else { return }
                    let newVisualCenter = CGPoint(x: value.location.x + grabOffset.width,
                                                   y: value.location.y + grabOffset.height)
                    onDragEnded(newVisualCenter, value.location, value.time)
                    isDragging = false
                    grabOffset = .zero
                },
            including: .gesture
        )
        // Double tap consumes the gesture before the single tap sheet.
        .highPriorityGesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .onTapGesture { onTap() }
    }

    // 渲染只读 canonical shape（缺失时由 resolvedShape 做迁移默认兜底）。
    private var glyph: NodeGlyph { NodeGlyph(shape: node.resolvedShape) }
    private var fillColor: Color {
        switch node.kind {
        case .CENTER: return .blue.opacity(0.22)
        case .EXPLANATION: return .green.opacity(0.18)
        case .TEMPORARY: return .orange.opacity(0.18)
        }
    }
}

struct QuestionGraphView: View {
    let state: QuestionGraphState
    let containerSize: CGSize
    let onNodeTap: (String) -> Void
    let onNodeDoubleTap: (String) -> Void
    let onBackgroundTap: () -> Void
    let onNodeDragChanged: (String, CGPoint) -> Void
    let onNodeDragEnded: (String, CGPoint) -> Void
    @State private var committedCanvasOffset: CGSize = .zero
    @State private var canvasPanSession: CanvasPanSession?
    @State private var nodeAutoPanLastTime: Date?
    @GestureState private var canvasDragTranslation: CGSize = .zero

    private var geometry: GraphCanvasGeometry {
        GraphCanvasGeometry(viewportSize: containerSize)
    }

    private var liveCanvasOffset: CGSize {
        let session = canvasPanSession
        // 节点触摸会建立一个 ownsCanvas=false 的父手势会话。节点边缘自动平移
        // 必须仍读取最新 committed offset，不能被该 non-owner session 冻住。
        let initialOffset: CGSize
        let translation: CGSize
        if let session, session.ownsCanvas {
            initialOffset = session.initialViewportOffset
            translation = canvasDragTranslation
        } else {
            initialOffset = committedCanvasOffset
            translation = .zero
        }
        return CGSize(width: initialOffset.width + translation.width,
                      height: initialOffset.height + translation.height)
    }

    private var stableWorldPositions: [CGPoint] {
        state.snapshot?.nodes.map { stableWorldPosition(for: $0) } ?? []
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let snap = state.snapshot, snap.center() != nil {
                ZStack(alignment: .topLeading) {
                    ForEach(snap.visibleChildren(), id: \.nodeId) { child in
                        if let parent = snap.resolvedParent(of: child) {
                            ChildLink(start: point(for: parent), end: point(for: child))
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                    }
                    ForEach(snap.nodes, id: \.nodeId) { node in
                        NodeShapeView(node: node,
                                      world: worldPosition(for: node),
                                      geometry: geometry,
                                      viewportOffset: liveCanvasOffset,
                                      isSelected: state.selectedNodeId == node.nodeId,
                                      onTap: { onNodeTap(node.nodeId) },
                                      onDoubleTap: { onNodeDoubleTap(node.nodeId) },
                                      onDragBegan: beginNodeDrag,
                                      onDragChanged: { visualCenter, location, time in
                                          updateNodeDrag(node.nodeId, visualCenter: visualCenter, location: location, time: time)
                                      },
                                      onDragEnded: { visualCenter, location, time in
                                          endNodeDrag(node.nodeId, visualCenter: visualCenter, location: location, time: time)
                                      })
                    }
                }
                .offset(liveCanvasOffset)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.largeTitle).foregroundColor(.secondary)
                    Text("暂无问题图").font(.headline)
                    Text("在 Mac 上开始讨论题目后，问题与解释会自动出现在这里；离线也可查看已缓存内容。")
                        .font(.footnote).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .coordinateSpace(name: "graph-canvas")
        .simultaneousGesture(canvasPanGesture)
        // Parent gesture only clears when the touch is outside every node hit rect;
        // it never competes with the node gesture for a node touch.
        .simultaneousGesture(
            SpatialTapGesture(count: 1, coordinateSpace: .named("graph-canvas"))
                .onEnded { value in
                    if !containsNode(at: value.location, viewportOffset: liveCanvasOffset) { onBackgroundTap() }
                }
        )
        .onChange(of: state.snapshot?.graphId) { _, _ in
            committedCanvasOffset = .zero
            canvasPanSession = nil
            nodeAutoPanLastTime = nil
        }
    }

    private func worldPosition(for node: GraphNodeDTO) -> CGPoint {
        state.dragTransient[node.nodeId]
            ?? state.pendingPositions[node.nodeId]
            ?? CGPoint(x: node.layout.x, y: node.layout.y)
    }

    /// pending 是本地 durable intent，dragTransient 只是当前手势帧。
    private func stableWorldPosition(for node: GraphNodeDTO) -> CGPoint {
        state.pendingPositions[node.nodeId]
            ?? CGPoint(x: node.layout.x, y: node.layout.y)
    }

    private func point(for node: GraphNodeDTO) -> CGPoint {
        geometry.screenPoint(from: worldPosition(for: node))
    }

    private func containsNode(at location: CGPoint, viewportOffset: CGSize) -> Bool {
        state.snapshot?.nodes.contains {
            geometry.visualHitRect(at: worldPosition(for: $0), viewportOffset: viewportOffset).contains(location)
        } ?? false
    }

    private func newCanvasPanSession(startLocation: CGPoint) -> CanvasPanSession {
        geometry.beginCanvasPanSession(
            startLocation: startLocation,
            stableWorldPositions: stableWorldPositions,
            initialViewportOffset: committedCanvasOffset
        )
    }

    private func beginNodeDrag() {
        nodeAutoPanLastTime = nil
    }

    private func viewportOffsetForNodeDrag(location: CGPoint, time: Date) -> CGSize {
        let elapsed = nodeAutoPanLastTime.map { time.timeIntervalSince($0) } ?? 0
        nodeAutoPanLastTime = time
        let delta = geometry.edgeAutoPanDelta(at: location, elapsed: elapsed)
        committedCanvasOffset = CGSize(width: committedCanvasOffset.width + delta.width,
                                       height: committedCanvasOffset.height + delta.height)
        return committedCanvasOffset
    }

    private func updateNodeDrag(_ nodeId: String, visualCenter: CGPoint, location: CGPoint, time: Date) {
        let offset = viewportOffsetForNodeDrag(location: location, time: time)
        let graphPoint = geometry.graphPoint(fromVisual: visualCenter, viewportOffset: offset)
        onNodeDragChanged(nodeId, geometry.worldPoint(from: graphPoint))
    }

    private func endNodeDrag(_ nodeId: String, visualCenter: CGPoint, location: CGPoint, time: Date) {
        let offset = viewportOffsetForNodeDrag(location: location, time: time)
        nodeAutoPanLastTime = nil
        let graphPoint = geometry.graphPoint(fromVisual: visualCenter, viewportOffset: offset)
        onNodeDragEnded(nodeId, geometry.worldPoint(from: graphPoint))
    }

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("graph-canvas"))
            .updating($canvasDragTranslation) { value, translation, _ in
                // 新手势在 onChanged 固化 session 前，仍只用 stable layout 判定；
                // 绝不能用 dragTransient 让 node drag 中途切换为 Canvas Pan。
                let session = canvasPanSession ?? newCanvasPanSession(startLocation: value.startLocation)
                guard session.ownsCanvas else {
                    translation = .zero
                    return
                }
                translation = value.translation
            }
            .onChanged { value in
                if canvasPanSession == nil {
                    canvasPanSession = newCanvasPanSession(startLocation: value.startLocation)
                }
            }
            .onEnded { value in
                let session = canvasPanSession ?? newCanvasPanSession(startLocation: value.startLocation)
                canvasPanSession = nil
                guard session.ownsCanvas else { return }
                committedCanvasOffset = CGSize(width: session.initialViewportOffset.width + value.translation.width,
                                               height: session.initialViewportOffset.height + value.translation.height)
            }
    }
}
