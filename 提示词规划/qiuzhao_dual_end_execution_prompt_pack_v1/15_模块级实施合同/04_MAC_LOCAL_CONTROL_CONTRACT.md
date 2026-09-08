# LocalControlServer 合同

监听：仅 loopback。

最低 endpoints：
```text
GET  /v1/status
POST /v1/question/open
POST /v1/question/close
POST /v1/node/add
GET  /v1/graph/:graph_id
```

推荐补充调试所需 query，但 mutation 一律经 GraphService。

Request：
- JSON；
- command_id 必填；
- Markdown body 可通过 stdin→CLI→HTTP JSON，必须保持 UTF-8 原文；
- body size limit。

Response：
```json
{"ok":true,"result":{...}}
```
或
```json
{"ok":false,"error":{"code":"...","message":"...","retryable":false,"details":{}}}
```

禁止：
- bind 0.0.0.0；
- 返回 stack；
- 让 Agent 获得 DB 路径后自行 UPDATE。
