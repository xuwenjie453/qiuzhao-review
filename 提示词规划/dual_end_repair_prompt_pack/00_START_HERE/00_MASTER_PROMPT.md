# MASTER PROMPT — 双端失联修复执行总控

你是本仓库的高级网络协议与可靠性工程师。你的任务不是“让这一次能连上”，而是消除所有会进入永久 `CONNECTING/OFFLINE` 的吸收态，并把客户端-服务端协议改造成可安全重放、可自愈、可观测的有限状态系统。

## 仓库

- Repo: `xuwenjie453/qiuzhao-review`
- 当前相关分支历史：`fix/pencil-live-render-v3`
- Mac: `DualEnd-Mac/`
- iPad: `DualEnd-iPad/`

## 事实优先级

每个结论必须标记：
- `FACT`：源码、日志、数据库直接证明。
- `INFERENCE`：由事实推导但尚未因果验证。
- `UNKNOWN`：缺少证据。

不要把推测写成根因。

## 当前关键事实

### Mac
- `sync_journal.message_id` 有 UNIQUE 约束。
- `StateDb.journal()` 当前是裸 INSERT。
- `SyncSession.onHello()` 使用硬编码 `message_id='x'`。
- iPad 重放旧消息时，Mac 日志出现 `UNIQUE constraint failed: sync_journal.message_id`。
- Mac 曾观察到 `upgrade 101 -> iPad`，说明至少某些失败循环已越过 Bonjour/TCP/HTTP Upgrade。

### iPad
- `SyncEngine.onSocketOpen()` 会 `restoreInflightToPending()` + `replayOutbox()`。
- ACK 到达后才清 outbox，因此这是 at-least-once delivery 设计。
- `WebSocketTransport.receiveLoop()` 当前只在 `opened == true` 时继续 `receive()`。
- `NWConnection.cancelled` 当前被静默忽略。
- `SyncEngine.connect()` 只要 `ws != nil` 就拒绝创建新 transport。
- `BonjourBrowser.start()` 只要 `browser != nil` 就拒绝创建新 browser。
- App 无明确 `scenePhase -> foreground network rebuild` 逻辑。

## 目标系统不变量

最终必须满足：

1. **At-least-once delivery, exactly-once effect**
   - 同一客户端消息可重放。
   - 业务效果只发生一次。
   - 重放必须补 ACK。

2. **所有非 READY 状态有最大驻留时间**
   - TCP establish、HTTP Upgrade、HELLO/WELCOME、Browser waiting 均不能无限等待。

3. **任何 terminal/stale transport 最终都能释放 `SyncEngine.ws`**。

4. **任何 fatal/stale browser 最终都能创建全新 NWBrowser**。

5. **foreground + Mac daemon healthy + 同 LAN**：必须在有限时间内进入 READY，或进入明确错误态，禁止无限“正在连接”。

6. **旧 epoch 的异步 callback 不得污染新 epoch**。

## 强制分阶段执行

### Phase A — 保存失败现场
不要修改 iPad 持久数据。先备份：
- iPad `client-store.sqlite`
- Mac `dual-end.db`
- daemon 日志
- 当前 git HEAD / branch

### Phase B — 只修 Mac 幂等
目标：保持 iPad 二进制与数据库不变，让当前 poison outbox 自动 replay → server dedup → 补 ACK → 清 outbox。

若成功，这是因果验证，不要立即继续改 iPad；先保存证据。

### Phase C — 修 iPad WebSocketTransport
优先修 HTTP 101 分片 receive bug，再做 terminal exactly-once、timeout、send error。

### Phase D — 修 SyncEngine / Browser / Lifecycle
实现 reconnect timer 单例、正确 backoff、browser rebuild、foreground Network Epoch。

### Phase E — 故障注入与回归
必须覆盖 ACK-loss、101 split、waiting、daemon restart、锁屏、旧 callback 等。

## 输出要求

每阶段完成后生成：
- 改动文件列表
- 关键 diff 摘要
- 测试命令与结果
- 仍未解决的 UNKNOWN
- 是否允许进入下一阶段

若证据与本提示词假设冲突，优先相信新证据，暂停并更新根因模型。
