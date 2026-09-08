# Protocol Reviewer

逐项对 Node/Swift：
- Envelope 字段；
- protocol version；
- session_epoch；
- server_seq；
- snapshot/patch revision；
- node/layout CAS；
- ink revision；
- duplicate handling；
- unknown type；
- size limit；
- fixtures 同源。
任何一端字段名/optional/default 不一致 = BLOCKER。
