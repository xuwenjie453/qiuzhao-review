# UI phase 映射

不要让 `cachedOffline` 同时承担“尚未开始发现”和“真实离线”。

建议至少：
- DISCOVERING：正在发现 Mac…
- CONNECTING：正在连接…
- HANDSHAKING/SYNCING：正在建立会话/同步…
- READY：已连接
- OFFLINE_CACHED：离线 · 显示本地内容
- LOCAL_NETWORK_DENIED：需要本地网络权限
- ERROR_RETRYING：连接异常，正在重试…

调试构建可附 epoch/attempt 简短信息。
