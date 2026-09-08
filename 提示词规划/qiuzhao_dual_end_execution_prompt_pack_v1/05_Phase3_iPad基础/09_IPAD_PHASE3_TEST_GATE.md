# Phase 3 iPad 基础测试闸门

## 任务目标
证明新 App 工程、Store、协议和真实 Mac 互通。

## 必读设计稿
- `90_设计稿基线/06_质量与交付/03_测试策略.md`

## 必须满足
- 若当前机器有 Xcode，必须跑 xcodebuild。
- 若无 Xcode，必须记录 BLOCKED，不得声称 build pass。

## 实施步骤
1. 运行 Swift unit tests。
2. 连接 Phase2 daemon 做最小 HELLO/SNAPSHOT E2E。
3. 杀网络后确认 cache 未清空。

## 测试要求
- build/unit/E2E evidence

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
