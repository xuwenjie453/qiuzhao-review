# 分阶段执行计划

## Phase 1 — Mac only

- 建议新分支：`fix/dualend-idempotent-recovery`
- 修 journal replay
- 修 WELCOME ID/顺序
- 新增 Mac tests
- 启动 daemon
- 保持 iPad binary/database 不变
- 观察 poison item 是否自动 ACK 清除

成功后创建独立 commit/tag checkpoint。

## Phase 2 — iPad Transport

- 修 receiveLoop
- terminal exactly once
- timeouts
- send error
- transport tests

独立 commit。

## Phase 3 — Sync/Browser/Lifecycle

- reconnect scheduler
- backoff
- browser endpoint/rebuild
- network epoch
- scenePhase
- structured logging

独立 commit。

## Phase 4 — Full regression

- fault injection
- lock stress
- daemon restart
- stale callback

禁止在某阶段失败时继续堆新改动；先定位并修当前阶段。
