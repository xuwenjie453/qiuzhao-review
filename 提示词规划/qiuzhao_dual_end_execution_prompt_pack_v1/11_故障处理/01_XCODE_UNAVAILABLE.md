# 当前环境没有完整 Xcode 时

必须继续：
- 创建完整工程文件；
- 写 Swift 源码；
- 写 tests；
- 做可用的静态语法/结构检查；
- 写 build 指令。

不得：
- 声称 xcodebuild PASS；
- 声称 Pencil Gate PASS；
- 把 iPad App 改成“以后再做”。

最终状态：`iPad build = BLOCKED_BY_ENVIRONMENT`，并列出用户/下一代理在 Mac Xcode 上要跑的命令。
