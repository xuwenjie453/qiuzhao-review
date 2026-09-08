# Active Graph 自动切换

## 任务目标
当 Mac 开始新问题时 iPad 自动展示新 active graph，同时保留旧 cache。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/05_离线重连与恢复.md`

## 必须满足
- ACTIVE_GRAPH_CHANGED 优先。
- 旧 graph 不删除。
- 旧 temporary 不在新 round snapshot。

## 实施步骤
1. 实现 navigation state transition。
2. 处理 user 正在 Reader 时的新 active graph：按设计主界面当前问题语义处理，不把旧 epoch stale event 抢页。若设计未指定细节，采用可预测且可回退的最小行为并记录。

## 测试要求
- switch graph
- offline then reconnect new active
- old cache remains

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
