# HELLO/WELCOME 与 session epoch

## 任务目标
实现连接协商、device state 与 active graph 初始同步。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/02_WebSocket协议总则.md`
- `90_设计稿基线/03_协议与同步/05_离线重连与恢复.md`

## 必须满足
- unsupported protocol 明确拒绝。
- WELCOME 含 daemon_id/session_epoch/server_seq/active。
- 旧 epoch response 不跨新会话生效。

## 实施步骤
1. 实现 session object。
2. 更新 device last_seen。
3. 根据 cached revision 决定 replay/snapshot。

## 测试要求
- valid hello
- unsupported version
- new epoch each reconnect

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
