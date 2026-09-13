# iPad–Mac 双端失联修复 AI 提示词包

本包用于指导一个具备代码读取/修改能力的 AI，在 `xuwenjie453/qiuzhao-review` 中修复 iPad–Mac 双端通信的复合失联问题。

## 已确认的核心问题

1. Mac `sync_journal.message_id UNIQUE` 与 iPad 持久 outbox 重放语义不兼容：ACK 丢失后重放同一 `message_id` 会触发 UNIQUE 异常。
2. Mac `WELCOME` 使用硬编码 `message_id='x'`，第二次会话起必然冲突；且当前代码违反 durable-before-emit 顺序。
3. iPad `WebSocketTransport.receiveLoop()` 仅在 `opened == true` 时继续注册 `receive`，如果 HTTP 101 响应被拆包，握手会永久卡死。
4. iPad 对 `NWConnection.cancelled` 静默 `break`，`waiting/preparing` 无有界 watchdog，存在 `ws != nil` 的吸收态。
5. `NWBrowser` fatal/cancelled/waiting-timeout 没有可靠 rebuild；App 缺少 foreground-driven network epoch 重建。
6. reconnect backoff 在“发现 candidate”时过早清零；多个恢复触发源未来可能造成重复 timer/race。

## 执行顺序

严格按以下顺序，不要一次性大改：

1. 阅读 `00_START_HERE/00_MASTER_PROMPT.md`。
2. 保留失败现场，执行 `07_EXECUTION/01_PHASED_EXECUTION_PLAN.md`。
3. 先只修 Mac 幂等，验证现有 poison outbox 是否自愈。
4. 再修 iPad Transport。
5. 再修 Bonjour + lifecycle + network epoch。
6. 最后做故障注入与锁屏压力回归。

## 红线

- 禁止删除/清空 iPad `client-store.sqlite` 或 outbox，除非用户明确批准。
- 禁止为了“恢复连接”重置 canonical 数据库。
- 禁止把 `.cancelled` 视作唯一 suspend 结果。
- 禁止把 `.ready` 当成“应用层已恢复”；必须至少收到 WELCOME，并完成必要同步。
- 禁止把所有 `message_id` 冲突无条件吞掉；重复 ID 必须做语义一致性校验。
