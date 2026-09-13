# Repository Recon Prompt

对 inheritance 相关代码做“调用链级”侦察，而不是只列目录。

## Mac
追踪：

```text
question.open
→ graph create/open
→ node rows/layout rows
→ snapshotPayload
→ daemon broadcastGraphChange/buildPatch
→ SyncSession
```

再追踪：

```text
RENAME_NODE / MOVE_NODE / DELETE_NODE / INK_PUT
→ visibility/ownership checks
→ CAS
→ graph_revision
→ journal
→ patch/ACK
```

## iPad
追踪：

```text
GRAPH_SNAPSHOT
→ codec
→ ClientStore.applySnapshot
→ graphs_cache/nodes_cache
→ QuestionGraphState
→ Topology
→ ReaderRoute(node_id)
```

以及本地 mutation：

```text
UI
→ local durable mutation
→ outbox
→ SyncEngine
→ CLIENT_COMMAND
→ ACK / canonical patch
```

## Learning/Review
追踪：

```text
LEARNING_VERIFIED
→ compile_capsule
→ review_capsules/source_questions
→ scheduler
→ materialize probe
→ Runtime question.open(REVIEW_CAPSULE)
```

输出每条链路中的具体函数/文件名，并标记 inheritance 需要插入的最小切点。不要提出大规模框架重写。
