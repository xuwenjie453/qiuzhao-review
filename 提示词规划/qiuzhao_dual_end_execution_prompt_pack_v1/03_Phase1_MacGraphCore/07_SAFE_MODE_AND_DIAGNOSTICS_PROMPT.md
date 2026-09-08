# SAFE_MODE 与诊断

## 任务目标
让数据库损坏、bridge 失败可被准确区分。

## 必读设计稿
- `90_设计稿基线/02_Mac端/01_Mac守护进程.md`
- `90_设计稿基线/06_质量与交付/01_状态机.md`

## 必须满足
- store integrity failure 进入 SAFE_MODE。
- SAFE_MODE 允许 query/export，不接受 mutation。
- bridge/Bonjour failure 可 DEGRADED，不能误伤 core。
- 日志不写完整 body/ink。

## 实施步骤
1. 实现 health snapshot。
2. 实现 structured log/redaction。
3. 实现 safe mode mutation guard。

## 测试要求
- corrupt/integrity simulated
- mutation rejected in safe mode
- query works

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
