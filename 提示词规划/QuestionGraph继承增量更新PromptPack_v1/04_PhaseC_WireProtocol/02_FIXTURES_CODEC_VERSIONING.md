# Fixtures / Codec / Versioning Prompt

更新 `DualEnd-common/fixtures`，让协议语义可以被双方测试共同锁定。

## 至少新增/更新 fixtures

1. Question Bank graph owner-only snapshot。
2. Review graph inheritance snapshot：own CENTER + inherited E1/E2。
3. shared rename child patch。
4. shared move sibling child patch。
5. shared delete patch。
6. inheritance relation first-open snapshot。
7. base mismatch recovery request/response（沿用现有 fixture 可扩充）。

## Codec 要求

Node/Swift 都严格 decode：
- ownerGraphId；
- visibility enum；
- parentGraphs relation list。

未知 visibility/inheritance kind 不应 silently 当 OWN。

## Version

若现有 `v` 是协议版本，明确 bump。选择以下一种并测试：
- daemon 对旧 client 返回 upgrade-required；或
- 在明确窗口内兼容旧 snapshot，但旧 client 不得进入 inheritance graph。

禁止“字段 optional 所以无需版本升级”的无声明策略，因为旧缓存模型无法正确表达一 node 多 membership。
