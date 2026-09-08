# 最终 diff 审查

## 任务目标
以产品不变量而不是代码美观为核心审查整个改动。

## 必读设计稿
- `90_设计稿基线/06_质量与交付/06_AI代码审查清单.md`

## 必须满足
- 无无关大改。

## 实施步骤
1. git diff --stat。
2. 检查 scheduler/engine schema 无意修改。
3. 检查 body update path。
4. 检查 ACK order。
5. 检查 pairing remnants。

## 测试要求
- all blockers resolved or reported

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
