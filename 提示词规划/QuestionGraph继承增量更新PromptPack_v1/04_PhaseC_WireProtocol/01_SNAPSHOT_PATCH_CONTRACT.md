# Snapshot / Patch Contract Prompt

## Snapshot V2

目标形态：

```json
{
  "graph_id":"A",
  "question_key":"capsule:...",
  "round_id":"...",
  "revision":13,
  "center_node_id":"CENTER_A",
  "parent_graphs":[
    {"graph_id":"B","inheritance_kind":"SHARED_EXPLANATIONS"}
  ],
  "nodes":[
    {
      "node_id":"E1",
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

OWN node 也必须显式带 owner/visibility，不依赖缺省推断。

## Patch

现有 `ADD_NODE/UPDATE_TITLE/UPDATE_LAYOUT/REMOVE_NODE` 可以继续使用，但 ADD_NODE payload 必须含 owner/visibility。对 membership 关系新建，V1 推荐直接发 child snapshot，避免在第一版加入复杂 membership delta op。

shared mutation 给 child patch 时：
- patch.graph_id 是 child view graph；
- node_id 仍是 canonical shared id；
- base/target revision 使用 child graph revision；
- node revision/layout revision 使用 canonical node revision。

## Recovery

保持：`local graph revision != patch.base_revision -> SNAPSHOT_REQUEST`。

Snapshot 必须足以完整重建 canonical node cache + current graph membership。
