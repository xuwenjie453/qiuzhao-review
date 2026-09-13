# 当前根因模型

## 复合故障模型

### 链 A：客户端旧 transport 吸收态

`lock/suspend -> old NWConnection stale -> waiting/preparing/cancelled -> no bounded recovery -> SyncEngine.ws != nil -> connect() guard -> “正在连接” forever`

### 链 B：持久 outbox + 非幂等 journal

`message M effect committed -> journal M committed -> ACK lost -> outbox keeps M -> app restart -> replay M -> UNIQUE(message_id) -> ACK path interrupted -> M remains -> retry loop`

### 链 C：HTTP Upgrade 分片 bug

`TCP ready -> send Upgrade -> receive partial 101 without 

 -> opened=false -> receiveLoop stops -> no transportOpen -> connecting forever`

## 不要错误统一

以下现象可能来自不同层：
- “正在连接…”：transport/handshake 吸收态概率高。
- “离线 · 显示本地内容”：可能只是初始 cachedOffline 或 discovery 还未更新 phase，不能直接判定 Bonjour 失败。
- Mac 看到 101：说明 discovery/TCP/HTTP 至少当次成功，后续失败在应用层或 transport lifecycle。
