# Swift Protocol Layer

## 任务目标
让 Swift 对 Phase0 wire fixtures 100% 对齐。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/02_WebSocket协议总则.md`

## 必须满足
- Envelope version/type/session_epoch。
- 未知可选字段容忍。
- unsupported semantics 可返回 typed error。

## 实施步骤
1. 把 shared fixtures 加到 test target。
2. 实现 decode/encode。
3. 避免 `Any` dictionary 到处传播。

## 测试要求
- all valid fixtures
- invalid fixtures

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
