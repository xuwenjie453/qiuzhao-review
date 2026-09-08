# Journal replay / reconnect

## 任务目标
实现重连后 server replay 或 snapshot recovery。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/05_离线重连与恢复.md`

## 必须满足
- last_server_seq 只作 checkpoint，不替代 graph revision。
- journal 不够时 snapshot。
- active graph change 优先通知。

## 实施步骤
1. 设计 replay window。
2. 实现 device last ack checkpoint。
3. 测试断线期间多 mutation。

## 测试要求
- disconnect-mutate-reconnect
- journal pruned snapshot fallback

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
