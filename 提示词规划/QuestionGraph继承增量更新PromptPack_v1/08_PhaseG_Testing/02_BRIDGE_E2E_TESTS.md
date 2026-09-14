# Bridge E2E Tests Prompt

用真实 daemon/service/session 路径验证 inheritance，不要只 mock GraphService。

## 主场景

1. open QB B。
2. add Explanation E1。
3. close/reopen 必要 round，确认 E1 persistent。
4. open Review A with inherit_from B。
5. iPad/client 收到 snapshot：CENTER_A + inherited E1；不含 CENTER_B。
6. client 在 A rename E1。
7. open/request B snapshot，看到相同 title/node_id。
8. open Review C inherit B。
9. client 在 C move E1。
10. A/B snapshot 看到相同 layout。
11. 触发 stale base revision，确认 snapshot recovery。
12. disconnect/reconnect，确认 A membership 恢复。

## Delete 场景

A delete E1 后：B/A/C 都不再出现，且 server canonical row 为 deleted。

## Journal/dedup

重复同 inheritance/open/mutation command 不产生双 effect；durable-before-emit/ACK 仍成立。
