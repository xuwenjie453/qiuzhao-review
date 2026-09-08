# WebSocket v1 Wire Fixtures

## 任务目标
在任何 bridge/iPad decoder 实现前冻结共享 JSON fixtures。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/02_WebSocket协议总则.md`
- `90_设计稿基线/03_协议与同步/03_GraphSnapshot与Patch.md`
- `90_设计稿基线/08_附录/02_协议样例.md`

## 必须满足
- Envelope 必含 v/message_id/type/session_epoch/sent_at/payload。
- 消息类型覆盖 HELLO/WELCOME/SNAPSHOT/PATCH/CLIENT_COMMAND/INK/ACK/ERROR/PING/PONG。
- optional field 只能向后兼容地增加。
- 未知 type 不 crash；unsupported version 明确拒绝。

## 实施步骤
1. 创建 `fixtures/protocol-v1/` 或等价目录。
2. 为每类消息给 valid fixture 和至少一个 invalid fixture。
3. 字段 naming 在 Node/Swift 保持一致。
4. 为二进制 Ink 约定 base64/独立 frame 的实际 wire representation，若设计未冻结则选择最简单可测方案，并在契约中记录；不得改变 full PKDrawing snapshot 语义。

## 测试要求
- Node decoder 后续对 fixtures 全部通过
- Swift decoder 后续读取同一 fixtures
- invalid version/type/size 有预期行为

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
