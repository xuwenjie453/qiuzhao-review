# Transport terminal 状态规范

## 终态来源

- NWConnection `.failed`
- NWConnection `.cancelled`
- receive `isComplete`
- receive error
- send error
- TCP watchdog timeout
- HTTP Upgrade timeout
- explicit owner stop

## exactly once

每个 WebSocketTransport 生命周期只能向 delegate 发送一次 terminal event。

建议内部：
- `finished: Bool`
- `finishReason`
- `finish()` 先置 finished，再断 handler/cancel connection，再回调。

## `.waiting`

记录完整 NWError；启动 bounded watchdog。第一版不必依赖 `restart()`，到期直接废弃对象并由上层新建 connection。
