# Local Control API

## 1. 传输

仅监听 `127.0.0.1`，不暴露到 LAN。HTTP JSON 即可；这是 Agent CLI 与 Daemon 的边界。

建议：

- `GET /v1/status`
- `POST /v1/question/open`
- `POST /v1/question/close`
- `POST /v1/node/add`
- `GET /v1/graph/:id`

## 2. 为什么不用 Agent 直接写数据库

直接写库会绕开：

- 用户显式入图约束；
- CENTER delete guard；
- immutable body；
- round 生命周期；
- graph revision；
- sync journal；
- patch emit；
- command dedup。

因此所有调用者，包括调试 CLI，都必须经过 command service。

## 3. 标准错误

```json
{
  "ok": false,
  "error": {
    "code": "ROUND_NOT_ACTIVE",
    "message": "...",
    "retryable": false,
    "details": {}
  }
}
```

Daemon 不返回 Python/Node stack trace 给 Agent；详细 stack 只写本地诊断日志。
