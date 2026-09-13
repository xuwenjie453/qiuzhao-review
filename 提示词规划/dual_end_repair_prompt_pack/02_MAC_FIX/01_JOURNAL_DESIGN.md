# journal 幂等设计规范

## 建议返回值

```js
{
  serverSeq: Number,
  replay: Boolean,
  existing?: Row
}
```

## 写入算法

1. `INSERT ... ON CONFLICT(message_id) DO NOTHING`。
2. `changes===1`：新消息，返回 lastInsertRowid。
3. `changes===0`：SELECT 原 row。
4. 比较 semantic identity。
5. 相同：返回原 server_seq，`replay=true`。
6. 不同：抛协议冲突错误。

## CLIENT_COMMAND identity

至少：
- message_id
- command_id
- kind
- graph_id
- 对关键 payload 做 canonical stable serialization 或 hash

## INK_PUT identity

至少：
- command_id
- graph_id
- node_id
- ink_revision
- blob_sha256

## 安全性

`DO NOTHING` 只能用于已定义可重放语义的消息类型。
