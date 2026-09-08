# LAN 重连 torture

## 任务目标
验证 Wi-Fi 抖动、daemon restart、App foreground/background 下的一致性。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/05_离线重连与恢复.md`

## 必须满足
- 离线不空白。
- outbox 不丢。
- duplicate one effect。

## 实施步骤
1. 在 rename/move/ink pending 时断开。
2. daemon restart。
3. 重连后 snapshot/replay。
4. 重复同 message/command。

## 测试要求
- canonical state equals expected

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
