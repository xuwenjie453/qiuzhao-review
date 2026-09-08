# 全版本 Definition of Done

## 代码
- 原 qiuzhao 学习核心仍工作。
- Mac daemon 可初始化、启动、停止、恢复。
- QuestionGraph schema / migration / command service 可运行。
- Agent localhost API / CLI 可运行。
- Bonjour / WebSocket bridge 可运行。
- iPad Xcode 工程完整，源代码归档在仓库。
- iPad 可离线加载 cache；在线可自动发现/连接。
- Topology/Reader/Pencil 全部存在。
- Runtime Prompt / AGENTS / README 已更新。

## 数据正确性
- node body immutable DB guard。
- one center invariant。
- one active round invariant。
- temporary round isolation。
- command dedup。
- server_seq monotonic。
- graph/node/layout/ink revisions 语义正确。
- tombstone 不复活。
- outbox ACK 前不删除。

## UX
- iPad 启动先显示 cache，再联网。
- 无 IP/验证码输入界面。
- 单击/双击/长按手势不互相误触。
- CENTER 不出现删除按钮。
- Pencil 书写不等待持久化。
- Local Network 权限拒绝时准确提示权限问题。

## 验收
- 自动化测试结果有命令+输出摘要。
- 真机要求有 PASS 或 BLOCKED/NOT_RUN 的真实状态。
- 不将 Simulator 当 Pencil 性能证据。
- 无 PDF 时 typography match 标 blocked。
