# Swift 并发 / Actor 合同

建议：
- ClientStore：actor；
- SyncEngine：actor 或明确串行执行域；
- BridgeConnection：actor / Sendable-safe；
- UI Model：@MainActor；
- PencilKit UIKit objects：MainActor；
- DB/blob serialization：异步移出主线程后再 actor commit，按 API thread-safety 调整。

禁止：
- background URLSession callback 直接 mutate @Published；
- MainActor 同步 sqlite 大 BLOB；
- 同一 outbox 多发送 worker 无顺序并发；
- PKCanvasView 从非主线程操作。
