# Ink 网络同步与 revision

## 任务目标
连接 iPad local drawing 与 Mac ink.put。

## 必读设计稿
- `90_设计稿基线/02_Mac端/03_问题图命令服务.md`
- `90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`

## 必须满足
- full snapshot v1。
- local first。
- ACK 清 outbox。
- gap 时发送当前 full snapshot。

## 实施步骤
1. 实现 ink outbox sender。
2. 避免 graph patch 与 ink revision 相互阻塞。
3. server backup 可用于新设备/cache miss 恢复。

## 测试要求
- offline write reconnect
- duplicate ink
- gap recovery

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
