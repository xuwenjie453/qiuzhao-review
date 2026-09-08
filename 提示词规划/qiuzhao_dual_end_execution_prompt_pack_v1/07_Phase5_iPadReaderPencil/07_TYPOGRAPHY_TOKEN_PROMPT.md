# Reader Typography Token

## 任务目标
集中所有阅读排版参数，并保持 PDF 校准可后置。

## 必读设计稿
- `90_设计稿基线/04_iPad端/04_阅读排版Token.md`

## 必须满足
- 所有字号/留白集中。
- 当前缺 PDF 时不声称匹配。
- 后续只调 token 不改 reader architecture。

## 实施步骤
1. 实现 `ReaderTypography`。
2. 提供合理开发默认值但明确命名为 development/default，不称 reference-matched。
3. 在验收表标 blocked。

## 测试要求
- token centralization
- layout signature changes when token changes

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
