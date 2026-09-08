# Command Executor / Idempotency 合同

建议将所有 mutation 包装为：
```text
execute(commandId, actor, commandName, input, tx => CommandResult)
```

transaction 内：
- 若 command_dedup 已存在，直接 parse 并返回旧 result，不再执行；
- 新执行必须把 mutation + journal + result_json 一起 commit。

注意：
- `command_id` 被重复用于不同 payload 时建议返回 `COMMAND_ID_CONFLICT`，而不是错误地把旧结果当新命令；
- 可在 dedup 表额外保存 request hash；
- server-generated journal message_id 与 client command_id 可以不同，但映射要可诊断；
- HTTP/WebSocket 重试都共享同一幂等层。
