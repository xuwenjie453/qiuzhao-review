# Canonical Mutation & CAS Prompt

继承不能降低现有 mutation 安全性。

## Command context

Client command 中：
- `node_id` = canonical mutation target；
- `graph_id` = 用户操作发生的 view graph context；
- `graph_id` 不表示 owner，也不得用于改写 ownership。

Server 在 mutation 前必须验证：目标 node 当前在 command.graph_id 的 effective view 中可见。不能只验证 `node.graph_id == command.graph_id`，否则 inherited node 无法编辑；也不能完全不验证，否则任意 graph 可改任意 node。

## CAS 保持

- rename/delete：node_revision CAS；
- move：layout_revision CAS；
- Ink：ink_revision sequence；
- duplicate command：command_dedup one-effect。

Inherited node 与 own node 使用完全相同的 canonical revision。

## Delete

删除 inherited Explanation = global canonical delete。若 command view 是 child：
- server 不创建 child tombstone；
- canonical owner node `deleted_at` 更新；
- affected parent/children structural revisions fan-out；
- duplicate delete 幂等；
- CENTER 仍永远 forbidden。

## 反例

若 A/C 都看到 B.E1，A 持 node_revision=3，C 成功 rename 到 rev4，A 再提交 base=3 必须 CAS_MISMATCH，而不是 silently overwrite。
