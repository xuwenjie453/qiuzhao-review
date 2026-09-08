# NWBrowser Bonjour 自动发现

## 任务目标
实现 `_qiuzhaoreview._tcp` 浏览、stable auto-selection 和 permission UX 状态。

## 必读设计稿
- `90_设计稿基线/03_协议与同步/01_Bonjour自动发现与连接.md`
- `90_设计稿基线/04_iPad端/07_连接状态与UX.md`

## 必须满足
- preferred daemon 优先。
- 否则 proto=1 + daemon_id 稳定排序。
- 无 chooser UI。
- Local Network denied 与 Mac offline 区分。

## 实施步骤
1. 配置 Info.plist `NSLocalNetworkUsageDescription`、`NSBonjourServices`。
2. 实现 browser state machine。
3. 缓存 preferred daemon。

## 测试要求
- service sort deterministic
- permission state mapping
- discovery updates

## 禁止捷径
- 不加入手动 IP fallback。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
