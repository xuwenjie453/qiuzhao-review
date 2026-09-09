// Topology —— SwiftUI 问题图：CENTER 正方 / EXPLANATION 圆 / TEMPORARY 三角；
// 标题于节点上方(最多5行); 子节点到 CENTER 低强调连线(星型, 不可编辑);
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
    @State private var dragOrigin: CGPoint?
    @State private var isDragging = false

    var body: some View {
        let center = CGPoint(x: normalized.x * containerSize.width,
                             y: normalized.y * containerSize.height)
        return glyph
            .fill(fillColor)
            .overlay(glyph.stroke(Color.black, lineWidth: isSelected ? 3 : 1.5))
            .frame(width: size, height: size)
            // 标题只做 overlay，不参与节点本体的 layout/hit-test 计算。
            .overlay {
            Text(node.title)
                .font(.caption.weight(.medium))
                .lineLimit(5)
                .multilineTextAlignment(.center)
                // ZStack 外层固定为节点大小；这里必须显式给标题宽度，
                // 否则 Text 会继承 64pt 的父布局，只能显示一排几个字。
                .frame(width: 160)
                .fixedSize(horizontal: false, vertical: true)
                    // 以节点中心为基准向上放置，标题行数变化时仍不会压住图形。
                    .offset(y: -(size / 2 + 24))
                    .allowsHitTesting(false)
            }
        // QuestionGraphView 使用 topLeading 坐标容器；offset 的原点与命中
        // 矩形完全一致，避免 position + 父级对齐造成视觉/触摸偏移。
        .offset(x: center.x - size / 2, y: center.y - size / 2)
        .contentShape(Rectangle())
        .scaleEffect(isDragging ? 1.08 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.22 : 0.08),
                radius: isDragging ? 10 : 3,
                y: isDragging ? 6 : 2)
        .animation(.spring(response: 0.18, dampingFraction: 0.82), value: isDragging)
        .gesture(
            // 固定手势开始时的 origin；translation 始终相对该 origin 计算，
            // 防止瞬时渲染位置再次叠加累计 translation 而四处飘移。
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    guard !node.isCenter else { return }
                    if dragOrigin == nil {
                        dragOrigin = normalized
                        isDragging = true
                    }
                    onDragChanged(normalizedDelta(v, origin: dragOrigin ?? normalized))
                }
                .onEnded { v in
                    guard !node.isCenter else { return }
                    let final = normalizedDelta(v, origin: dragOrigin ?? normalized)
                    dragOrigin = nil
                    isDragging = false
                    onDragEnded(final)
                },
            including: .gesture
        )
        // 双击置于高优先级，避免一次双击同时触发单击 sheet。
        .highPriorityGesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .onTapGesture { onTap() }
    }

    private func normalizedDelta(_ v: DragGesture.Value, origin: CGPoint) -> CGPoint {
        let x = (origin.x * containerSize.width + v.translation.width) / containerSize.width
        let y = (origin.y * containerSize.height + v.translation.height) / containerSize.height
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
    let onBackgroundTap: () -> Void
    let onNodeDragChanged: (String, CGPoint) -> Void
    let onNodeDragEnded: (String, CGPoint) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let snap = state.snapshot, let center = snap.center() {
                ForEach(snap.visibleChildren(), id: \.nodeId) { child in
                    ChildLink(
                        start: point(for: center),
                        end: point(for: child)
                    )
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .allowsHitTesting(false)
                }
                ForEach(snap.nodes, id: \.nodeId) { node in
                    NodeShapeView(node: node, normalized: normalizedPosition(for: node),
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        // 背景手势放在父容器上，并与子节点手势并行识别。此前把一个带
        // onTapGesture 的 Color.clear 放在 ZStack 中，会在部分 iPadOS
        // 命中测试场景吞掉节点的点击/双击。通过点击坐标判断是否落在节点
        // 矩形内，只对真正的空白区域清焦点，不参与节点命中竞争。
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                if !containsNode(at: value.location) {
                    onBackgroundTap()
                }
            }
        )
    }

    private func normalizedPosition(for node: GraphNodeDTO) -> CGPoint {
        state.dragTransient[node.nodeId]
            ?? CGPoint(x: node.layout.x, y: node.layout.y)
    }

    private func point(for node: GraphNodeDTO) -> CGPoint {
        let p = normalizedPosition(for: node)
        return CGPoint(x: CGFloat(p.x) * containerSize.width,
                       y: CGFloat(p.y) * containerSize.height)
    }

    private func containsNode(at location: CGPoint) -> Bool {
        let half: CGFloat = 32
        return state.snapshot?.nodes.contains { node in
            let p = point(for: node)
            return abs(location.x - p.x) <= half && abs(location.y - p.y) <= half
        } ?? false
    }
}
