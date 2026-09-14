# Phase D — iPad Store Prompt

本阶段只让 iPad 正确存储 canonical node 与 graph membership。UI 可以暂时保持简单。

## 核心变化

旧模型把 `nodes_cache.graph_id` 同时当 ownership 与 membership。新模型必须正规化：

```text
nodes_cache                # canonical node once
graph_node_membership_cache # node visible in graph
```

## Gate

- 同一 E1 可同时出现在 B/A/C membership；
- nodes_cache 只有一条 E1 canonical row；
- A snapshot apply 不删除 B/C membership；
- rename/move patch 更新 canonical E1，A/B/C reload 都看到新状态；
- outbox 仍按 ACK 清；
- durable-before-ACK 保持；
- existing v1 cache 可迁移为 OWN membership；
- relaunch 后 inheritance membership 仍能恢复。
