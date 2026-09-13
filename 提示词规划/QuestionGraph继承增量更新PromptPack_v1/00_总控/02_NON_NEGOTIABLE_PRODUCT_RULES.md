# Non-Negotiable Product Rules

实现过程中持续检查以下产品红线。任何“更简单”的实现只要违反其中一条，都不可接受。

1. **不是复制继承。** child snapshot 可以包含 inherited node，但 canonical store 不得复制 parent Explanation。
2. **同一 node identity。** parent 与所有 child/sibling 看到同一 Explanation 时必须共享 `node_id`。
3. **CENTER 独立。** Review CENTER 是当前复习 probe；不得继承 Question Bank CENTER。
4. **TEMPORARY 隔离。** round-scoped Temporary 绝不跨 graph inheritance。
5. **动态继承。** parent 后来新增 Explanation，child 后续 snapshot 自动可见；不得把继承节点列表冻结成创建时快照。
6. **单向 ownership。** child 新增 Explanation 归 child，不回灌 parent/sibling。
7. **Write-through。** rename/move/Ink 对 inherited node 修改 canonical node。
8. **Layout node-scoped。** V1 不做 per-graph layout；同一 shared node 在所有图位置一致。
9. **Ink node-scoped。** Ink 只按 node_id；Review 与原题图必须看到同一笔迹。
10. **删除是全局删除。** inherited delete 删除 canonical Explanation；UI 必须警告影响原题图及所有继承图。
11. **来源不能猜。** `primary_source_question_id` 是唯一自动 inheritance anchor；不使用 `source_questions[0]` 猜测。
12. **事实性。** parent graph 不存在时不得伪造历史 graph/Explanation；Review 仍应可继续。
13. **Agent 声明关系，GraphService 计算视图。** Runtime 不复制节点、不自行拼装 inherited snapshot。
14. **旧可靠性规则保留。** dedup/CAS/durable/outbox/snapshot recovery 不得因 inheritance 被削弱。
15. **UI 不是事实源。** iPad 只缓存 canonical + membership；Mac canonical store 决定 ownership/inheritance。
