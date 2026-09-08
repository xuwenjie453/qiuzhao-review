# 零人工配对与安全边界

## 任务目标
确保最终 bridge 没有验证码/IP 配置。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/06_自动信任与安全边界.md`

## 必须满足
- 可信个人 LAN + TOFU。
- local control 仅 loopback。
- 无 pairing code。
- 无手动 IP endpoint。
- schema/size limits。

## 实施步骤
1. 全仓搜索 pair/pairing/manual IP 相关新代码。
2. 若从 reading-system 复制，删除其 Pairing token path。
3. 记录安全边界到 README。

## 测试要求
- 正常连接完全不需要 user credential
- malformed payload rejected

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
