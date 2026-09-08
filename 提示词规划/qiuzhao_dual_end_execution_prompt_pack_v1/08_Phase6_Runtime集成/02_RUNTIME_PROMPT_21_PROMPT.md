# 新增 RuntimePrompt 双端协作协议

## 任务目标
新增设计指定的 `21_双端问题图与iPad协作协议.md`（或实际编号等价），并接入总控。

## 必读设计稿
- `90_设计稿基线/05_集成与迁移/02_RuntimePrompt改造.md`

## 必须满足
- 明确 open/add/close。
- 普通解释不入图。
- 模糊指代最小澄清。
- body exact span。
- CLI 成功后再确认。

## 实施步骤
1. 写完整 runtime prompt。
2. 在 00 总控与启动接管文件加入引用。
3. 提供 positive/negative examples。

## 测试要求
- Prompt QA 人工/自动 grep 条件

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
