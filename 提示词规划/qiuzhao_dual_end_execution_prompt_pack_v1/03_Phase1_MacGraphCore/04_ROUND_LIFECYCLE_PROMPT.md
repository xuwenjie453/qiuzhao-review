# Question Round 生命周期

## 任务目标
实现 open/close/interrupted/temporary 过滤与 crash recovery。

## 必读设计稿
- `90_设计稿基线/01_产品与领域/05_问题身份与轮次生命周期.md`

## 必须满足
- 全系统只允许一个 ACTIVE round。
- open 新题前中断旧 active。
- temporary 只在其 round 可见。
- close/interrupt 后 temporary expired。

## 实施步骤
1. 实现 recovery pass。
2. 实现 snapshot visible filter。
3. 明确 close 幂等。

## 测试要求
- close removes temp
- reopen same question no old temp
- persistent remains
- crash simulated active recovery

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
