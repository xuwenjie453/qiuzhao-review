# ClientCommand CAS 与 ACK

## 任务目标
接收 iPad rename/move/delete，按实体 revision CAS。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/04_ClientCommand与冲突处理.md`

## 必须满足
- rename/delete 用 node_revision。
- move 用 layout_revision。
- CENTER delete reject。
- ACK 含 canonical revisions。

## 实施步骤
1. 解析 CLIENT_COMMAND。
2. 调用 command service，不直写 DB。
3. 映射 conflict/retryable error。

## 测试要求
- concurrent add + move both succeed
- stale move returns current
- center delete rejected
- duplicate command one effect

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
