# iPad 高层 Question Graph / Topology

> 自问题图继承 V1 起，Topology 展示的是 effective graph view：当前 graph 自有节点 + 可见的 inherited EXPLANATION。

## 1. 视觉语义

- CENTER：正方形。
- EXPLANATION：圆形。
- TEMPORARY：等边/视觉明确三角形。
- inherited EXPLANATION 仍然是圆形，不新增第四种 NodeKind。
- 可用轻量 badge / chain indicator 标识 inherited，但不得让用户误以为是复制节点。
- 标题显示在节点图形上方，最多 2 行，超长省略；完整标题在单击管理 sheet 内显示。
- 所有可见非 CENTER 节点都可画一条低强调度线连到当前 view graph 的 CENTER；该线只是视图关系，不改变 node owner。

## 2. Effective View

当前图 G 的可见节点：

```text
OWN CENTER
+ OWN EXPLANATION
+ current-round OWN TEMPORARY
+ INHERITED EXPLANATION
```

不显示：

- parent CENTER；
- parent TEMPORARY；
- deleted node。

Inherited node 使用 canonical `node_id`，因此 Reader、Ink、Rename、Move 都直接作用于同一对象。

## 3. 初始布局

首次 graph：CENTER `(0.5, 0.5)`。

新增 OWN 子节点使用确定性 radial slot：

```text
angle = golden_angle * insertion_index
radius = min(0.18 + ring*0.12, 0.42)
```

Inherited node 不重新生成 per-child layout；直接使用 canonical node layout。

结果是：如果用户从任一 parent/child graph 拖动 shared Explanation，该位置对所有可见该 node 的 graph 生效。

目的仅是保持单一 canonical presentation。V1 不提供 per-graph layout override。

## 4. 手势优先级

- double tap > single tap；
- long press 进入 drag，不触发 single；
- drag 过程中禁止页面导航；
- Pencil 在 Topology 页面默认不作为绘图输入，以免和节点拖动混淆。

OWN 与 INHERITED Explanation 手势一致。

## 5. Single tap sheet

字段：

- node title TextField；
- kind badge；
- visibility badge：`OWN | INHERITED`；
- persistent/temporary 状态；
- owner graph diagnostic（可隐藏在 debug/secondary text）；
- delete（CENTER 不出现）。

保存 title：先 local commit/outbox，再 dismiss。

对 INHERITED Explanation 保存 title 属于 write-through mutation；其他继承同一 node 的 graph 会看到同一标题。

## 6. Double tap

导航：

```text
ReaderRoute(node_id)
```

Reader 必须按 canonical `node_id` 恢复正文与 Ink，不按当前 graph_id、title 或 body hash。

因此 inherited Explanation 不需要 Reader 副本。

## 7. Move

OWN / INHERITED Explanation 都允许拖动。

Move 写：

```text
layouts[node_id]
```

而不是 child-specific layout。

若 stale `layout_revision`，继续沿用现有 CAS + snapshot recovery。

## 8. Delete

### 8.1 OWN Explanation

沿用现有删除流程：本地 optimistic hide + outbox；server reject 时恢复 snapshot。

### 8.2 INHERITED Explanation

V1 为 global delete：删除 canonical owner node。

提交前必须显示明确确认：

> 这是共享解释节点。删除会同时影响原题图以及所有继承该解释的问题图。

确认后才写 local delete intent + outbox。

V1 不提供“仅在当前图隐藏”。

## 9. iPad Cache 模型

继承后，同一 `node_id` 可以出现在多个 graph view，因此缓存必须分离 canonical node 与 membership。

目标：

```text
nodes_cache
- node_id PK
- owner_graph_id
- kind/title/body/node_revision
- layout

membership_cache
- graph_id
- node_id
- visibility OWN|INHERITED
- PK(graph_id,node_id)
```

加载一个 graph snapshot 时，通过 membership 找出其可见 node，再 join canonical nodes_cache。

禁止以 `nodes_cache.graph_id = current_graph` 作为可见性判断。

## 10. Offline / Reconnect

离线时 inherited node 与 own node 一样可读。

Reconnect 后：

- 若 patch 连续，按 patch 更新；
- 若 base mismatch，重新拉 effective snapshot；
- snapshot replace 只替换当前 graph membership，不应误删其他已缓存 graph 对同一 canonical node 的 membership；
- 未 ACK rename/move/delete/ink outbox 按现有机制重放。

## 11. UI 非目标

V1 不做：

- 显示完整 graph inheritance DAG；
- 在 Topology 上同时展开 parent CENTER；
- per-child node style customization；
- per-child layout；
- per-child hide inherited node。
