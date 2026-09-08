# WebSocket Server

## 任务目标
实现 RFC6455 server 与连接生命周期。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/02_WebSocket协议总则.md`

## 必须满足
- 严格 frame/message size。
- JSON text envelope。
- protocol error 不 crash daemon。
- session_epoch 每连接新 UUID。

## 实施步骤
1. 若复用 reading-system 零依赖 frame parser，删除其 pairing 语义。
2. 实现 ping/pong、close、parse error。

## 测试要求
- handshake
- fragment/invalid handling as supported
- oversize rejection
- disconnect cleanup

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
