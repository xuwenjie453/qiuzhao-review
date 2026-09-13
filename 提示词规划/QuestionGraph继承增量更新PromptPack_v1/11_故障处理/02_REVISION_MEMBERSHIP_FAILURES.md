# Revision / Membership Failure Recovery Prompt

## 症状 A：parent 改了，child 不刷新
检查：
- `affectedGraphsForNode` 是否包含 child；
- child graph_revision 是否增加；
- daemon 是否广播 child graph patch/snapshot；
- iPad child membership 是否存在。

## 症状 B：打开 child 后 parent node 消失
检查：
- applySnapshot 是否把“未出现在 A snapshot”误解释成 canonical delete；
- 是否只替换 A membership；
- nodes_cache locally_deleted 是否仍被 graph-local逻辑滥用。

## 症状 C：同 node 出现两份
检查：
- server 是否复制 inherited node；
- iPad 是否以 `(graph,node)` 复制 canonical row；
- node_id 是否被重新生成。

## 症状 D：patch mismatch 循环
检查：
- fan-out revision 是否和发送 patch 的 base/target 同一事务事实；
- 是否对同一 graph 一次 mutation 增加多次 revision；
- snapshot revision 是否 canonical 最新。

修复必须加最小 regression test，不要通过强制全量刷新无限兜底。
