# 双端实体设备联调提示词

请在问题图和 Reader 单项测试通过后做 Mac/iPad 联调。

## 启动

确认：

```bash
node DualEnd-Mac/bin/qreview-dual.mjs daemon status
```

必要时启动：

```bash
node DualEnd-Mac/bin/qreview-dual.mjs daemon start
```

不要让用户手工输入 IP、端口或验证码。

## 联调场景

1. Mac 打开测试 question round；
2. iPad Bonjour 自动发现并连接；
3. Mac 添加 explanation/temporary 节点；
4. iPad 点击、拖动、双击节点；
5. iPad 离线拖动并书写；
6. 恢复网络，确认 outbox、layout、ink ACK；
7. Mac 同时改变另一个节点；
8. iPad 退出重启后验证缓存；
9. 横竖屏切换后验证位置和笔迹。

## 证据

记录：

- daemon 状态、端口和 session 数；
- iPad 型号、系统版本、方向；
- snapshot/patch revision；
- layout revision、command_id、ACK/reject；
- Reader layout signature；
- 测试截图或视频路径；
- 任何失败的最小复现步骤。

如果无法访问实体 Apple Pencil，必须标记 `BLOCKED_BY_DEVICE`，不得把 Simulator 结果当 Pencil PASS。

