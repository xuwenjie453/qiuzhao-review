# QuestionGraphService Effective View Prompt

在 `question-graph-service.mjs` 中实现 graph ownership 与 visibility 分离。

## 建议新增能力

```text
ensureInheritance(childGraphId,parentGraphId,kind)
parentGraphs(graphId)
effectiveNodes(graphId,roundId)
nodeVisibleInGraph(nodeId,viewGraphId,roundId)
affectedGraphsForNode(nodeId)
```

函数名可按代码风格调整，但职责必须存在。

## ensureInheritance

必须验证：
- child 存在且 source=REVIEW_CAPSULE；
- parent 存在且 source=QUESTION_BANK；
- child != parent；
- kind=SHARED_EXPLANATIONS；
- V1 runtime 不允许第二个 primary parent；
- 不形成 cycle；
- duplicate relation 幂等 one-effect。

## effectiveNodes

返回：

```text
owned CENTER
+ inherited non-deleted EXPLANATION
+ owned non-deleted EXPLANATION
+ current-round TEMPORARY
```

每个 DTO 必须能标记：
- `owner_graph_id`
- `visibility = OWN | INHERITED`

按 `node_id` dedup，输出顺序 deterministic。

## 关键禁止

- 不要 INSERT inherited copy。
- 不要把 parent CENTER 放进 child。
- 不要把 parent Temporary 放进 child。
- 不要修改 inherited node 的 `graph_id`。
- 不要缓存继承 node id 列表为 relation snapshot。

snapshot 读取必须动态查询 relation + parent current Explanation。
