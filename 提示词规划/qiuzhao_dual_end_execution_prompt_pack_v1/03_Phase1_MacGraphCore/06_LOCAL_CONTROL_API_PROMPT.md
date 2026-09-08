# localhost Control API

## 任务目标
为 Agent/CLI 提供唯一合法 mutation 边界。

## 必读设计稿
- `90_设计稿基线/02_Mac端/05_本机控制API.md`

## 必须满足
- 仅 127.0.0.1。
- 标准 JSON error。
- 不暴露 stack trace。
- 所有 handler 调 command service。

## 实施步骤
1. 实现 status/open/close/node.add/graph query。
2. 加入 body/Ink size limit 前置校验。
3. 实现 CLI wrapper。

## 测试要求
- remote bind absent
- invalid payload 400
- domain error stable
- API duplicate command idempotent

## 禁止捷径
- 禁止 handler 直接 SQL。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
