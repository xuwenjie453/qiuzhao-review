// Pencil —— 双击切换 ink/eraser + PKDrawing 绑定 node_id 持久化。
// UIPencilInteraction 双击: ink→eraser; eraser→恢复 previousInkTool (第一代 Pencil 无双击硬件)。
import UIKit
import PencilKit

final class PencilToolController: NSObject, UIPencilInteractionDelegate, ObservableObject {
    @Published var isEraser = false
    private var inkTool: PKTool
    private weak var canvas: PKCanvasView?

    override init() {
        inkTool = PKInkingTool(.pen, color: .black, width: 2.5)
        super.init()
    }

    func attach(to view: UIView) {
        if let canvasView = view as? PKCanvasView {
            if canvas === canvasView { return }
            canvas = canvasView
        }
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
    }

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        // 第一下双击必定进入 eraser; 再次双击返回此前 ink (提供返回路径)
        if isEraser {
            isEraser = false
        } else {
            isEraser = true
        }
        if let canvas {
            apply(to: canvas, isEraser: isEraser)
        }
    }

    func apply(to canvas: PKCanvasView, isEraser: Bool) {
        if isEraser {
            canvas.tool = PKEraserTool(.vector)
        } else {
            let current = canvas.tool
            if let ink = current as? PKInkingTool { inkTool = ink }
            canvas.tool = inkTool
        }
        // ★ @Published 即使写同值也会触发 objectWillChange；而 apply 在每次
        // SwiftUI updateUIViewController 中被调用 → 无条件写会形成
        // “更新→发布→重渲染→更新” 的死循环（主线程 99% CPU、界面卡死）。
        // 只有值真正变化才允许发布。
        if self.isEraser != isEraser {
            self.isEraser = isEraser
        }
    }
}
