# Concurrency & Recovery Audit Prompt

针对共享节点检查并发与断线恢复。

场景：B owns E1，A/C inherit B。

- A/C 同时 rename E1：CAS 是否保证 one winner？
- A move 后 ACK 丢失并重放：dedup 是否 one-effect？
- C 修改 E1 时 A offline：A reconnect snapshot 是否拿到新 canonical state？
- shared mutation fan-out 中 daemon crash：事务是否避免部分 graph revision 已增、node mutation 未完成？
- inheritance relation 建立后 snapshot emit 前 crash：重启能否从 canonical relation 重建？
- iPad apply snapshot crash：durable-before-ACK 是否仍成立？
- A snapshot apply 与 B pending outbox 同时存在：是否误删 B membership/intent？
- Ink revision 与 structural patch 并发是否互不破坏？

发现任何依赖“事件通常不会同时发生”的逻辑，标记为风险。
