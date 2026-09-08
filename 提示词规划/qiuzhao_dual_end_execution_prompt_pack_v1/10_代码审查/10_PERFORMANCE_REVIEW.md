# Performance Reviewer

Mac：
- journal/db transaction 不做无界扫描；
- patch 不每次发全图（snapshot fallback除外）；
- Ink blob 不进入 JSON log。

iPad：
- Pencil render 与 save 解耦；
- SQLite actor 不阻塞 MainActor；
- Topology drag 不每帧网络发送（本地流畅，合理节流/提交）；
- Markdown 长页不卡死；
- cache load 不等待 LAN。
