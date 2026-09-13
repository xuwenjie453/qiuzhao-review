# Prompt — iPad WebSocketTransport 修复

只聚焦 Transport，不在此阶段引入完整 lifecycle 大改。

## 第一优先级：修 receive stream bug

`NWConnection.receive` 每次调用只触发一次 completion。即使 HTTP Upgrade 尚未完成，也必须继续注册下一次 receive。

删除逻辑：

```swift
if self.opened { self.receiveLoop() }
```

改成只要 transport 未 terminal 就继续 receive。

## 第二优先级：terminal exactly once

实现统一 `finish(...)`，保证：
- failed/cancelled/EOF/receive error/send error/timeout 只通知上层一次；
- teardown 不会因为内部 `cancel()` 再制造第二次业务 callback；
- state handler 在内部 cancel 前解除或通过 finished guard 去重。

## 第三优先级：watchdog

建议第一版：
- connect/preparing/waiting：5s
- HTTP Upgrade：3s
- 不要无限等待

## 第四优先级：send error

`.contentProcessed` 出错必须 finish(error)，不能只 print。
