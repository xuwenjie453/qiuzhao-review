# 完整测试矩阵

## 任务目标
汇总并执行 Mac/Python/Swift/UI/E2E 全测试。

## 必读设计稿
- `90_设计稿基线/06_质量与交付/03_测试策略.md`

## 必须满足
- 测试命令可复现。

## 实施步骤
1. 跑原 qiuzhao tests。
2. 跑 DualEnd-Mac tests。
3. 跑 protocol fixture tests。
4. 跑 xcodebuild unit/UI tests（环境允许）。
5. 跑真实 Mac↔iPad/simulator E2E。

## 测试要求
- 无新增 regression

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
