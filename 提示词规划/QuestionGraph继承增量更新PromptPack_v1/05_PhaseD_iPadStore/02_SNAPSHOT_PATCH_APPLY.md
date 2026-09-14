# iPad Snapshot / Patch Apply Prompt

## applySnapshot

收到 graph A snapshot 时事务内：

1. upsert graphs_cache A + parent relation metadata（可放专表或 snapshot metadata cache）；
2. upsert snapshot 中每个 canonical node 到 nodes_cache；
3. **只替换 A 的 membership set**；
4. 不标记/删除其他 graph 的 membership；
5. 对 server 不再包含的 A membership 做 remove；
6. 保留未 ACK outbox 对 canonical node 的本地意图；
7. 写 inbox_dedup；
8. commit 后才 ACK。

旧代码中“snapshot 未出现的本 graph node 标 locally_deleted”的策略必须重新审查，不能把 shared canonical node 因某个 child snapshot 缺失而全局标 deleted。

## applyPatch

Patch.graph_id 决定哪个 graph revision 前进；node op 更新 canonical row，并按 op 类型更新该 graph membership。

shared UPDATE_TITLE/UPDATE_LAYOUT 不需要复制到每个 membership row，因为 membership 不保存 canonical state。

## Base mismatch

保持现有恢复：不盲 apply；请求 snapshot；保留本地 pending intent；snapshot durable 后重放 outbox。
