// Pencil —— 双击切换 ink/eraser + PKDrawing 绑定 node_id 持久化。
// UIPencilInteraction 双击: ink→eraser; eraser→恢复 previousInkTool (第一代 Pencil 无双击硬件)。
import UIKit
import PencilKit

final class PencilToolController: NSObject, UIPencilInteractionDelegate, ObservableObject {
    @Published var isEraser = false
    private var inkTool: PKTool

    override init() {
        inkTool = PKInkingTool(.pen, color: .black, width: 2.5)
        super.init()
    }

    func attach(to view: UIView) {
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
    }

    func apply(to canvas: PKCanvasView, isEraser: Bool) {
        if isEraser {
            canvas.tool = PKEraserTool(.vector)
        } else {
            let current = canvas.tool
            if let ink = current as? PKInkingTool { inkTool = ink }
            canvas.tool = inkTool
        }
        self.isEraser = isEraser
    }
}
