# SyncEngine

## 任务目标
实现 durable apply→ACK、outbox replay、revision recovery。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/03_GraphSnapshot与Patch.md`
- `90_设计稿基线/03_协议与同步/04_ClientCommand与冲突处理.md`
- `90_设计稿基线/03_协议与同步/05_离线重连与恢复.md`

## 必须满足
- ACK 只在 ClientStore commit 后。
- patch base mismatch→snapshot request。
- socket send 不是完成。
- old epoch ack ignored。

## 实施步骤
1. 实现 message dispatch。
2. snapshot transaction replace。
3. patch apply。
4. outbox sender serialization。
5. active graph state。

## 测试要求
- duplicate server message
- base mismatch
- reconnect replay
- old epoch ignored

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
