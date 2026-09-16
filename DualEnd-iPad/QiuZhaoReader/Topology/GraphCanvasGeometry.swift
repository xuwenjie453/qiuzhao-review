// GraphCanvasGeometry —— QuestionGraph 的 WORLD_V1 坐标和本地相机转换来源。
import CoreGraphics
import Foundation

/// Canvas Pan 的所有权必须在手势起点确定，并在整个手势周期内保持不变。
/// offset 是 iPad 本地相机状态，绝不能作为节点 canonical layout 同步。
struct CanvasPanSession: Equatable {
    let ownsCanvas: Bool
    let initialViewportOffset: CGSize
}

enum GraphWorldSpace {
    /// 与 Mac `world-layout.mjs` 保持一致，用于把已有 normalized 缓存一次性迁移为世界坐标。
    static let legacyWidth: CGFloat = 1_000
    static let legacyHeight: CGFloat = 700
    static let maximumCoordinate: CGFloat = 1_000_000

    static func legacyNormalizedToWorld(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: (x - 0.5) * legacyWidth, y: (y - 0.5) * legacyHeight)
    }

    /// 仅写入升级前缓存中保留的 NOT NULL 镜像列；不用于 canonical world 读取。
    static func worldToLegacyNormalized(x: Double, y: Double) -> (x: Double, y: Double) {
        (0.5 + x / Double(legacyWidth), 0.5 + y / Double(legacyHeight))
    }
}

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

    /// 世界原点显示在安全内容区中心。world 可以是任意正负有限数，绝不截断。
    func screenPoint(from world: CGPoint) -> CGPoint {
        CGPoint(x: contentRect.midX + world.x, y: contentRect.midY + world.y)
    }

    func worldPoint(from screen: CGPoint) -> CGPoint {
        CGPoint(x: screen.x - contentRect.midX, y: screen.y - contentRect.midY)
    }

    func visualRect(at world: CGPoint, size: CGFloat = 64) -> CGRect {
        let p = screenPoint(from: world)
        return CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
    }

    func hitRect(at world: CGPoint, size: CGFloat = 88) -> CGRect {
        let p = screenPoint(from: world)
        return CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
    }

    /// viewport offset 只属于本地呈现层；canonical world point 始终不含它。
    func visualPoint(from graphPoint: CGPoint, viewportOffset: CGSize) -> CGPoint {
        CGPoint(x: graphPoint.x + viewportOffset.width, y: graphPoint.y + viewportOffset.height)
    }

    func graphPoint(fromVisual visualPoint: CGPoint, viewportOffset: CGSize) -> CGPoint {
        CGPoint(x: visualPoint.x - viewportOffset.width, y: visualPoint.y - viewportOffset.height)
    }

    func visualHitRect(at world: CGPoint, viewportOffset: CGSize, size: CGFloat = 88) -> CGRect {
        hitRect(at: world, size: size).offsetBy(dx: viewportOffset.width, dy: viewportOffset.height)
    }

    /// 以稳定布局快照判定一次 Canvas Pan 的归属。
    /// 不能在节点已开始移动后用新的 visual hit rect 重算这个结果。
    func beginCanvasPanSession(startLocation: CGPoint,
                               stableWorldPositions: [CGPoint],
                               initialViewportOffset: CGSize) -> CanvasPanSession {
        let ownsCanvas = !stableWorldPositions.contains {
            visualHitRect(at: $0, viewportOffset: initialViewportOffset).contains(startLocation)
        }
        return CanvasPanSession(ownsCanvas: ownsCanvas,
                                initialViewportOffset: initialViewportOffset)
    }

    /// 节点拖到内容区边缘时，显式推动本地相机。它不是父 canvas gesture，
    /// 因而不会夺取节点 drag 的所有权或重现画布闪烁。
    func edgeAutoPanDelta(at location: CGPoint, elapsed: TimeInterval) -> CGSize {
        let interval = min(max(CGFloat(elapsed), 0), 1.0 / 12.0)
        guard interval > 0 else { return .zero }
        let horizontal = edgePressure(location.x, min: contentRect.minX, max: contentRect.maxX)
        let vertical = edgePressure(location.y, min: contentRect.minY, max: contentRect.maxY)
        let maximumSpeed: CGFloat = 900 // logical points / second
        return CGSize(width: -horizontal * maximumSpeed * interval,
                      height: -vertical * maximumSpeed * interval)
    }

    private func edgePressure(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        let edge = min(84, max(40, (upper - lower) * 0.10))
        if value < lower + edge { return -min(1, max(0, (lower + edge - value) / edge)) }
        if value > upper - edge { return min(1, max(0, (value - (upper - edge)) / edge)) }
        return 0
    }
}
