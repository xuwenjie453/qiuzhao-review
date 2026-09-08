# PKDrawing 本地持久化

## 任务目标
实现每 node 一份 drawing，低延迟显示、异步 durable save。

## 必读设计稿
- `90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`
- `90_设计稿基线/04_iPad端/06_iPad本地数据库.md`

## 必须满足
- `PKDrawing.dataRepresentation()` opaque bytes。
- 300–500ms debounce 只优化 I/O。
- disappear/background force flush。
- 重 I/O 不阻塞 MainActor。

## 实施步骤
1. dirty tracking。
2. serialize off main where API permits；SQLite actor durable write。
3. increment local ink_revision + outbox。

## 测试要求
- kill/relaunch
- rapid strokes while save
- node switch flush

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
