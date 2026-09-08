# PencilKit Canvas

## 任务目标
将 `PKCanvasView` 集成到 Reader，Pencil 写、finger 滚动。

## 必读设计稿
- `90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`

## 必须满足
- PKCanvasView 是真实交互画布。
- drawingPolicy `.pencilOnly`（按当前 SDK API）。
- Ink overlay 透明且 same bounds。

## 实施步骤
1. UIKit bridge 持有 canvas。
2. 避免 SwiftUI view refresh 重建 canvas/drawing。
3. tool 配置集中。

## 测试要求
- drawing persistence basic
- finger scroll not draw

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
