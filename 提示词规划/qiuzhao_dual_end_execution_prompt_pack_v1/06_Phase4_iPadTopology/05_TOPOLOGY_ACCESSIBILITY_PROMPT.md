# Topology 可访问性与交互质量

## 任务目标
保证形状不是唯一的信息载体，手势有替代操作。

## 必读设计稿
- `90_设计稿基线/04_iPad端/02_问题图Topology设计.md`

## 必须满足
- VoiceOver label 包含 kind/title。
- 管理操作可通过 accessibility action。
- 触控 hit target 合理。

## 实施步骤
1. 添加 accessibilityLabel/value/actions。
2. 验证动态文字不会破坏节点命中。

## 测试要求
- basic accessibility inspection

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
