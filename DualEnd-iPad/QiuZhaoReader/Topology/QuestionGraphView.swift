// Topology —— SwiftUI 问题图：统一图布坐标、确定性手势和本地乐观位置。
import SwiftUI

enum TopologyLayout {
    static func slot(index: Int) -> CGPoint {
        let golden = 2.399963229728653
        let ring = Double(index / 12)
        let radius = min(0.18 + ring * 0.12, 0.42)
        let angle = golden * Double(index)
        return CGPoint(x: 0.5 + radius * cos(angle), y: 0.5 + radius * sin(angle))
    }
}

struct NodeGlyph: Shape {
    let kind: NodeKind
    func path(in rect: CGRect) -> Path {
        switch kind {
        case .CENTER: return Path(rect)
        case .EXPLANATION: return Path(ellipseIn: rect)
        case .TEMPORARY:
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
    let normalized: CGPoint
    let geometry: GraphCanvasGeometry
    let viewportOffset: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    private let glyphSize: CGFloat = 64
    private let hitSize: CGFloat = 88
    @State private var grabOffset = CGSize.zero
    @State private var isDragging = false

    var body: some View {
        let center = geometry.screenPoint(from: normalized)
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
                    }
                    let newVisualCenter = CGPoint(x: value.location.x + grabOffset.width,
                                                   y: value.location.y + grabOffset.height)
                    let graphCenter = geometry.graphPoint(fromVisual: newVisualCenter, viewportOffset: viewportOffset)
                    onDragChanged(geometry.normalizedPoint(from: graphCenter))
                }
                .onEnded { value in
                    guard !node.isCenter else { return }
                    let newVisualCenter = CGPoint(x: value.location.x + grabOffset.width,
                                                   y: value.location.y + grabOffset.height)
                    let graphCenter = geometry.graphPoint(fromVisual: newVisualCenter, viewportOffset: viewportOffset)
                    let final = geometry.normalizedPoint(from: graphCenter)
                    isDragging = false
                    grabOffset = .zero
                    onDragEnded(final)
                },
            including: .gesture
        )
        // Double tap consumes the gesture before the single tap sheet.
        .highPriorityGesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .onTapGesture { onTap() }
    }

    private var glyph: NodeGlyph { NodeGlyph(kind: node.kind) }
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
    @GestureState private var canvasDragTranslation: CGSize = .zero

    private var geometry: GraphCanvasGeometry {
        GraphCanvasGeometry(viewportSize: containerSize)
    }

    private var liveCanvasOffset: CGSize {
        let session = canvasPanSession
        let initialOffset = session?.initialViewportOffset ?? committedCanvasOffset
        let translation = session?.ownsCanvas == false ? .zero : canvasDragTranslation
        let proposed = CGSize(width: initialOffset.width + translation.width,
                              height: initialOffset.height + translation.height)
        return geometry.clampedViewportOffset(
            proposed: proposed,
            nodeCenters: session?.constraintCenters ?? viewportConstraintCenters
        )
    }

    /// Clamp 的边界不能读取 dragTransient，否则节点的逐帧拖动会反向改变 viewport。
    private var viewportConstraintCenters: [CGPoint] {
        geometry.viewportConstraintCenters(from: stableNormalizedPositions)
    }

    private var stableNormalizedPositions: [CGPoint] {
        state.snapshot?.nodes.map { stableNormalizedPosition(for: $0) } ?? []
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
                                      normalized: normalizedPosition(for: node),
                                      geometry: geometry,
                                      viewportOffset: liveCanvasOffset,
                                      isSelected: state.selectedNodeId == node.nodeId,
                                      onTap: { onNodeTap(node.nodeId) },
                                      onDoubleTap: { onNodeDoubleTap(node.nodeId) },
                                      onDragChanged: { onNodeDragChanged(node.nodeId, $0) },
                                      onDragEnded: { onNodeDragEnded(node.nodeId, $0) })
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
        }
    }

    private func normalizedPosition(for node: GraphNodeDTO) -> CGPoint {
        state.dragTransient[node.nodeId]
            ?? state.pendingPositions[node.nodeId]
            ?? CGPoint(x: node.layout.x, y: node.layout.y)
    }

    /// 仅用于 viewport 约束：pending 是本地 durable intent，dragTransient 只是当前手势帧。
    private func stableNormalizedPosition(for node: GraphNodeDTO) -> CGPoint {
        state.pendingPositions[node.nodeId]
            ?? CGPoint(x: node.layout.x, y: node.layout.y)
    }

    private func point(for node: GraphNodeDTO) -> CGPoint {
        geometry.screenPoint(from: normalizedPosition(for: node))
    }

    private func containsNode(at location: CGPoint, viewportOffset: CGSize) -> Bool {
        state.snapshot?.nodes.contains {
            geometry.visualHitRect(at: normalizedPosition(for: $0), viewportOffset: viewportOffset).contains(location)
        } ?? false
    }

    private func newCanvasPanSession(startLocation: CGPoint) -> CanvasPanSession {
        geometry.beginCanvasPanSession(
            startLocation: startLocation,
            stableNormalizedPositions: stableNormalizedPositions,
            initialViewportOffset: committedCanvasOffset
        )
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
                let proposed = CGSize(width: session.initialViewportOffset.width + value.translation.width,
                                      height: session.initialViewportOffset.height + value.translation.height)
                committedCanvasOffset = geometry.clampedViewportOffset(proposed: proposed,
                                                                        nodeCenters: session.constraintCenters)
            }
    }
}
