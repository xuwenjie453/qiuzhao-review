# 建议 Commit 划分

1. `fix(mac): make replay journal idempotent and fix welcome ids`
2. `test(mac): cover ack-loss and duplicate replay`
3. `fix(ipad): make websocket receive loop stream-safe`
4. `fix(ipad): unify transport terminal handling and watchdogs`
5. `fix(ipad): rebuild browser and add network epochs`
6. `test(ipad): add transport lifecycle and stale-callback coverage`
7. `test(e2e): add lock/restart recovery regression`

保持 commit 可独立 review / revert。
