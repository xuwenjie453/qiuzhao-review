// Topology —— SwiftUI 问题图：CENTER 正方 / EXPLANATION 圆 / TEMPORARY 三角；
// 标题于节点上方(最多2行); 子节点到 CENTER 低强调连线(星型, 不可编辑);
// 手势优先级 double tap > single tap; long-press/drag 不触发 single; 拖动本地优先。
import SwiftUI

enum TopologyLayout {
    static func slot(index: Int) -> CGPoint {
        let golden = 2.399963229728653
        let ring = Double(index / 12)
        let radius = min(0.18 + ring * 0.12, 0.42)
        let a = golden * Double(index)
        return CGPoint(x: 0.5 + radius * cos(a), y: 0.5 + radius * sin(a))
    }
}

struct NodeGlyph: Shape {
    let kind: NodeKind
    func path(in rect: CGRect) -> Path {
        switch kind {
        case .CENTER:
            return Path(rect)
        case .EXPLANATION:
            return Path(ellipseIn: rect)
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

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 低强调度连线（无业务编辑能力）
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
    /// 归一化中心位置 (0..1)
    let normalized: CGPoint
    let containerSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    private let size: CGFloat = 64

    var body: some View {
        let center = CGPoint(x: normalized.x * containerSize.width,
                             y: normalized.y * containerSize.height)
        return ZStack {
            glyph
                .fill(fillColor)
                .overlay(glyph.stroke(Color.black, lineWidth: isSelected ? 3 : 1.5))
            // 标题于节点上方
            Text(node.title)
                .font(.caption2.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 150)
                .offset(y: -size / 2 - 16)
        }
        .frame(width: size, height: size)
        .position(center)
        .contentShape(glyph)
        .gesture(
            // long press 进入拖动(不触发 single)
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    guard !node.isCenter else { return }
                    onDragChanged(normalizedDelta(v))
                }
                .onEnded { v in
                    guard !node.isCenter else { return }
                    onDragEnded(normalizedDelta(v))
                },
            including: .gesture
        )
        .gesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .gesture(TapGesture(count: 1).onEnded { onTap() })
    }

    private func normalizedDelta(_ v: DragGesture.Value) -> CGPoint {
        let x = (normalized.x * containerSize.width + v.translation.width) / containerSize.width
        let y = (normalized.y * containerSize.height + v.translation.height) / containerSize.height
        return CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
    }

    private var glyph: NodeGlyph { NodeGlyph(kind: node.kind) }
    private var fillColor: Color {
        switch node.kind {
        case .CENTER: Color.blue.opacity(0.22)
        case .EXPLANATION: Color.green.opacity(0.18)
        case .TEMPORARY: Color.orange.opacity(0.18)
        }
    }
}

struct QuestionGraphView: View {
    let state: QuestionGraphState
    let containerSize: CGSize
    let onNodeTap: (String) -> Void
    let onNodeDoubleTap: (String) -> Void
    let onNodeDragChanged: (String, CGPoint) -> Void
    let onNodeDragEnded: (String, CGPoint) -> Void

    var body: some View {
        ZStack {
            if let snap = state.snapshot, let center = snap.center() {
                ForEach(snap.visibleChildren(), id: \.nodeId) { child in
                    ChildLink(
                        start: CGPoint(x: CGFloat(center.layout.x) * containerSize.width,
                                       y: CGFloat(center.layout.y) * containerSize.height),
                        end: CGPoint(x: CGFloat(child.layout.x) * containerSize.width,
                                     y: CGFloat(child.layout.y) * containerSize.height)
                    )
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
                ForEach(snap.nodes, id: \.nodeId) { node in
                    NodeShapeView(node: node, normalized: CGPoint(x: node.layout.x, y: node.layout.y),
                                  containerSize: containerSize,
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
                    Text("暂无问题图")
                        .font(.headline)
                    Text("在 Mac 上开始讨论题目后，问题与解释会自动出现在这里；离线也可查看已缓存内容。")
                        .font(.footnote).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }
}
