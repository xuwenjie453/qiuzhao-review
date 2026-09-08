# iPad BridgeConnection 合同

职责仅限 transport/discovery，不拥有 canonical graph state。

输入：
- selected Bonjour endpoint；
- outgoing envelope stream。

输出：
- connection state events；
- decoded envelope stream；
- transport errors。

实现：
- NWBrowser 浏览 `_qiuzhaoreview._tcp`；
- service auto-select；
- URLSessionWebSocketTask；
- heartbeat；
- reconnect signal；
- foreground resume。

禁止：
- Pairing code；
- host/IP text field；
- 网络 callback 直接改 SwiftUI graph。
