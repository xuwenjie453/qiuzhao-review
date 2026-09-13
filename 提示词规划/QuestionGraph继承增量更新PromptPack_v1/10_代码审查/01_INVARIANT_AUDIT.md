# Invariant Audit Prompt

逐条从代码而不是注释证明：

- inherited node 不 INSERT copy；
- `nodes.graph_id` 只表示 owner；
- effective view 只继承 EXPLANATION；
- CENTER/TEMPORARY exclusion 有 server 级保证；
- parent later ADD 动态进入 child；
- child own node 不传播；
- visibility validation 防止任意 graph 修改任意 node；
- shared rename/move/delete fan-out 所有 affected graph revision；
- Ink 不 fan-out graph revision；
- iPad canonical cache 与 membership 分离；
- snapshot A 不删除 B membership/canonical node；
- outbox graph_id 是 view context；
- primary source 不由 source_questions 顺序推断；
- missing parent 不伪造历史；
- body immutable、CENTER guard、CAS、dedup、durability 全保留。

若某条只能靠“当前 UI 不会这么调用”成立，视为服务端不变量缺失。
