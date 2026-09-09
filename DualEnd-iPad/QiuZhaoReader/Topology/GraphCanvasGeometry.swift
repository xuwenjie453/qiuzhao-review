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

    private func clamp(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
}
