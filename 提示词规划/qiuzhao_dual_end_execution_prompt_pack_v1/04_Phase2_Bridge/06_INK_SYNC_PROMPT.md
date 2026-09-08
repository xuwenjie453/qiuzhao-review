# Ink full snapshot 同步

## 任务目标
实现 iPad→Mac 的 full PKDrawing opaque snapshot 备份。

## 必读设计稿
- `90_设计稿基线/01_产品与领域/04_问题图领域模型.md`
- `90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`

## 必须满足
- ink revision 独立。
- same revision+same hash 幂等。
- lower ignore/ack semantics 明确。
- gap 返回 INK_REVISION_GAP。
- blob 上限。

## 实施步骤
1. 选定 wire encoding。
2. store hash/blob transaction。
3. 返回 ack canonical revision。

## 测试要求
- rev1
- duplicate rev1 same hash
- duplicate rev1 diff hash reject
- gap
- oversize

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
