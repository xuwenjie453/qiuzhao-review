# iPad 高层 Question Graph / Topology

## 1. 视觉语义

- CENTER：正方形。
- EXPLANATION：圆形。
- TEMPORARY：等边/视觉明确三角形。
- 标题显示在节点图形上方，最多 2 行，超长省略；完整标题在单击管理 sheet 内显示。
- 所有子节点可画一条低强调度线连到 CENTER；线无业务编辑能力。

## 2. 初始布局

首次 graph：CENTER `(0.5, 0.5)`。

新增子节点使用确定性 radial slot：

```text
angle = golden_angle * insertion_index
radius = min(0.18 + ring*0.12, 0.42)
```

目的仅是防重叠。用户一旦拖动，写 `USER_PINNED` layout，后续不得自动重新布局该 node。

## 3. 手势优先级

- double tap > single tap；
- long press 进入 drag，不触发 single；
- drag 过程中禁止页面导航；
- Pencil 在 Topology 页面默认不作为绘图输入，以免和节点拖动混淆。

## 4. Single tap sheet

字段：

- node title TextField；
- kind badge；
- persistent/temporary 状态；
- delete（CENTER 不出现）。

保存 title：先 local commit/outbox，再 dismiss。

## 5. Double tap

导航 `ReaderRoute(node_id)`。Reader 必须按 node_id 恢复 ink，不按 title/body hash。

## 6. 删除

删除后本地立即从图隐藏并写 outbox。若 server reject（理论上主要 CENTER），恢复 snapshot 并显示错误。CENTER UI 根本不提供 delete，server 仍必须守卫。
