# 最终成功标准

## 功能 SLA

- 正常前台恢复：目标 < 3 秒。
- 一般异常重试：目标 < 10 秒。
- 任何前台场景：30 秒内必须 `READY` 或明确错误，不允许无限 CONNECTING。

## 协议

- ACK 丢失后重连：原 message_id 重放必须成功补 ACK。
- 重放不得重复产生 mutation。
- 同 message_id 不同语义必须拒绝并记录冲突。
- WELCOME 不得再使用固定 ID。

## Transport

- 101 HTTP header 被拆成任意多段，仍能完成 Upgrade。
- `.failed/.cancelled` 都能让上层释放当前 transport。
- `.waiting/.preparing` 有有界 watchdog。
- `send` 错误触发 transport failure，而不是只打印。

## Discovery/Lifecycle

- NWBrowser `.failed` 后能创建新 browser。
- prolonged `.waiting` 能 rebuild。
- foreground 可建立新 network epoch。
- stale epoch callbacks 被忽略。

## 回归

- Mac 原测试全绿。
- iPad 原测试全绿。
- 新增协议/transport/lifecycle 测试全绿。
- 120s 锁屏至少 20 次无永久卡死。
