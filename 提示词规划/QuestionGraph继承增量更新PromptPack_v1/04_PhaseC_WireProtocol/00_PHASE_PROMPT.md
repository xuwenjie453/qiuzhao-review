# Phase C — Wire Protocol Prompt

在 Mac canonical tests 已通过后再修改 wire。目标是让 iPad 能区分 node owner 与 graph membership，并能恢复 inheritance snapshot。

## 必须更新

- Snapshot root：`parent_graphs`。
- Snapshot node：`owner_graph_id`、`visibility`。
- common fixtures。
- Mac codec/emit 与 Swift codec/model。
- wire version 或兼容策略。

## 不要做

- 不要发送复制 node id；
- 不要用 node.graph_id 省略 owner 字段后让 iPad 猜；
- 不要让旧 client silent parse 新 payload 后丢 membership 语义；
- 不要为了省事把所有 inherited mutation 改成无 revision snapshot stream。

## Gate

同一 fixture 在 Node/Swift 两端能够一致 decode；old payload 处理策略明确；inheritance relation 初建和 shared mutation 都有协议样例。
