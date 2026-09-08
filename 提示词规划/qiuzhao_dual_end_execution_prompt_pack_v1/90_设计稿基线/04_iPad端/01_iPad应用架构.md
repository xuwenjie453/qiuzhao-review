# iPad App 架构

## 1. 技术栈

- Swift / SwiftUI：App shell、Topology、管理 sheet。
- UIKit bridge：PencilKit Reader 与精确手势协调。
- PencilKit：Ink。
- Network.framework：Bonjour `NWBrowser`。
- `URLSessionWebSocketTask`：WebSocket client。
- SQLite3：本地 durable cache/outbox/inbox。
- 零第三方依赖作为优先目标，降低协议和渲染依赖漂移。

## 2. 模块

```text
DualEnd-iPad/App/
  App/
  Domain/
  Protocol/
  Connectivity/
  Sync/
  Store/
  Topology/
  Reader/
  Pencil/
  Diagnostics/
```

## 3. ViewModel 状态

`AppSessionModel`：connection, activeGraphID, activeRoundID。

`QuestionGraphModel`：snapshot + node selection + local drag transient position。

`ReaderModel`：node content + ink loading/saving + tool state。

所有 canonical data 读取应从 `ClientStore` actor 获取；网络层不直接持有 UI mutable state。

## 4. 启动

```text
open local db
 -> load cached active graph
 -> immediately render cache
 -> request local-network access via browser start
 -> auto discover/connect
 -> sync reconcile
```

这样即使 Mac 尚未启动，iPad 仍能查看上次节点和笔迹。
