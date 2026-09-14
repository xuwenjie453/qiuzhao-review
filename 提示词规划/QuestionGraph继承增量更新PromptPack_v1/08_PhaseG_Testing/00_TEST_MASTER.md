# Phase G — Test Master Prompt

不要只测试“Review snapshot 多了 inherited node”。必须测试共享 identity、传播、迁移与恢复。

## 测试层级

1. Mac store migration tests。
2. Mac GraphCore unit。
3. Wire fixture/codec tests。
4. Bridge E2E。
5. iPad store/sync/domain tests。
6. iPad build/UI state tests（可自动化部分）。
7. Learning system E2E。
8. Manual true-device acceptance。

## 核心测试矩阵

建立：B=QuestionBank；A/C=Review；E1/E2=B owned；X1=A owned。

验证：
- A/C inherited E1 same node_id；
- B add E2 -> A/C dynamically visible；
- A add X1 -> B/C invisible；
- A rename E1 -> B/C same title；
- C move E1 -> A/B same layout；
- A Ink E1 -> B/C same drawing；
- A delete E1 -> B/C removed；
- parent/child graph revisions only在 structural mutation 正确 fan-out；
- Ink 不 fan-out graph revision；
- stale CAS 被拒绝；
- reconnect/snapshot 恢复 membership；
- legacy v1 DB/cache migration 无损。

任何一个核心矩阵项没有证据，不得声称 inheritance 完整实现。
