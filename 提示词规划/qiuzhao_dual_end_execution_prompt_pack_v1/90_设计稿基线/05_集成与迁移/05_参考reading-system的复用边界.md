# reading-system 复用边界

## 直接借鉴

- Mac daemon / iPad client 双端分工；
- Bonjour discovery；
- WebSocket 长连接；
- iPad local SQLite；
- inbox/outbox；
- Snapshot/Patch；
- revision mismatch → snapshot recovery；
- message_id dedup；
- durable before emit / durable before ACK；
- session_epoch；
- PencilKit 原生书写；
- cached content 在离线时仍可读。

## 需要修改

reading-system 当前有 6 位配对码；本项目必须移除，改成自动连接。

reading-system 的 Topology 是 Book/Block/Node 内容图；本项目的图固定是 Question + Explanation/Temporary 三种 node，语义完全不同。

reading-system 的 Reader 支持 append-only EXTEND；本项目 Node Body 一经创建绝对不变，所以 Reader 更简单，但 Ink 的稳定坐标要求更强。

## 明确不复用

- Reading Interest/Timing Scheduler；
- Reading Core 的书籍 Parser pipeline；
- Block/Graph Focus 语义；
- Curator CREATE/EXTEND；
- Reading Semantic Work Broker 作为本次必需重构。

后者未来可用于增强 Agent runtime，但不属于“只做双端更新”的本次 scope。
