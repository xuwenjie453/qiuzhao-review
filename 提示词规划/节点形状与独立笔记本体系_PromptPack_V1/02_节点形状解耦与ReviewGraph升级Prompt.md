# 02 节点形状解耦与 ReviewGraph 升级 Prompt

本步骤只处理 Review QuestionGraph 的 NodeShape，不创建 Notebook。

## 一、目标模型

新增：

```text
NodeShape
├── SQUARE
├── CIRCLE
└── TRIANGLE
```

Review `GraphNodeDTO` / Mac node canonical 必须同时拥有：

```text
kind  = 业务语义
shape = 视觉语义
```

渲染必须改为：

```text
NodeGlyph(shape)
```

而不是：

```text
NodeGlyph(kind)
```

---

## 二、默认值规则

### 新数据 creation default

```text
CENTER       -> SQUARE
EXPLANATION  -> CIRCLE
TEMPORARY    -> CIRCLE
```

### 旧数据 migration default

为了升级后保持旧图外观：

```text
旧 CENTER       -> SQUARE
旧 EXPLANATION  -> CIRCLE
旧 TEMPORARY    -> TRIANGLE
```

注意：migration default 与 creation default 不相同，尤其是 TEMPORARY。

实现时必须写测试锁死这个差异。

---

## 三、Mac canonical schema

基于当前 schema 版本增量升级，不重建已有 ID。

建议 `nodes` 新增：

```sql
shape TEXT NOT NULL
CHECK(shape IN ('SQUARE','CIRCLE','TRIANGLE'))
```

如果 SQLite add-column + CHECK/NOT NULL 的原地迁移需要分步，请优先保证：

- 旧数据库可升级；
- 旧 node_id / graph_id / parent_node_id / layout / ink 不变化；
- body immutable trigger 不破坏；
- migration 可重复启动而不损坏数据。

不要为了 shape 改 WORLD_V1 layout。

---

## 四、QuestionGraph service

所有创建 node 的路径必须显式写 shape：

- CENTER creation -> SQUARE；
- EXPLANATION creation -> CIRCLE；
- TEMPORARY creation -> CIRCLE。

snapshot / patch node payload 必须携带 `shape`。

新增 command：

```text
SET_NODE_SHAPE
```

推荐输入：

```json
{
  "node_id": "...",
  "shape": "TRIANGLE",
  "base_node_revision": 7
}
```

语义：

```text
成功：
node.shape 更新
node_revision + 1
graph_revision + 1
```

非法 shape -> VALIDATION。

CENTER 允许改 shape；shape 修改不得改变 kind、parent、body、layout、round。

---

## 五、同步协议

重新评估是否必须升级 wire protocol。

原则：

- 如果现有 protocol v3 的 JSON payload 天然允许新增可选字段，并且旧客户端会安全忽略 `shape`，可以不升级；
- 但如果旧客户端仍会按 kind 固定渲染，导致 canonical shape 丢失/错误显示，则必须升级协议并阻止旧客户端连接。

不要为了避免 protocol bump 而接受“服务端 shape 已变但旧 iPad 看不到”的语义分叉。

若升级：

- Mac `SUPPORTED_PROTOCOLS`；
- iPad `WireV1.version/supportedVersions/clientBuild`；
- HELLO/WELCOME compatibility；
- tests/fixtures 全部同步。

---

## 六、iPad domain/cache/outbox

新增 Swift：

```swift
enum NodeShape: String, Codable, CaseIterable {
    case SQUARE
    case CIRCLE
    case TRIANGLE
}
```

`GraphNodeDTO` 新增 `shape`。

ClientStore nodes cache 新增 shape 列并迁移：

```text
旧 CENTER       -> SQUARE
旧 EXPLANATION  -> CIRCLE
旧 TEMPORARY    -> TRIANGLE
```

新增 durable local mutation：

```text
localSetShape(...)
```

必须遵守现有纪律：

```text
用户修改
-> 先写本地 DB
-> queue outbox
-> optimistic UI
-> 网络发送
-> server ACK/patch
-> 清 outbox
```

不能绕过 ClientStore 直接发网络。

---

## 七、UI

`NodeGlyph` 改为只接受 `NodeShape`。

它不得 import / switch `NodeKind`。

节点管理 sheet 增加形状选择：

```text
□ 方形
○ 圆形
△ 三角形
```

要求：

- 任意节点都可以选择任意形状；
- CENTER 不例外；
- shape picker 不影响 rename/delete/move/ink；
- shape 切换不改变 node center，不触发布局重算；
- parent-child link anchor 仍以节点中心为准。

---

## 八、绝对禁止

禁止以下伪修复：

```text
shape 不落库，只保存在 SwiftUI @State
shape 由 title 推断
shape 由 kind 继续推断，只增加 override
TEMPORARY 永久硬编码三角形
CENTER 永久禁止改形状
改 shape 时创建新 node
改 shape 时改 graph layout
```

必须真正把 shape 做成 canonical node metadata。

---

## 九、测试

至少覆盖：

1. 新 CENTER 默认 SQUARE；
2. 新 EXPLANATION 默认 CIRCLE；
3. 新 TEMPORARY 默认 CIRCLE；
4. 旧 TEMPORARY migration 后仍 TRIANGLE；
5. SET_NODE_SHAPE 成功 + revision 增长；
6. 非法 shape 被拒绝；
7. shape 不改变 kind/parent/body/layout；
8. snapshot / patch shape round-trip；
9. iPad cache/offline reload 后 shape 保留；
10. outbox 重放幂等；
11. NodeGlyph 渲染由 shape 驱动而非 kind。
