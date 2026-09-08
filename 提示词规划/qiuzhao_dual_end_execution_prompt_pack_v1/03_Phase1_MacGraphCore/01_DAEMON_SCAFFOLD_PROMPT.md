# Mac daemon 工程骨架

## 任务目标
创建 `DualEnd-Mac` 工程、CLI 与 daemon 生命周期骨架。

## 必读设计稿
- `90_设计稿基线/02_Mac端/01_Mac守护进程.md`

## 必须满足
- 优先 Node.js 26 + 内置模块；若当前环境不同先兼容检测。
- daemon 不取代 Python 学习核心。
- 单实例 lock。
- STARTING→READY/SAFE_MODE/DEGRADED 生命周期。

## 实施步骤
1. 建立 package/bin/src/test 结构。
2. 实现 `init/start/status/stop` 最小 CLI。
3. 实现运行目录创建和 lock。
4. 先不加入网络复杂度。

## 测试要求
- 第二实例拒绝
- clean start/stop
- bad store 进入 SAFE_MODE

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
