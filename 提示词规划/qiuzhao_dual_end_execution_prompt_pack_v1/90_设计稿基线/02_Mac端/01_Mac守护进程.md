# Mac 守护进程设计

## 1. 定位

新增 `DualEnd-Mac/`，它是**伴生守护进程**，不取代 `学习系统/` Python 包。

推荐沿用 reading-system 已验证的 Node.js 26 零第三方依赖方向：

- `node:sqlite`：新双端 store；
- `node:http`/`node:net`：本机控制接口 + WebSocket server；
- `node:crypto`：hash、UUID、握手 nonce；
- `/usr/bin/dns-sd` 或同等 Bonjour 注册机制；
- 自实现最小 RFC6455 framing 可直接按 reading-system bridge 模块重用思想。

若实施者决定全部用 Python，也必须保持本文协议和不变量；语言不是产品契约。

## 2. 进程职责

```text
Daemon
├── LocalControlServer    仅 localhost，Agent CLI 使用
├── QuestionGraphService  graph/round/node command
├── GraphStore            SQLite WAL
├── BridgeServer          WebSocket
├── BonjourAdvertiser
├── SyncJournal
└── Health/Diagnostics
```

## 3. 生命周期

```text
STARTING
 -> OPEN_STORE
 -> RECOVER_JOURNAL
 -> INTEGRITY_CHECK
 -> START_LOCAL_CONTROL
 -> START_BRIDGE
 -> ADVERTISE_BONJOUR
 -> READY
```

任一 canonical store integrity failure：进入 `SAFE_MODE`，允许 query/export，不接受 mutation；不要以空库覆盖。

## 4. 单实例

daemon 使用 runtime lock：`系统数据/dual-end/runtime/daemon.lock`。第二实例发现有效 PID/lock 后退出，避免两进程同时广播和写 store。

## 5. 建议目录

```text
DualEnd-Mac/
  bin/qreview-dual.mjs
  src/
    daemon.mjs
    control/
    graph/
    bridge/
    store/
    protocol/
    diagnostics/

系统数据/dual-end/
  state/dual-end.db
  runtime/
  logs/
  recovery/
```
