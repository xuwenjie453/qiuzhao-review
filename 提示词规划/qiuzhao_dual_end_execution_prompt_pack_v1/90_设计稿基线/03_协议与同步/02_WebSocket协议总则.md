# WebSocket Wire Protocol v1

## 1. Envelope

所有 text frame 是 UTF-8 JSON：

```json
{
  "v": 1,
  "message_id": "uuid",
  "type": "GRAPH_SNAPSHOT",
  "session_epoch": "uuid-or-null",
  "sent_at": "2026-09-08T12:34:56.123Z",
  "payload": {}
}
```

## 2. 类型

Server→Client：

- `WELCOME`
- `ACTIVE_GRAPH_CHANGED`
- `GRAPH_SNAPSHOT`
- `GRAPH_PATCH`
- `INK_SNAPSHOT`
- `COMMAND_ACK`
- `COMMAND_REJECTED`
- `PING`

Client→Server：

- `HELLO`
- `SNAPSHOT_REQUEST`
- `CLIENT_COMMAND`
- `INK_PUT`
- `ACK`
- `PONG`

## 3. HELLO

```json
{
  "device_id": "stable ipad uuid",
  "client_build": "1.0.0",
  "supported_protocols": [1],
  "last_server_seq": 120,
  "cached_graph": {"graph_id":"...", "revision":7}
}
```

## 4. WELCOME

```json
{
  "selected_protocol": 1,
  "daemon_id": "...",
  "session_epoch": "new uuid",
  "server_seq": 126,
  "active": {"graph_id":"...", "round_id":"..."}
}
```

## 5. server_seq

所有 canonical server events 获得单调 `server_seq`。它用于诊断/replay checkpoint，不取代 per-graph revision。

## 6. 兼容性

- 未知 `type`：记录并忽略，不能 crash。
- `v` 不支持：server 返回 `PROTOCOL_UNSUPPORTED` 后断开。
- 新增 optional field 向后兼容；删除/改语义必须 bump protocol version。
