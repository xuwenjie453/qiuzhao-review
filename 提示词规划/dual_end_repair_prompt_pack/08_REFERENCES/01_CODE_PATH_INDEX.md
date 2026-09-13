# 关键代码路径索引

## Mac

- `DualEnd-Mac/src/store/state-db.mjs`
  - schema
  - sync_journal
  - journal()

- `DualEnd-Mac/src/bridge/sync-session.mjs`
  - onHello
  - onClientCommand
  - onInkPut
  - ACK/WELCOME

- `DualEnd-Mac/src/bridge/ws-server.mjs`
  - HTTP Upgrade
  - socket lifecycle
  - heartbeat

## iPad

- `DualEnd-iPad/QiuZhaoReader/Connectivity/WebSocketTransport.swift`
  - NWConnection states
  - HTTP Upgrade
  - receiveLoop

- `DualEnd-iPad/QiuZhaoReader/Connectivity/BonjourBrowser.swift`
  - NWBrowser lifecycle
  - candidates

- `DualEnd-iPad/QiuZhaoReader/Sync/SyncEngine.swift`
  - reconnect
  - outbox replay
  - HELLO/WELCOME

- `DualEnd-iPad/QiuZhaoReader/App/AppSessionModel.swift`
  - bootstrap
  - UI phase
  - scene lifecycle integration point
