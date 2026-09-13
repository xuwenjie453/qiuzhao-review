# Prompt — SyncEngine 修复

## 目标

让所有 transport 终态最终释放 `ws`，且任意重连只能由单一调度器驱动。

## 必做

- `reconnectAttempt` 只在 WELCOME/READY 后清零，不在 candidate 选中时清零。
- 维护单个 reconnect work item/task；新 schedule 前 cancel 旧 timer。
- transport callback 必须做 identity/epoch guard。
- HELLO→WELCOME 增加 5s watchdog。
- `ws != nil` 只能表示一个真实活动 attempt；terminal 后必须变 nil。
- phase transitions 记录完整 reason。

## 状态建议

DISCOVERING -> CONNECTING -> HANDSHAKING/SYNCING -> READY
失败统一进入 RECOVERING，再回 DISCOVERING/CONNECTING。
