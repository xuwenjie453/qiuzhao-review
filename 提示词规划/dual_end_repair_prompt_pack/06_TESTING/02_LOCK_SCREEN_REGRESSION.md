# 锁屏回归计划

修复完成后不再以“寻找时长阈值”为主，而是验证收敛性。

## 基础
- 20s × 5
- 120s × 20
- 20min × 3

## 每次记录
- T_LOCK
- T_UNLOCK
- epoch change
- browser ready/result
- connection states
- HTTP101
- WELCOME
- replay count
- READY

## 失败判据
- 前台 30s 未 READY 且无明确错误
- phase 卡 CONNECTING/Discovering 不再变化
- outbox 同一条无限重放无 ACK
- 多个 epoch 并发修改 UI
