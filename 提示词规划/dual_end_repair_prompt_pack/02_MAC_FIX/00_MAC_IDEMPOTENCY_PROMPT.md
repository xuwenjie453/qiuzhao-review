# Prompt — Mac 端幂等修复

只修改 Mac 端。此阶段禁止修改 iPad。

## 目标

让当前真实失败现场中的持久 outbox 项在下一次 replay 时：

`duplicate message -> verify same semantics -> reuse original server_seq -> send ACK -> iPad clears outbox`

## 必做

1. 将客户端可重放消息的 journal 写入改成幂等 API。
2. 重复 message_id 必须查询已有 row。
3. 校验重复消息的语义身份一致。
4. 一致：返回原 `server_seq`，调用方继续 ACK。
5. 不一致：抛明确 `MESSAGE_ID_REUSE_CONFLICT`，日志包含 message_id/command_id/kind。
6. 不要把服务端自产生的 GRAPH_PATCH/SNAPSHOT 的 UUID 冲突无条件吞掉。
7. 移除 WELCOME 固定 `'x'`。
8. 恢复 durable-before-emit：先 journal，再 send。

## 推荐 API

- `journalUnique(...)`：服务端自产生事件，重复仍是 bug。
- `journalReplayable(...)`：CLIENT_COMMAND / INK_PUT 使用。

## 完成后

先运行单测，再使用真实 poison outbox 验证；不要清 iPad 数据。
