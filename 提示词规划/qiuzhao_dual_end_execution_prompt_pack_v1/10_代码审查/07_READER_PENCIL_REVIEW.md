# Reader / Pencil Reviewer

BLOCKER：
- 双 scroll view 同步；
- WebView 默认实现造成未知 layout；
- body 可编辑；
- SwiftUI refresh 重建 PKCanvasView 丢 drawing；
- MainActor 同步写大 BLOB；
- Ink 以 title/hash 绑定。

必须确认：
- single coordinate container；
- PencilKit；
- pencilOnly；
- UIPencilInteraction；
- force flush；
- canonical page width；
- true device gate。
