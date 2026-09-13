# 结构化日志规范

## iPad 每条网络日志

字段至少：
- timestamp
- networkEpoch
- browserId/generation
- transportId
- phase
- state
- error domain/code/description
- endpoint/service name
- reconnectAttempt
- watchdog kind

## Protocol
- sessionEpoch
- messageId
- commandId
- message type
- outbox state transition

## Mac
- connectionId
- deviceId
- sessionEpoch
- messageId
- commandId
- kind
- journal: inserted/replay/conflict
- serverSeq
- ACK sent result

## 原则

日志必须支持重建一条完整 Timeline，而不是只打印“失败”。
