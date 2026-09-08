# 真实 LEARN / REVIEW smoke

## 任务目标
用现有学习系统至少跑一个试题库问题和一个 review capsule 的双端流程。

## 必读设计稿
- `90_设计稿基线/05_集成与迁移/01_与现有qiuzhao-review集成.md`

## 必须满足
- 不得伪造 Learning Event。
- 若本地无真实 review capsule，使用 test fixture 层完成 identity 测试并说明。

## 实施步骤
1. LEARN open→explanation add→close。
2. REVIEW open→temporary/persistent path→close。
3. 验证 iPad/sim client active graph。

## 测试要求
- 学习核心不因 daemon offline 失败

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
