# Protocol Schema 合同

所有文本消息：
```json
{
  "v":1,
  "message_id":"uuid",
  "type":"...",
  "session_epoch":"uuid-or-null",
  "sent_at":"ISO-8601",
  "payload":{}
}
```

规范：
- JSON decoder 必须拒绝缺失必填字段；
- message_id dedup；
- sent_at 仅诊断，不用于业务排序；
- server_seq 由 Mac journal 决定；
- graph revision 只用于图结构；
- node/layout/ink 有各自并发域；
- optional unknown fields ignore；
- unknown message type log+ignore 或 typed reject，不能 crash；
- max body/ink/frame size 在两端一致。

协议 fixture 是 cross-platform executable spec。
