# Graph Snapshot / Patch

> 自问题图继承 V1 起，Snapshot/Patch 描述的是 **effective graph view**，不再等同于 `nodes.graph_id = graph_id` 的独占节点集合。详细语义见 `01_产品与领域/05_问题图继承与共享解释节点.md`。

## 1. Snapshot

```json
{
  "graph_id": "A",
  "question_key": "capsule:cap-1:probe-1",
  "round_id": "current round",
  "revision": 12,
  "center_node_id": "center-A",
  "parent_graphs": [
    {
      "graph_id": "B",
      "inheritance_kind": "SHARED_EXPLANATIONS"
    }
  ],
  "nodes": [
    {
      "node_id":"center-A",
      "owner_graph_id":"A",
      "visibility":"OWN",
      "kind":"CENTER",
      "title":"...",
      "body_markdown":"...",
      "node_revision":3,
      "layout":{"x":0.5,"y":0.5,"revision":2}
    },
    {
      "node_id":"ex-B-1",
      "owner_graph_id":"B",
      "visibility":"INHERITED",
      "kind":"EXPLANATION",
      "title":"...",
      "body_markdown":"...",
      "node_revision":4,
      "layout":{"x":0.2,"y":0.3,"revision":5}
    }
  ]
}
```

Snapshot 中：

- 不含 deleted；
- 不含 previous round 的 temporary；
- 必含当前 graph OWN CENTER；
- 永不继承 parent CENTER；
- 永不继承 TEMPORARY；
- inherited node 保持原 canonical `node_id`；
- `owner_graph_id` 指 canonical owner；
- `visibility` 只描述该 node 在当前 snapshot 中是 `OWN` 还是 `INHERITED`；
- body 可随 snapshot 下发，因为解释规模小且离线需要完整可读；
- `parent_graphs` 为空表示独立 graph。

## 2. Patch

```json
{
  "graph_id":"A",
  "base_revision":12,
  "target_revision":13,
  "ops":[
    {"op":"ADD_NODE","node":{...}},
    {"op":"UPDATE_TITLE","node_id":"...","title":"...","node_revision":4},
    {"op":"UPDATE_LAYOUT","node_id":"...","layout":{...}},
    {"op":"REMOVE_NODE","node_id":"..."},
    {"op":"SET_INHERITANCE","parent_graphs":[...]}
  ]
}
```

### 2.1 Shared node mutation

若 node 属于 parent graph，但在 child graph 可见，则同一次 canonical mutation 可以影响多个 graph 的 effective view。

Server 必须：

1. 计算 `AffectedGraphs(node_id)`；
2. 分别推进每个 affected graph 的 `graph_revision`；
3. 为需要实时同步的 graph 生成各自连续的 patch；
4. durable journal 后再 emit。

禁止拿 owner graph 的 revision 直接冒充 child graph revision。

### 2.2 Inheritance edge change

创建/移除 inheritance relation 会改变 child effective node membership，必须推进 child graph revision。

V1 可优先发送整图 Snapshot 以降低 SET_INHERITANCE + 多 ADD_NODE 的实现复杂度；协议保留 `SET_INHERITANCE` op 作为后续优化能力。

## 3. iPad apply rule

只有 `local.graph_revision == patch.base_revision` 时 apply。否则：

1. 不盲写；
2. 发 `SNAPSHOT_REQUEST`；
3. 保留当前缓存 UI；
4. 收到 snapshot 后原子更新 canonical node cache + 当前 graph membership；
5. 再重放未 ACK outbox（命令级重放）。

继承场景中 snapshot apply **不能删除某 node 在其他 graph 的 membership**。同一 canonical `node_id` 可以同时属于多个 cached graph view。

## 4. durable-before-ACK

iPad 接受 Snapshot/Patch：先 SQLite transaction apply + inbox message_id，再发 ACK。避免 crash 后 server 认为已同步但 iPad 实际没落盘。

继承 Snapshot transaction 至少原子包含：

- graphs_cache；
- nodes_cache canonical upsert；
- graph_node_membership_cache replace for current graph；
- inbox_dedup。

## 5. Ink

Ink 仍不通过 GRAPH_PATCH 高频传播；它保持 node-scoped revision 语义。

因此 inherited Explanation 的 Ink：

```text
same node_id
=> same ink stream
```

不需要为 parent/child 分别维护 Ink 副本。
