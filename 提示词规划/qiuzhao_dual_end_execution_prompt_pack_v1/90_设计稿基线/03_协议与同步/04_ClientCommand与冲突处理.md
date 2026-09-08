# Client Command 与冲突处理

## 1. CLIENT_COMMAND

```json
{
  "command_id":"uuid",
  "kind":"RENAME_NODE",
  "graph_id":"...",
  "payload":{
    "node_id":"...",
    "title":"新标题",
    "base_node_revision":3
  }
}
```

支持：

- `RENAME_NODE`
- `MOVE_NODE`
- `DELETE_NODE`

## 2. 为什么不用全图 base_revision 做 client mutation 冲突

Mac Agent 可能正在添加 Explanation，同时 iPad 正在移动旧节点。若所有命令都要求全图 revision 相等，会产生大量无意义冲突。

所以：

- rename/delete 对 `node_revision` CAS；
- move 对 `layout_revision` CAS；
- ink 对 `ink_revision` 序列；
- server 接收成功后统一 graph_revision++ 并广播 patch。

## 3. 冲突策略

### MOVE

布局只由 iPad 用户操作；revision 冲突时 server 返回当前 layout，iPad 若该 move 仍在 outbox 顶部可基于新 revision 重试一次。

### RENAME

Agent v1 不主动改已存在 title，因此实际只有 iPad writer。若冲突，显示 server title 并保留用户未提交文本草稿，允许用户再次保存。

### DELETE

若节点已 deleted，视为幂等成功；CENTER 永远 reject。

## 4. 响应

`COMMAND_ACK` 必须包含 canonical revisions；iPad 用它清 outbox，而不是以“socket send 成功”视为提交成功。
