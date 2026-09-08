# Graph Snapshot / Patch

## 1. Snapshot

```json
{
  "graph_id": "...",
  "question_key": "qb:...",
  "round_id": "current round",
  "revision": 12,
  "center_node_id": "...",
  "nodes": [
    {
      "node_id":"...",
      "kind":"CENTER",
      "title":"...",
      "body_markdown":"...",
      "node_revision":3,
      "layout":{"x":0.5,"y":0.5,"revision":2}
    }
  ]
}
```

Snapshot 中：

- 不含 deleted；
- 不含 previous round 的 temporary；
- 必含 CENTER；
- body 可随 snapshot 下发，因为解释规模小且离线需要完整可读。

## 2. Patch

```json
{
  "graph_id":"...",
  "base_revision":12,
  "target_revision":13,
  "ops":[
    {"op":"ADD_NODE","node":{...}},
    {"op":"UPDATE_TITLE","node_id":"...","title":"...","node_revision":4},
    {"op":"UPDATE_LAYOUT","node_id":"...","layout":{...}},
    {"op":"REMOVE_NODE","node_id":"..."}
  ]
}
```

## 3. iPad apply rule

只有 `local.graph_revision == patch.base_revision` 时 apply。否则：

1. 不盲写；
2. 发 `SNAPSHOT_REQUEST`；
3. 保留当前缓存 UI；
4. 收到 snapshot 后原子替换 canonical cache；
5. 再重放未 ACK outbox（命令级重放）。

## 4. durable-before-ACK

iPad 接受 Snapshot/Patch：先 SQLite transaction apply + inbox message_id，再发 ACK。避免 crash 后 server 认为已同步但 iPad 实际没落盘。
