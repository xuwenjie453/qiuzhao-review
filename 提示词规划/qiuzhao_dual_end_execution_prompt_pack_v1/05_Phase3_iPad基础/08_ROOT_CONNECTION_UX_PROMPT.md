# Root UX / Connection Status

## 任务目标
建立缓存优先 App Shell 和精确连接状态。

## 必读设计稿
- `90_设计稿基线/04_iPad端/07_连接状态与UX.md`

## 必须满足
- 首次有 cache 即展示。
- 状态：连接/连接中/离线缓存/权限拒绝/协议不兼容。
- 无配对页。

## 实施步骤
1. 实现 AppSessionModel。
2. 首次权限说明轻量展示。
3. 提供系统 Settings 跳转仅用于权限恢复。

## 测试要求
- offline cache visible
- permission denied wording
- reconnect status

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
