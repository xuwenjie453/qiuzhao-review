# Bonjour Advertiser

## 任务目标
实现 Mac `_qiuzhaoreview._tcp` 广播与稳定 TXT metadata。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/01_Bonjour自动发现与连接.md`

## 必须满足
- TXT 不放 secret。
- daemon_id 稳定。
- proto=1。
- advertise failure→DEGRADED，不损 canonical core。

## 实施步骤
1. 优先复用 reading-system 已验证思路。
2. 实现 start/stop/health。
3. 本机用 dns-sd 或等价命令验证服务可见。

## 测试要求
- advertiser lifecycle
- TXT fields

## 禁止捷径
- 不要复制 `_readingsystem._tcp` 或 pairing metadata。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
