# Observability Checklist

Mac status 至少暴露：
- daemon state；
- DB schema version/integrity；
- bridge listening；
- Bonjour advertised；
- connected devices count；
- active graph/round id（不泄露正文）；
- server_seq；
- journal size；
- last error。

iPad Diagnostics 可显示：
- connection state；
- daemon_id；
- session_epoch short；
- active graph revision；
- pending outbox count；
- last sync error；
- local DB schema version。

日志不得输出完整解释正文或 Ink blob。
