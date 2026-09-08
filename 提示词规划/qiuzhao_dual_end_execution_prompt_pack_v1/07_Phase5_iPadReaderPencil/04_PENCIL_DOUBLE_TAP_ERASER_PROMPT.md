# Apple Pencil 双击切橡皮擦

## 任务目标
实现硬件 double tap 的 ink↔eraser toggle。

## 必读设计稿
- `90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`

## 必须满足
- 使用 `UIPencilInteraction`。
- 第一次从 ink 进入 eraser。
- 再次返回 previous ink。
- 一代 Pencil 不支持不算失败。

## 实施步骤
1. 按当前 SDK delegate API 编译实现。
2. 保留 UI tool picker/按钮作为不支持硬件的手工工具路径，但不改变用户要求的双击行为。

## 测试要求
- unit state toggle
- 真机支持型号验证

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
