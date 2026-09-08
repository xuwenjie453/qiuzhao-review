# Graph Snapshot / Patch

## 任务目标
把 graph 变化转换成 canonical snapshot/patch。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/03_GraphSnapshot与Patch.md`

## 必须满足
- snapshot 不含 deleted/旧 temporary。
- snapshot 必含 center。
- patch base/target revision 连续。
- body 可随 snapshot/add node 下发。

## 实施步骤
1. 为每个 command 定义 patch op。
2. bridge 仅在 commit 后读取 journal/emit。
3. 实现 snapshot request。

## 测试要求
- add/rename/move/delete patch
- close temp remove patch
- snapshot filters

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
