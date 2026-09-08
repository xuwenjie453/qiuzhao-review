# 零配置连接专项审计

## 任务目标
确保整个 iPad App 没有残留 pairing/IP/port 配置路径。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/01_Bonjour自动发现与连接.md`
- `90_设计稿基线/03_协议与同步/06_自动信任与安全边界.md`

## 必须满足
- 自动选择 preferred daemon。

## 实施步骤
1. 全仓 grep：PairingView/pair code/manual host/IP text field。
2. 验证同 LAN daemon+app 启动后自动连接。

## 测试要求
- no manual path

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
