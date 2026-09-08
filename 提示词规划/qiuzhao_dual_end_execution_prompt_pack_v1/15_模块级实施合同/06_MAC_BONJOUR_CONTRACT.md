# BonjourAdvertiser 合同

Service type：`_qiuzhaoreview._tcp`

TXT：
```text
proto=1
daemon_id=<stable id>
workspace=<short fingerprint>
bridge=ws
```

要求：
- daemon_id 存在持久 meta，不每次启动变；
- workspace fingerprint 仅用于诊断/选择，不是 secret；
- port 使用实际 bridge port；
- advertise start/stop 可重复；
- 注册冲突/失败进入 DEGRADED 并可重试；
- 不产生 pairing code；
- 不要求用户读取 TXT。
