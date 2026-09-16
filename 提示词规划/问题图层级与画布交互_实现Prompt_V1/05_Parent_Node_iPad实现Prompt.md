# 05 — Parent Node：iPad Protocol / Cache / Render 实现 Prompt

前提：Mac canonical 已按 `04` 输出 optional `parent_node_id`。本阶段让 iPad 在在线 patch、全量 snapshot、离线 cache、App 重启后都保持同一层级关系。

## 1. Domain DTO

在 `GraphNodeDTO` 增加：

```swift
let parentNodeId: String?
```

CodingKey：

```text
parent_node_id
```

为兼容现有 Swift tests/构造调用，initializer 可给 `parentNodeId: String? = nil` 默认值，但不要用 initializer 默认值篡改 wire 含义。

CENTER 的值应为 nil。旧 server/snapshot 不带字段时 decode 为 nil。

## 2. GraphCodec

`GraphCodec.node(from:)` 读取 optional：

```text
parent_node_id
```

缺失时仍成功 decode。不要因为 parent 缺失把整个 snapshot 判 malformed。

Snapshot 的 backward-compat 语义：

```text
node.parentNodeId == nil 且 node != CENTER
→ presentation 视为 snapshot.centerNodeId
```

注意：fallback 是消费层规则，不要在 codec 中伪造一个 parent 字符串。

## 3. iPad durable cache migration

给 `nodes_cache` additive 增加 nullable：

```sql
parent_node_id TEXT
```

更新 fresh schema 和 `migrate()`：

```text
PRAGMA table_info(nodes_cache)
若缺列 → ALTER TABLE ADD COLUMN parent_node_id TEXT
```

不要求清空 cache，不删除用户 ink/outbox/layout。

旧 cache 行 parent=NULL 继续由 UI fallback CENTER。

## 4. Snapshot apply / loadSnapshot

所有 node cache UPSERT/SELECT 路径都要覆盖 parent：

- `applySnapshot` 写 `parent_node_id`；
- `loadSnapshot` 还原到 `GraphNodeDTO.parentNodeId`；
- 本地存在 pending rename/move 时，server parent 仍应更新，因为 V1 没有本地 reparent intent；不要把 parent 当作 pending UI mutation 保留旧值。

检查 SQL column/value 数量严格一致，避免静默 `try?` 掩盖 insert 失败。若当前 store 广泛使用 `try?`，测试必须能暴露 schema/SQL 错位。

## 5. Patch apply

`ADD_NODE` 的 `GraphCodec.node` decode 后，在 `nodes_cache` 写入 parent。

必须满足：

> 新 child 通过在线 GRAPH_PATCH 到达时，用户立即看到正确 parent link，不需要等下一次 snapshot。

现有 `UPDATE_TITLE` / `UPDATE_LAYOUT` / `REMOVE_NODE` 不需要增加 reparent op。

## 6. Rendering：从星形改为 resolved parent links

不要再假设所有 non-center 节点直接连 CENTER。

建议在 `GraphSnapshotDTO` 或 View 层提供纯 helper，例如：

```swift
func resolvedParent(of node: GraphNodeDTO) -> GraphNodeDTO? {
    guard !node.isCenter else { return nil }
    if let pid = node.parentNodeId,
       let visibleParent = nodes.first(where: { $0.nodeId == pid }) {
        return visibleParent
    }
    return center()
}
```

绘制：

```text
for each non-center visible node:
    parent = resolvedParent(node)
    draw parent → node
```

### Fallback 规则

以下情况都只在 presentation fallback 当前 snapshot CENTER：

- 旧 snapshot 没 parent；
- 旧 local cache parent=NULL；
- canonical parent 已 deleted，不在 visible nodes；
- inherited child 的 raw parent 是源 graph CENTER，而该 CENTER 不在 Review effective snapshot；
- cache/sync 暂时不完整。

**不得**因此写回 Mac、更新 nodes_cache parent 为 center、生成 command。

### Inheritance

若 inherited child 的 `parent_node_id` 指向另一个同样 visible 的 inherited EXPLANATION，则应正常连接 inherited parent → inherited child。只有 parent 不可见时才 fallback Review CENTER。

OWN Review explanation 不可能合法创建在 inherited parent 下；该约束由 Mac same-graph validation 保证。

## 7. 与 Canvas Pan 集成

父子 links 和 nodes 必须处于同一个 pannable canvas layer。

原则：

```text
base graph geometry 先解析 parent-child start/end
→ inner layer 一次性应用 viewport offset
```

不要：

- link 自己加 offset + layer 又加 offset；
- parent resolution 使用视觉 offset 后的 ID/坐标；
- 把 hierarchy 与 layout persistence 混在一起。

## 8. Layout

Correctness Must：连线关系正确。

UX 可选优化：新 child 初始位置靠近 parent。只有在不显著扩大改动面、测试可控时才做。若做：

- server `_radialSlot` 可扩展成基于 parent layout + sibling index 的 deterministic child slot；
- 仍 clamp 到 normalized bounds；
- 用户 drag 后照常 USER_PINNED。

**此优化不是完成 Parent Node 的必要条件。** 不要为了“漂亮布局”阻塞核心功能。

## 9. iPad tests（MUST 在代码层覆盖可测逻辑）

至少验证：

1. GraphCodec：有 parent / 无 parent 都 decode；
2. DTO old payload compatibility；
3. ClientStore fresh schema 有 parent column；
4. legacy cache migration 不丢现有 row；
5. snapshot apply → App reload/loadSnapshot 后 parent 仍在；
6. ADD_NODE patch → parent 立即写 cache；
7. `resolvedParent`: explicit visible parent；
8. missing parent → CENTER；
9. inherited parent visible → 连接 inherited parent；
10. inherited source CENTER 不可见 → current CENTER fallback；
11. parent deleted/absent → child 仍显示且 fallback center；
12. 与 Canvas Pan 同时开启时 link/node transform 一致。

如果 UI gesture 难直接 unit test，把 parent resolution 与 coordinate transform 抽成纯 helper 测试，不要为了测试引入复杂 ViewModel 重构。

## 10. 完成条件

以下路径 parent 关系必须一致：

```text
Mac DB
  ↓
Snapshot / ADD_NODE Patch
  ↓
iPad GraphCodec
  ↓
ClientStore durable cache
  ↓
GraphNodeDTO
  ↓
QuestionGraphView link rendering
```

任何一层遗漏都算未完成。
