# scenePhase 集成规范

在 SwiftUI App 层监听 scene phase。

## background/inactive

不要删除 ClientStore/outbox。
仅停止瞬态资源：
- transport
- browser
- reconnect timer
- handshake watchdog

## active

- startNewNetworkEpoch(reason: foreground)
- phase -> discovering

## 幂等要求

重复收到 active 不应创建并行 epoch；需要 generation/owner guard。
