# WELCOME 修复规范

## 当前错误

- message_id 固定 `x`
- send 在 journal 前

## 目标

```text
create session epoch
create unique welcome message id
persist journal
send WELCOME
```

## 建议

`messageId = uuid()`，而不是 `welcome-${epoch}` 也可以；UUID 更直接。

WELCOME 的 `server_seq` 字段需要重新确认语义：如果它表示全局 max seq，应在 journal WELCOME 前/后定义清楚并保持一致测试。

## 测试

- 连续建立 100 个 session 不得出现 UNIQUE。
- 每个 WELCOME message_id 唯一。
- journal 失败时不得已经对客户端承诺一个无法持久化的 WELCOME。
