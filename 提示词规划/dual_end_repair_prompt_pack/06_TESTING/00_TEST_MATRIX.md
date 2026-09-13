# 总测试矩阵

| 场景 | 预期 |
|---|---|
| 正常启动 | READY |
| HTTP 101 单包 | READY |
| HTTP 101 两段 | READY |
| HTTP 101 多段 | READY |
| ACK 丢失 | replay + same effect + ACK |
| duplicate message same semantic | 同 seq + ACK |
| duplicate ID different semantic | 明确 conflict |
| NWConnection failed | 新 attempt |
| NWConnection cancelled | 新 attempt |
| waiting > watchdog | 丢弃旧 connection |
| Browser failed | rebuild |
| Browser waiting > watchdog | rebuild |
| daemon graceful restart | 自动恢复 |
| daemon 换端口 | 浏览结果更新后恢复 |
| 120s lock | 自动恢复 |
| 20min lock | 自动恢复 |
| 旧 epoch callback 迟到 | 被忽略 |
| 20次 120s lock stress | 0 永久卡死 |
