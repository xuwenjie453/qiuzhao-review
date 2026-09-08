# PencilCoordinator 合同

持有：
- PKCanvasView；
- current ink tool；
- previous ink tool；
- eraser tool；
- dirty state；
- save debounce task；
- current node_id / ink_revision。

行为：
- drawingPolicy pencilOnly；
- canvas delegate drawingDidChange → 标 dirty + schedule save；
- double tap：
  - ink → eraser
  - eraser → previous ink
- node change 前 force flush；
- view disappear force flush；
- scene inactive/background force flush。

持久化：
- PKDrawing.dataRepresentation；
- ClientStore saveInkLocal；
- 大 blob 序列化/DB 不能制造落笔延迟。
