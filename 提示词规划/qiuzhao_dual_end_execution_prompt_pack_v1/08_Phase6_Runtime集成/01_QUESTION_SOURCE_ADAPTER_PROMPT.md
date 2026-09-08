# QuestionRef Source Adapter

## 任务目标
把试题库和 Review Capsule 转换为稳定双端 QuestionRef。

## 必读设计稿
- `90_设计稿基线/05_集成与迁移/01_与现有qiuzhao-review集成.md`
- `90_设计稿基线/01_产品与领域/05_问题身份与轮次生命周期.md`

## 必须满足
- questions DB 仍只读。
- Review 仅加身份适配，不改调度。

## 实施步骤
1. 定位 TaskIntent 当前携带的题目 ID。
2. 定位 review capsule/probe identity。
3. 实现 thin adapter/CLI serializer。

## 测试要求
- LEARN question ref
- REVIEW question ref
- same identities stable

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
