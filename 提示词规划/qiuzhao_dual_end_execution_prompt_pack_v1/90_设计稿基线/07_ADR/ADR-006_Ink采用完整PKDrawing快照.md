# ADR-006：Ink v1 传完整 PKDrawing snapshot

Status: Accepted

## Alternatives

- stroke delta；
- CRDT strokes；
- PNG raster；
- full PKDrawing bytes。

## Decision

每次 debounce durable 后同步完整 `PKDrawing.dataRepresentation()`。

## Rationale

单用户 LAN、每节点一份笔迹、实现简单、恢复确定；PNG 会丢失矢量编辑能力，delta/CRDT 对 v1 过度设计。
