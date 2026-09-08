# ADR-004：Mac canonical authority + iPad local-first

Status: Accepted

Mac 是 graph 合并点；iPad 所有交互先本地 durable 再 outbox。

这样同时满足：

- Mac Agent 新增解释可推送；
- iPad 断网仍能读/写标题/位置/Ink；
- 重连可集中解决冲突；
- 不引入 CRDT。
