# 官方参考资料

以下资料用于约束实现语义；执行 AI 应优先以官方文档和当前源码为准。

## Apple Network.framework

- NWConnection.receive — 每次 receive 调用的 completion 只触发一次：
  https://developer.apple.com/documentation/Network/NWConnection/receive%28minimumIncompleteLength%3AmaximumLength%3Acompletion%3A%29

- NWConnection.State：waiting / preparing / ready / failed / cancelled：
  https://developer.apple.com/documentation/network/nwconnection/state-swift.enum

- NWConnection.State.cancelled：
  https://developer.apple.com/documentation/network/nwconnection/state-swift.enum/cancelled

- NWBrowser.State：failed 是 fatal error：
  https://developer.apple.com/documentation/network/nwbrowser/state-swift.enum

- NWBrowser：
  https://developer.apple.com/documentation/network/nwbrowser

- Apple DTS：iOS suspend 后 NWConnection 可能被 defunct；应用应准备重建：
  https://developer.apple.com/forums/thread/840808

## SQLite

- UPSERT / ON CONFLICT DO NOTHING：
  https://www.sqlite.org/lang_upsert.html

- ON CONFLICT：
  https://www.sqlite.org/lang_conflict.html

## 使用原则

不要依赖未文档化的“锁屏一定得到 cancelled”之类假设；状态机应同时正确处理 failed/cancelled/waiting 与 owner-driven rebuild。
