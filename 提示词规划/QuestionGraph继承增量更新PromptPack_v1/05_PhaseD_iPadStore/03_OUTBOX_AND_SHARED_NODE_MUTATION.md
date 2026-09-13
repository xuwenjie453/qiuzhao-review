# iPad Outbox & Shared Node Mutation Prompt

继承后 outbox 不能把 `graph_id` 误当 node owner。

## localRename/localMove/localDelete/localInkSave

- `entity_id = node_id` 保持不变；
- payload.graph_id = 当前 view graph；
- payload.node_id = canonical node id；
- base revisions 来自 canonical node/layout/ink；
- 本地 optimistic UI 修改 canonical row，而不是创建 child-specific copy。

## ACK/Conflict

- ACK 仍是清 outbox 唯一依据；
- CAS_MISMATCH 时用 server canonical state 恢复；
- 若另一个 sibling 已修改 shared node，本地冲突逻辑与同图并发一致；
- 不要因为 owner_graph_id != current_graph_id 就拒绝生成 outbox。

## Delete

UI 确认后 localDelete shared node 可以 optimistic 从当前 graph 隐藏，但在 server global delete 确认/patch 后，所有 memberships 最终都必须移除。若 server reject，恢复 snapshot。

## Ink

`ink_cache(node_id)` 保持单份。切换 parent/child graph 双击同一 E1，Reader 必须载入同一 drawing。
