# 崩溃恢复

## 任务目标
验证 daemon/iPad 在关键事务点崩溃不会破坏 canonical state。

## 必读设计稿
- `90_设计稿基线/02_Mac端/04_存储与数据库.md`
- `90_设计稿基线/06_质量与交付/02_失败矩阵.md`

## 必须满足
- 未 commit 不 ACK。
- 旧 active round recovery interrupt。

## 实施步骤
1. 模拟 command transaction fail。
2. kill daemon after commit before client receive。
3. reconnect duplicate replay。
4. 检查 temp 不复活。

## 测试要求
- integrity passes
- one effect

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
