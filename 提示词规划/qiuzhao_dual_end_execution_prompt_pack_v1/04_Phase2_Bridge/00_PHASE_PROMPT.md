# Phase 2 — Bonjour + WebSocket Bridge — Phase 总控 Prompt

## 目标
把 Mac canonical graph 通过稳定 v1 协议同步给模拟 iPad，并接受 ClientCommand/Ink。

## 开始前必须阅读
- `90_设计稿基线/03_协议与同步/*`
- Phase0 protocol fixtures
- Phase1 command service

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- daemon 广播 `_qiuzhaoreview._tcp`。
- WebSocket HELLO/WELCOME/session_epoch/server_seq 实现。
- Snapshot/Patch/reconnect/dedup/ACK 实现。
- Node 模拟 iPad E2E 覆盖。
