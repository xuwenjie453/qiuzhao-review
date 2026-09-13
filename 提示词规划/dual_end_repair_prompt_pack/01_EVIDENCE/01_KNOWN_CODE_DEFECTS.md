# 已知代码缺陷清单

## Mac

### M1 — `WELCOME` message_id 硬编码 `'x'`
文件：`DualEnd-Mac/src/bridge/sync-session.mjs`
后果：第二次及以后 WELCOME journal 冲突。

### M2 — journal 裸 INSERT
文件：`DualEnd-Mac/src/store/state-db.mjs`
后果：合法 replay 被当成 UNIQUE 错误。

### M3 — durable-before-emit 顺序不一致
WELCOME 当前先 send 再 journal。

### M4 — unexpected onMessage error 只日志、不形成明确 session 策略
修复后应定义“协议异常是否结束当前 session”。

## iPad

### I1 — `receiveLoop()` 握手未完成时停止接收
这是确定的 stream framing bug。

### I2 — `.cancelled` 静默 break
可能导致上层 `ws` 不释放。

### I3 — waiting/preparing 无 deadline
可能永久 CONNECTING。

### I4 — send error 只打印
连接健康状态可能与真实 transport 脱节。

### I5 — backoff reset 过早
发现 candidate 就 `reconnectAttempt=0`，TCP 层失败时不能形成真实退避。

### I6 — Browser 只保存 service name，再手工重建 endpoint
应优先保存 NWBrowser.Result.endpoint 原对象。

### I7 — Browser fatal/stale 无 rebuild
`browser != nil` 会阻止 start()。

### I8 — 无 foreground network epoch
跨 suspend 复用旧对象风险高。
