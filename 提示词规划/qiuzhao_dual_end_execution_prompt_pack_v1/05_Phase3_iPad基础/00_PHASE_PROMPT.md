# Phase 3 — 新建 iPad App + Cache/Sync Shell — Phase 总控 Prompt

## 目标
从零建立完整 iPadOS Xcode 工程，并先完成 Domain/Protocol/Store/Connectivity/Sync/Root UX。此阶段不是 mock UI。

## 开始前必须阅读
- `90_设计稿基线/04_iPad端/01_iPad应用架构.md`
- `90_设计稿基线/04_iPad端/06_iPad本地数据库.md`
- `90_设计稿基线/04_iPad端/07_连接状态与UX.md`
- `90_设计稿基线/03_协议与同步/*`
- Phase0 fixtures

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- 仓库内存在可打开的 Xcode project。
- iPad 冷启动先读 cache。
- NWBrowser 自动发现。
- URLSessionWebSocketTask 自动连接。
- ClientStore actor + inbox/outbox。
- SyncEngine 可与真实 Mac daemon 互通。
- 无 PairingView / IP 输入。
