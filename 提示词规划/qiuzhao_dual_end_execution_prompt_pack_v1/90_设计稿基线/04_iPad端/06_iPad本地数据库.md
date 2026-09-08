# iPad ClientStore SQLite

## 1. 原则

iPad 的每次用户 mutation 先 durable，再发网络。Store 使用单 actor 串行 SQLite 事务，避免 View/Sync 并发写。

## 2. 表

- `graphs_cache`
- `nodes_cache`
- `layouts_cache`
- `ink_cache`
- `active_state`
- `inbox_dedup`
- `outbox`
- `daemon_identity`
- `meta`

## 3. outbox

```text
outbox_id
message_id unique
kind
entity_id
payload_json/blob_ref
created_at
attempt_count
last_attempt_at
state PENDING|INFLIGHT
```

WebSocket 断开时 INFLIGHT 全部回 PENDING；清除只依据 Mac `COMMAND_ACK`/Ink ACK。

## 4. snapshot replace

GRAPH_SNAPSHOT apply 使用 transaction：

1. upsert graph；
2. upsert visible nodes；
3. mark server-absent nonlocal nodes stale/deleted；
4. preserve unsent local outbox intents；
5. set graph revision；
6. insert inbox message_id；
7. commit；
8. ACK。

## 5. cache policy

v1 不主动清除旧 graphs。题库量虽大，但实际只缓存打开过的问题图，正文/ink 可接受。未来如需要 LRU，只清无 pending outbox 的非 active graph。
