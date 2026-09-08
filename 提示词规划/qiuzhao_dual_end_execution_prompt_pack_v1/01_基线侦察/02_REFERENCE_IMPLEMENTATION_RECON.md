# reading-system 参考实现侦察 Prompt

只抽取工程模式，不复制业务。

重点观察：
- Mac daemon lifecycle；
- SQLite WAL / transaction / dedup / journal；
- RFC6455 WebSocket 或 bridge abstraction；
- Bonjour advertise；
- bridge E2E test；
- Swift Envelope / ClientStore actor；
- NWBrowser / URLSessionWebSocketTask；
- outbox / reconnect / epoch；
- Topology gesture coordination；
- Reader + PencilKit 低延迟路径。

输出“复用矩阵”：
- 可复制思路；
- 可移植代码片段/模块（若许可证/同作者仓库允许内部复用）；
- 必须重写的业务；
- 禁止复制（配对码、手动 IP、Reading Focus 等）。

不要把 reading-system 的实现现状反过来改本设计。
