# Swift Domain Models

## 任务目标
实现 QuestionGraph/Node/Layout/Ink metadata/ActiveState 等值类型。

## 必读设计稿
- `90_设计稿基线/01_产品与领域/04_问题图领域模型.md`

## 必须满足
- kind enum 严格三类。
- body 对 UI 无 setter/mutation path。
- IDs/string 与 wire 对齐。

## 实施步骤
1. 实现 Codable/Equatable 模型。
2. 分离 cache row 与 domain DTO 时写 mapper tests。

## 测试要求
- fixture decode
- temporary round rules mapping

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
