# 外部参考核验（2026-09-08）

本文件记录实施提示词包生成时核验到的公开实现事实，只作参考，不覆盖 Canonical Design。

## qiuzhao-review
公开仓库：
https://github.com/xuwenjie453/qiuzhao-review

当前根目录包含：
- Algorithms/
- Knowledge/
- Projects/
- 学习系统/
- 提示词规划/
- 试题库/
- scheduler.sqlite3
- AGENTS.md / README.md

当前 AGENTS 明确旧版本是 Agent-native，并写有“不要做 Web/App 产品化”的旧限制。本次设计稿已经明确 supersede 该限制的相关部分：不重构学习核心，但**本版本必须开发 iPad Reader App**。

## reading-system
公开仓库：
https://github.com/xuwenjie453/reading-system

当前拥有：
- ReadingSystem-Mac/
- ReadingSystem-iPad/
- 提示词迭代库/

可参考：
- Node.js daemon；
- SQLite WAL；
- durable-before-ACK；
- message dedup；
- journal；
- Bonjour + WebSocket；
- SwiftUI/PencilKit；
- ClientStore/outbox；
- Snapshot/Patch。

禁止复制其与本项目冲突的旧体验：
- 6 位配对码；
- 手动 IP 兜底；
- Reading ContentGraph 的业务语义；
- Reading Focus/Curator/Scheduler 到本项目。

## Apple 官方
PencilKit：
https://developer.apple.com/documentation/pencilkit
`PKCanvasView` 提供 Apple Pencil/触控的低延迟绘制，`PKDrawing` 可持久化。

Apple Pencil interactions：
https://developer.apple.com/documentation/uikit/uipencilinteraction
支持的 Apple Pencil 可通过 `UIPencilInteraction` 接收 double tap；第一代 Apple Pencil 不支持该硬件 interaction。

Network / Bonjour：
https://developer.apple.com/documentation/network/nwbrowser
https://developer.apple.com/documentation/network/nwlistener
iPad 本地网络浏览需处理 `NSLocalNetworkUsageDescription` / `NSBonjourServices` 等系统权限配置。

实现 API 细节若 SDK 已更新，以当前 Xcode SDK 编译器与 Apple 官方文档为准，但不得改变产品行为。
