# Stop Conditions Prompt

以下情况必须停止继续扩展代码，先报告问题：

1. 两份权威设计对同一核心语义直接冲突。
2. 发现真实生产/用户 DB schema 与 repo 假设不同，migration 可能 destructive。
3. 无法稳定确定 primary source，且业务要求自动继承；此时不得猜。
4. 修改 inheritance 必须破坏 body immutable/CAS/dedup/durable 等冻结不变量才能继续。
5. wire 兼容要求不明确且旧 client 可能 silent corrupt cache。
6. test failure 表明已有主干存在独立数据损坏风险，无法区分 regression。
7. 用户工作区有未提交改动会被覆盖。

以下情况**不是**停止理由，应自行继续：
- 测试普通失败；
- 编译错误；
- fixture 需要同步；
- migration test 暴露 bug；
- 需要新增小型 helper；
- 代码比预计多几个文件。
