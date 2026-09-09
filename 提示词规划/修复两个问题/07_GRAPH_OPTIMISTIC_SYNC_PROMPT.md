# 问题一：拖动与双端同步状态机提示词

请修复拖动结束后节点回弹、旧 ACK 覆盖新位置和 layout CAS 冲突造成的跳动。

## 三层位置状态

每个节点至少区分：

```text
canonical：Mac 已确认位置
pending：iPad 已本地持久化并等待 ACK 的位置
dragging：当前手势中的瞬时位置
```

显示优先级必须是：

```text
dragging ?? pending ?? canonical
```

## 松手顺序

松手时必须按以下顺序：

1. 把最后 dragging 写入 pending；
2. 立即停止 dragging，但继续显示 pending；
3. 先写入 iPad durable store；
4. 创建带 command_id/base_layout_revision 的 outbox；
5. 发送网络命令；
6. 只有收到对应 ACK 后才清除 pending。

禁止先清 transient、再等待异步 Store 写入，否则会短暂恢复旧坐标。

## ACK 与拒绝

- ACK 必须按 command_id 匹配；旧 ACK 不得覆盖更新的拖动；
- ACK 中的 canonical layout_revision 必须写回本地；
- CAS_MISMATCH 时获取最新 layout；
- 若用户没有再次拖动，允许基于新 revision 自动重试一次；
- 若用户已经再次拖动，旧命令只能结束，不能覆盖新 pending；
- 重试失败必须显示可诊断错误并回到服务器位置，不得静默抖动。

## 断网

断网时拖动仍应立即显示并持久化。恢复连接后由 outbox 重放。不要因为 daemon 离线而撤销本地位置。

加入延迟 ACK、拒绝、重复 ACK、断线重连测试。

