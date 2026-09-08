# BridgeSession 合同

每个 WebSocket 一份 session object：
```text
sessionEpoch
deviceId
selectedProtocol
lastAckedServerSeq
connectedAt
sendQueue
closed
```

握手：
- 未 HELLO 前只接受 HELLO/PING/close；
- HELLO 校验 supported_protocols；
- 生成新 sessionEpoch；
- WELCOME；
- reconcile active graph。

入站：
- CLIENT_COMMAND → GraphService；
- INK_PUT → GraphService；
- SNAPSHOT_REQUEST → query snapshot；
- ACK → update device checkpoint；
- PONG → heartbeat。

出站：
- 所有 canonical event 来自 committed journal/result；
- 不允许 service mutate 之前先 emit optimistic server patch。

旧 session：
- close/cancel 后其异步 callback 不得继续写 active device state。
