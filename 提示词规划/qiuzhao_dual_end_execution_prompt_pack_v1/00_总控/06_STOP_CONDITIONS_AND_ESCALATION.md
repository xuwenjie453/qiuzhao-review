# 停止条件与升级规则

实施 AI 仅在以下局部问题上停止并报告，不要因为其中一项就停止整个版本：

- 设计冻结规则与平台事实不可同时满足；
- 数据迁移会损坏现有用户真源；
- 需要删除/重建用户现有数据库才能继续；
- 当前 repo 已经出现无法解释的 schema 与设计冲突；
- 用户提供的参考 PDF 仍缺失，且当前任务仅剩 typography calibration；
- 当前机器无 Xcode/签名/真机，导致只剩硬件 Gate。

不可把这些当“停止整个任务”的理由：
- 编译错误；
- Swift API 细节；
- Node API 差异；
- 文件名与设计建议不同；
- 需要增加测试 helper；
- Bonjour 权限配置；
- WebSocket frame 实现 bug；
- 一般 race condition。

这些应自行调试解决。
