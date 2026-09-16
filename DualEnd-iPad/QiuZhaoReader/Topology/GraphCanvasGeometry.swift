// GraphCanvasGeometry —— QuestionGraph 唯一的 normalized/local 几何转换来源。
import CoreGraphics

struct GraphCanvasGeometry: Equatable {
    let viewportSize: CGSize
    let contentRect: CGRect

    init(viewportSize: CGSize) {
        self.viewportSize = viewportSize
        let horizontal = min(56, max(28, viewportSize.width * 0.06))
        let top = min(96, max(72, viewportSize.height * 0.10))
        let bottom = min(56, max(28, viewportSize.height * 0.06))
        let width = max(1, viewportSize.width - horizontal * 2)
        let height = max(1, viewportSize.height - top - bottom)
        self.contentRect = CGRect(x: horizontal, y: top, width: width, height: height)
    }

    func screenPoint(from normalized: CGPoint) -> CGPoint {
        CGPoint(x: contentRect.minX + clamp(normalized.x) * contentRect.width,
                y: contentRect.minY + clamp(normalized.y) * contentRect.height)
    }

    func normalizedPoint(from screen: CGPoint) -> CGPoint {
        CGPoint(x: clamp((screen.x - contentRect.minX) / contentRect.width),
                y: clamp((screen.y - contentRect.minY) / contentRect.height))
    }

    func visualRect(at normalized: CGPoint, size: CGFloat = 64) -> CGRect {
        let p = screenPoint(from: normalized)
        return CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
    }

    func hitRect(at normalized: CGPoint, size: CGFloat = 88) -> CGRect {
        let p = screenPoint(from: normalized)
        return CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
    }

    /// viewport offset 只属于本地呈现层；canonical graph point 始终不含它。
    func visualPoint(from graphPoint: CGPoint, viewportOffset: CGSize) -> CGPoint {
        CGPoint(x: graphPoint.x + viewportOffset.width, y: graphPoint.y + viewportOffset.height)
    }

    func graphPoint(fromVisual visualPoint: CGPoint, viewportOffset: CGSize) -> CGPoint {
        CGPoint(x: visualPoint.x - viewportOffset.width, y: visualPoint.y - viewportOffset.height)
    }

    func visualHitRect(at normalized: CGPoint, viewportOffset: CGSize, size: CGFloat = 88) -> CGRect {
        hitRect(at: normalized, size: size).offsetBy(dx: viewportOffset.width, dy: viewportOffset.height)
    }

    /// viewport 的约束边界只应由稳定的布局位置计算；调用方不能传入 drag transient。
    func viewportConstraintCenters(from stableNormalizedPositions: [CGPoint]) -> [CGPoint] {
        stableNormalizedPositions.map { screenPoint(from: $0) }
    }

    /// 可把任一最边缘 node center 移到 viewport 中心，但不允许整个图被甩出可恢复范围。
    func clampedViewportOffset(proposed: CGSize, nodeCenters: [CGPoint]) -> CGSize {
        guard !nodeCenters.isEmpty else { return .zero }
        let minX = nodeCenters.map(\.x).min() ?? 0
        let maxX = nodeCenters.map(\.x).max() ?? 0
        let minY = nodeCenters.map(\.y).min() ?? 0
        let maxY = nodeCenters.map(\.y).max() ?? 0
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let x = min(max(proposed.width, center.x - maxX), center.x - minX)
        let y = min(max(proposed.height, center.y - maxY), center.y - minY)
        return CGSize(width: x, height: y)
    }

    private func clamp(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
}
