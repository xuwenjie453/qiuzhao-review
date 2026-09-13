# 目标状态机

```text
STOPPED
  |
  v
DISCOVERING --browser fatal/timeout--> RECOVERING
  | service
  v
CONNECTING --conn terminal/timeout--> RECOVERING
  | TCP ready
  v
HANDSHAKING --101/WELCOME timeout--> RECOVERING
  | WELCOME
  v
SYNCING --protocol failure--> RECOVERING
  | replay/snapshot complete
  v
READY
  | background / path failure / terminal
  v
RECOVERING
  |
  +--> new Network Epoch --> DISCOVERING
```

任何状态都不能成为无后继吸收态。
