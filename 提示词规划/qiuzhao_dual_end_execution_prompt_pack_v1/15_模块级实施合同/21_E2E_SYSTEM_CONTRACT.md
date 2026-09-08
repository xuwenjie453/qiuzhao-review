# 完整 E2E 系统合同

一次成功流程的 canonical 顺序：

```text
Agent -> LocalControl question.open
Mac DB commit graph/round/journal
Mac -> iPad GRAPH_SNAPSHOT
iPad DB commit snapshot/inbox
iPad -> Mac ACK

Agent explains (no graph mutation)

User explicitly selects explanation
Agent -> LocalControl node.add exact markdown
Mac commit node/layout/journal
Mac -> iPad GRAPH_PATCH
iPad commit patch/inbox -> ACK

iPad drag/rename
iPad local transaction + outbox
iPad -> Mac CLIENT_COMMAND
Mac CAS + commit + journal -> ACK/PATCH
iPad durable canonical update + clear outbox

iPad Pencil
PencilKit immediate render
ClientStore full PKDrawing snapshot + outbox
Mac ink.put commit -> ACK

Agent question.close
Mac expire temp + journal
iPad remove temp

same question reopen
same graph_id
new round_id
persistent/ink remain
old temp absent
```

任何实现若顺序在 durability/authority 上反转，必须修正。
