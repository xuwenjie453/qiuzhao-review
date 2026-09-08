# 启动/停止/开发 Runbook

## 任务目标
让下一位 AI 或用户可按文档启动 Mac daemon 与 iPad App。

## 必读设计稿
- `90_设计稿基线/02_Mac端/01_Mac守护进程.md`
- `90_设计稿基线/04_iPad端/01_iPad应用架构.md`

## 必须满足
- 命令与路径必须实际存在。

## 实施步骤
1. 写 DualEnd-Mac README。
2. 写 DualEnd-iPad README。
3. 说明 Xcode signing、Local Network permission、真机 Pencil。
4. 说明 daemon 当前如何常驻；若实现 launchd，提供安全 install/uninstall；若未实现不得声称开机常驻。

## 测试要求
- fresh checkout runbook review

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
