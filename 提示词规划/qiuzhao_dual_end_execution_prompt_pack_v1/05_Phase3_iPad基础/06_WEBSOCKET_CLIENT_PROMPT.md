# URLSessionWebSocketTask Client

## 任务目标
实现自动连接、收发、heartbeat、reconnect。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/02_WebSocket协议总则.md`
- `90_设计稿基线/03_协议与同步/05_离线重连与恢复.md`

## 必须满足
- connection callbacks 不直接改 View。
- session epoch 每次重连刷新。
- 指数退避。
- 前台重连，后台不承诺常驻。

## 实施步骤
1. 实现 BridgeConnection actor/object。
2. receive loop typed decode。
3. 断开通知 SyncEngine。

## 测试要求
- connect to real Mac daemon
- disconnect/reconnect
- malformed frame safe

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
