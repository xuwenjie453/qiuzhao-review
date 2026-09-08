# iPad ClientStore Actor 合同

ClientStore 是 iPad 本地事实入口。SwiftUI/Network 不直接 SQLite。

建议接口：
```swift
actor ClientStore {
  func openAndMigrate() throws
  func cachedActiveGraph() throws -> GraphSnapshot?
  func applySnapshot(_ snapshot: GraphSnapshot, messageID: UUID) throws
  func applyPatch(_ patch: GraphPatch, messageID: UUID) throws -> PatchApplyResult
  func renameLocal(...) throws -> OutboxRecord
  func moveLocal(...) throws -> OutboxRecord
  func deleteLocal(...) throws -> OutboxRecord
  func saveInkLocal(...) throws -> OutboxRecord
  func nextOutbox() throws -> OutboxRecord?
  func markInflight(...)
  func ackOutbox(...)
  func resetInflightToPending()
  func hasSeen(messageID: UUID) -> Bool
}
```

事务：
- local mutation + outbox 同一事务；
- snapshot/patch + inbox dedup 同一事务；
- ACK 清 outbox 单独安全事务；
- disconnect 将 INFLIGHT 恢复 PENDING。

不得：
- View 持有 sqlite connection；
- receive loop 直接 mutate graph arrays 再“稍后落盘”。
