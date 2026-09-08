# Phase 1 测试闸门

## 任务目标
在没有任何 iPad/网络情况下证明 graph core 正确。

## 必读设计稿
- `90_设计稿基线/06_质量与交付/03_测试策略.md`

## 必须满足
- 必须有 automated tests。

## 实施步骤
1. 运行全部 DualEnd-Mac unit tests。
2. 用 CLI 建一题、加 persistent/temp、close、reopen，检查结果。
3. 运行原 qiuzhao baseline regression。

## 测试要求
- 所有 Phase1 tests
- 原系统 baseline 不新增 failure

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
