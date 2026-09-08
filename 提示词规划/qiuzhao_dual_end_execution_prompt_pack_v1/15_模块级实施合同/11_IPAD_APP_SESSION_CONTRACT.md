# AppSessionModel 合同

只保存 UI 所需派生状态：
```text
connectionState
activeGraphID
activeRoundID
selectedNodeID / route
lastUserVisibleError
```

canonical graph/node/ink 从 ClientStore 获取。

启动：
1. open DB；
2. load cached active；
3. render；
4. start browser；
5. connect/sync。

连接状态：
- cachedOffline
- discovering
- connecting
- syncing
- ready
- localNetworkDenied
- protocolUnsupported

离线时 Reader/Topology 仍可读 cache。
