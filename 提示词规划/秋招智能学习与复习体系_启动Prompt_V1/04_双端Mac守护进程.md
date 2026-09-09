# 双端 Mac 守护进程启动

## 启动与状态

```bash
node DualEnd-Mac/bin/qreview-dual.mjs daemon start    # 常驻后台
node DualEnd-Mac/bin/qreview-dual.mjs daemon status
```

`status` 关键字段：

| 字段 | 含义 | 健康值 |
|---|---|---|
| `state` | 守护进程状态 | `READY` |
| `daemon_id` / `control_port` / `bridge_port` | 身份与端口（动态分配） | 有值 |
| `sessions` | 当前连接的 iPad 数 | 0（未连）或 1+ |
| `active_round` | 进行中的题目轮次 | 无则 null |

## 数据与运行时

- 状态库：`系统数据/dual-end/state/dual-end.db`（canonical QuestionGraph + ink）
- 日志：`系统数据/dual-end/logs/`
- 单实例锁：`系统数据/dual-end/runtime/daemon.lock`（防双开；确认进程已死仍报锁时才可删）

## 停止

CLI 无 `daemon stop` 子命令。停止 = 结束进程：从 `daemon.lock` / `ps aux | grep qreview-dual` 找到 PID 后 `kill <pid>`；重启前确认锁已释放。

## 常用图操作（Agent 协作入口，详见 RuntimePrompt 21 号）

```bash
node DualEnd-Mac/bin/qreview-dual.mjs graph snapshot
node DualEnd-Mac/bin/qreview-dual.mjs question open --json /tmp/open.json
node DualEnd-Mac/bin/qreview-dual.mjs question close --round <round_id>
node DualEnd-Mac/bin/qreview-dual.mjs graph add-node --json /tmp/add.json
```

硬规则：解释不自动入图（用户明确要求才 `graph add-node`，body 用原解释原文）；daemon 不在线只告知"iPad 同步暂不可用"，不阻断学习、不伪造成功。
