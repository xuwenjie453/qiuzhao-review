# Bridge E2E 模拟 iPad

## 任务目标
用 Node test 实现一个真实 WebSocket 客户端覆盖完整学习轮次。

## 必读设计稿
- `90_设计稿基线/06_质量与交付/03_测试策略.md`
- `90_设计稿基线/08_附录/02_协议样例.md`

## 必须满足
- 不能只 mock handler，至少一个真实 socket E2E。

## 实施步骤
1. connect hello
2. agent open question
3. receive snapshot durable-ack simulation
4. add explanation receive patch
5. client move ack
6. duplicate send
7. disconnect/reconnect
8. revision mismatch snapshot
9. close temp removal

## 测试要求
- 完整路径全自动通过

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
