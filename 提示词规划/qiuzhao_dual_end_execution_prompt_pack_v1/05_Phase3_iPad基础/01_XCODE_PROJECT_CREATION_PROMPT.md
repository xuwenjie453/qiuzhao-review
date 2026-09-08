# 创建完整 iPadOS Xcode 工程

## 任务目标
真正新增 `DualEnd-iPad` 下完整工程，而不是仅放 Swift 片段。

## 必读设计稿
- `90_设计稿基线/04_iPad端/01_iPad应用架构.md`
- `90_设计稿基线/05_集成与迁移/03_文件级改造清单.md`

## 必须满足
- Swift/SwiftUI 主体。
- UIKit bridge 可用。
- PencilKit/Network/SQLite3 system frameworks。
- 零第三方依赖优先。

## 实施步骤
1. 先检查可用 Xcode/SDK。
2. 创建 app target + unit tests + UI tests（若环境支持）。
3. 设置 iPad device family。
4. 加入源码目录 Domain/Protocol/Connectivity/Sync/Store/Topology/Reader/Pencil/Diagnostics。
5. 保证 project file 纳入 git。

## 测试要求
- xcodebuild -list
- 能解析 project
- 基础 target compile（环境允许）

## 禁止捷径
- 禁止只创建 Swift package 代替 iPad App。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
