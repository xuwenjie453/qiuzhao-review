# Topology 手势优先级

## 任务目标
实现 single/double/long-press drag 且无串扰。

## 必读设计稿
- `90_设计稿基线/04_iPad端/02_问题图Topology设计.md`

## 必须满足
- double > single。
- long press→drag 不触发 single。
- drag 不导航。
- Topology Pencil 默认不画。

## 实施步骤
1. 优先使用 SwiftUI/UIKit 可验证的 gesture coordination。
2. 为 reducer/gesture state 写 tests。

## 测试要求
- double opens reader only
- single opens manage only
- long drag move only

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
