# Agent 双端 CLI

## 任务目标
提供 Agent 稳定调用接口，隐藏 HTTP 细节。

## 必读设计稿
- `90_设计稿基线/02_Mac端/05_本机控制API.md`

## 必须满足
- CLI 只是 client，不直写 DB。
- machine-readable JSON mode。
- human diagnostics mode。

## 实施步骤
1. 实现 open/add/close/status。
2. 输出稳定 exit codes。
3. 正文支持 stdin/file，避免 shell escaping 破坏 Markdown。

## 测试要求
- markdown exact roundtrip
- daemon offline exit code

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
