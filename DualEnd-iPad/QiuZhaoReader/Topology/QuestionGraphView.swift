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
                        grabOffset = CGSize(width: center.x - value.location.x,
                                            height: center.y - value.location.y)
                        isDragging = true
                    }
                    let newCenter = CGPoint(x: value.location.x + grabOffset.width,
                                            y: value.location.y + grabOffset.height)
                    onDragChanged(geometry.normalizedPoint(from: newCenter))
                }
                .onEnded { value in
                    guard !node.isCenter else { return }
                    let newCenter = CGPoint(x: value.location.x + grabOffset.width,
                                            y: value.location.y + grabOffset.height)
                    let final = geometry.normalizedPoint(from: newCenter)
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

    private var geometry: GraphCanvasGeometry {
        GraphCanvasGeometry(viewportSize: containerSize)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let snap = state.snapshot, let center = snap.center() {
                ForEach(snap.visibleChildren(), id: \.nodeId) { child in
                    ChildLink(start: point(for: center), end: point(for: child))
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                ForEach(snap.nodes, id: \.nodeId) { node in
                    NodeShapeView(node: node,
                                  normalized: normalizedPosition(for: node),
                                  geometry: geometry,
                                  isSelected: state.selectedNodeId == node.nodeId,
                                  onTap: { onNodeTap(node.nodeId) },
                                  onDoubleTap: { onNodeDoubleTap(node.nodeId) },
                                  onDragChanged: { onNodeDragChanged(node.nodeId, $0) },
                                  onDragEnded: { onNodeDragEnded(node.nodeId, $0) })
                }
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
        // Parent gesture only clears when the touch is outside every node hit rect;
        // it never competes with the node gesture for a node touch.
        .simultaneousGesture(
            SpatialTapGesture(count: 1, coordinateSpace: .named("graph-canvas"))
                .onEnded { value in
                    if !containsNode(at: value.location) { onBackgroundTap() }
                }
        )
    }

    private func normalizedPosition(for node: GraphNodeDTO) -> CGPoint {
        state.dragTransient[node.nodeId]
            ?? state.pendingPositions[node.nodeId]
            ?? CGPoint(x: node.layout.x, y: node.layout.y)
    }

    private func point(for node: GraphNodeDTO) -> CGPoint {
        geometry.screenPoint(from: normalizedPosition(for: node))
    }

    private func containsNode(at location: CGPoint) -> Bool {
        state.snapshot?.nodes.contains {
            geometry.hitRect(at: normalizedPosition(for: $0)).contains(location)
        } ?? false
    }
}
