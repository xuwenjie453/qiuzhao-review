# MASTER EXECUTION PROMPT — 交给实施 AI 的总控指令

你正在对 `xuwenjie453/qiuzhao-review` 实施一次**明确限定范围的双端版本更新**。你不是重新设计学习系统；你要在现有 Agent-native 学习系统旁路新增 Mac↔iPad 双端能力，并真正开发一个 iPadOS App。

## 一、最高目标

最终仓库必须同时拥有：

- 原有秋招学习闭环，行为不被破坏；
- `DualEnd-Mac/`（或设计允许的等价命名）伴生 daemon；
- `DualEnd-iPad/` 下完整 Xcode 工程；
- 新双端 SQLite Store；
- localhost Agent Control API / CLI；
- Bonjour `_qiuzhaoreview._tcp`；
- WebSocket v1；
- Snapshot/Patch/ClientCommand/Ink 同步；
- iPad 本地 SQLite + outbox + inbox dedup；
- QuestionGraph Topology；
- immutable Markdown Reader；
- PencilKit Ink；
- Runtime Prompt 双端协议；
- 自动化测试与真机验收说明。

## 二、绝不能把更新做成什么

禁止把此次任务做成：
- Web App；
- Mac GUI 学习主程序；
- iPad 上的新聊天/Agent 主界面；
- Scheduler 重写；
- 五库合并；
- “AI 自动判断重点并自动加解释节点”；
- 手动 IP/端口/验证码配对；
- 单纯 Demo 或静态 UI；
- 只有 iPad mock、没有真实协议；
- 只有 Mac 协议、没有 iPad 工程；
- 只有源文件、没有 Xcode project；
- 用 WebView + 独立 Pencil scroll view 粗暴叠加导致坐标漂移；
- ACK 在落盘之前发送。

## 三、实施方法

每个阶段遵守以下循环：

1. 阅读该阶段 Prompt 指定的设计稿章节。
2. 检查当前仓库对应代码，而不是凭假设工作。
3. 写“阶段前检查结果”。
4. 完成最小可验证闭环。
5. 添加/更新自动化测试。
6. 运行测试并记录命令和结果。
7. 做 `10_代码审查` 中相关专项自审。
8. 更新 `实施状态.md`。
9. 只有阶段 DoD 满足后进入下一阶段。

不要因为任务很大就跳阶段。

## 四、遇到设计冲突

如果一个技术问题迫使你违反冻结产品决策：
- 停止该**局部分支**；
- 明确记录冲突、证据、影响和可选方案；
- 不要静默改变产品行为；
- 继续完成不受冲突影响的其他部分。

以下不是冲突，可自行解决：
- 文件名小幅调整；
- 内部类/函数命名；
- 测试辅助结构；
- 编译器要求的安全重构；
- 不改变契约的内部实现选择。

## 五、实现完整性原则

### Mac
所有 canonical mutation 都经 command service。不得让 Agent、CLI、WebSocket handler 直接 UPDATE 数据库。

### iPad
所有 canonical/cache mutation 都经 `ClientStore` actor。网络 callback 不直接写 SwiftUI state。

### Protocol
Node 和 Swift 使用同一套 fixtures。字段变化必须双端同步测试。

### Ink
屏幕落笔与磁盘 I/O 解耦；PencilKit 主线程负责交互，序列化/SQLite 写入不得造成可见卡顿。

### Runtime
用户普通追问只产生聊天解释，不自动加图。只有用户显式指定某段解释时才执行 add。

## 六、完成判据

只有当以下都具备才可以说“更新实现完成”：
- Mac unit / protocol / bridge E2E 通过；
- iPad 工程可以在具备 Xcode 的环境 build；
- iPad store/sync/topology/reader 的 unit/UI tests 已实现并尽可能运行；
- LAN 自动发现/自动连接路径存在且无人工配对；
- true device Pencil Gate 有明确真实执行证据，或者明确标记未能在当前环境执行；
- 原学习系统基线测试仍通过；
- Release Acceptance Checklist 完整逐项给状态。

不要用“代码看起来正确”替代验收。
