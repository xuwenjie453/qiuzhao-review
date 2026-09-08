# Mac QuestionGraphService 合同

建议 query：
```text
getGraphByQuestionKey(questionKey)
getGraph(graphId)
snapshot(graphId, roundId?)
getActiveRound()
getNode(nodeId)
```

建议 command：
```text
openQuestion(commandId, questionRef, centerBody, aiTitle)
closeQuestion(commandId, roundId)
addNode(commandId, roundId, kind, exactBodyMarkdown, aiTitle, originTurnRef?)
renameNode(commandId, nodeId, title, baseNodeRevision)
moveNode(commandId, nodeId, xNorm, yNorm, baseLayoutRevision)
deleteNode(commandId, nodeId, baseNodeRevision)
putInk(commandId/messageId, nodeId, inkRevision, format, blob, sha256)
```

每个 command：
1. dedup lookup；
2. load；
3. invariant/CAS；
4. mutate；
5. journal；
6. save result；
7. COMMIT；
8. caller 才可 emit。

关键错误：
CENTER_DELETE_FORBIDDEN、ROUND_NOT_ACTIVE、NODE_REVISION_CONFLICT、LAYOUT_REVISION_CONFLICT、NODE_BODY_IMMUTABLE、INK_REVISION_GAP。

`addNode`：
- 只能 EXPLANATION/TEMPORARY；
- TEMPORARY 要 active round 且 round_id 一致；
- exactBodyMarkdown 不重写；
- initial layout deterministic；
- graph_revision++。

`openQuestion`：
- ensure stable graph；
- first create CENTER；
- interrupt any previous active round；
- create new round；
- return full visible snapshot。
