# 故障注入方案

## ACK-loss

服务端在 journal 成功后、ACK send 前按测试开关丢弃一次 ACK，然后主动断开。
验证 reconnect replay。

## HTTP 101 split

测试 server 将 101 header 按多种边界分块写入。
必须证明当前修复后的 client 会持续 receive。

## Waiting simulation

通过测试 double/fake transport 模拟 preparing/waiting 超时，验证 watchdog 触发 owner replacement。

## Stale callback

创建 epoch N，随后切 N+1，再人工触发 N 的 failed/closed/result callback；状态不得回退。

## Browser fatal

注入 failed，验证新 generation 创建且 candidate 清空。
