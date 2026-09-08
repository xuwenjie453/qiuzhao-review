# 真机 Pencil Gate

## 任务目标
在真实 iPad + Apple Pencil 上验证书写体验。

## 必读设计稿
- `90_设计稿基线/06_质量与交付/03_测试策略.md`
- `90_设计稿基线/06_质量与交付/04_验收标准.md`

## 必须满足
- Simulator 不能作为 Pencil Gate。

## 实施步骤
1. 安装 App 到真机。
2. 连续书写2分钟。
3. 滚动长页。
4. double tap eraser（支持型号）。
5. 离开/返回50次抽样检查 alignment。
6. kill/relaunch 检查 ink。

## 测试要求
- 记录设备/OS/Pencil 型号、PASS/FAIL。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
