# Phase E — iPad UI Prompt

只有在 iPad Store 已能正确表达一 node 多 membership 后才进入本阶段。

本阶段目标是让 inherited Explanation 在 Topology/Reader 中表现为“同一共享节点”，而不是新增一种伪 node 类型。

## UI 语义

- inherited Explanation 仍是圆形 EXPLANATION；
- 可增加轻量 inherited badge，但不要创建第四种 NodeKind；
- child CENTER 只连接当前 view 中的 Explanation，用视觉边表示 view relation；
- rename/move/Reader/Ink 对 own 与 inherited Explanation 使用相同交互入口；
- inherited delete 必须先提示这是 global shared delete；
- child own Explanation 不应显示 inherited badge。

## Gate

至少完成 UI/model tests 或可验证代码路径：
- inherited E1 可显示；
- double tap E1 用 `ReaderRoute(node_id)`；
- rename/move 能生成 current view graph context 的 outbox；
- inherited delete 有明确二次确认；
- CENTER delete 仍无入口；
- Pencil/Reader 不按 graph_id 复制 Ink。
