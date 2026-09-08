# Agent → Daemon 命令契约

## 任务目标
冻结 Runtime Prompt 与 localhost API 之间的 open/add/close 语义。

## 必读设计稿
- `90_设计稿基线/02_Mac端/02_Agent接入契约.md`
- `90_设计稿基线/05_集成与迁移/02_RuntimePrompt改造.md`

## 必须满足
- Agent 负责识别用户指定的解释 span。
- Daemon 不做语义挑选。
- node.add body 必须 exact assistant explanation markdown。
- initial title 由当前 Agent 生成。
- CLI/API 成功后 Agent 才可确认已加入。
- Daemon unavailable 不阻断学习核心。

## 实施步骤
1. 定义 request/response JSON。
2. 定义 error code 表。
3. 定义 persistent vs temporary 的显式参数。
4. 定义 open 前/close 后 round 行为。
5. 准备 Runtime Prompt 示例：明确/模糊/普通追问三类。

## 测试要求
- 普通解释绝不创建 node
- 模糊指代不得一次加两个
- daemon 失败不能伪报成功

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
