# iPad Store / UI Tests Prompt

至少覆盖以下 Swift tests：

## Store

- v1 nodes_cache migration creates OWN membership。
- one canonical node can belong to B/A/C memberships。
- applying A snapshot does not delete B/C membership。
- canonical rename visible when loadSnapshot(B/A/C)。
- canonical layout update visible across memberships。
- Ink cache remains one row per node_id。
- outbox graph_id remains view context。
- snapshot durable + inbox write occurs before ACK trigger path。

## Patch recovery

- child patch base mismatch returns `.baseMismatch`；
- subsequent snapshot restores inherited membership；
- pending local outbox survives snapshot replace。

## UI state

- inherited badge only for INHERITED；
- inherited delete invokes shared-impact confirmation state；
- CENTER still lacks delete；
- Reader route uses node_id and shared ink。

无法自动测的 Pencil 真机行为留到 Release Gate，不要用 simulator 测试冒充真机 PASS。
