# 双端 Mac 守护进程启动

## 一、固定网络身份（2026-09-13 起，重要）

双端通信已从"Bonjour 零配置发现"改为**静态端点直连优先**，网络身份全部固定：

| 项 | 值 | 配置位置 |
|---|---|---|
| Mac 静态 IP | `192.168.1.197` | 路由器 DHCP 静态分配（用户已配置） |
| iPad 静态 IP | `192.168.1.200` | 路由器 DHCP 静态分配（用户已配置） |
| daemon bridge 端口 | **`57689`**（固定） | `DualEnd-Mac/bin/daemon-fixed.sh` 的 `FIXED_PORT` |
| iPad 静态端点默认值 | `192.168.1.197:57689` | `DualEnd-iPad/.../Connectivity/BonjourBrowser.swift` 的 `StaticEndpoint.defaultHost/defaultPort` |

**为什么固定**：VPN（TUN + fake-ip 模式）会劫持 `.local` 主机名解析（实测解析成 `198.18.x.x` 假地址）并干扰 mDNS 组播，导致 Bonjour 发现与连接随 VPN 状态漂移。静态直连是纯 `IP:Port`，不碰 mDNS、不碰 DNS 解析，VPN 只要不劫持局域网直连即完全无影响。

**改动时必须同步的对应关系**（改一处必须核对另一处）：

- 改 bridge 端口 → 同时改 `daemon-fixed.sh` 的 `FIXED_PORT` **和** iPad 端 `StaticEndpoint.defaultPort`
- 改 Mac IP → 改 iPad 端 `StaticEndpoint.defaultHost`，或用 `devicectl` 写 UserDefaults `dualend.static.host`（免重编译）

## 二、启动与状态（一律用固定端口脚本）

```bash
./DualEnd-Mac/bin/daemon-fixed.sh start     # 固定端口 57689 启动（nohup 脱离 + 清理孤儿广播）
./DualEnd-Mac/bin/daemon-fixed.sh stop      # 优雅停止（SIGTERM + 清理孤儿 dns-sd）
./DualEnd-Mac/bin/daemon-fixed.sh restart   # 重启
./DualEnd-Mac/bin/daemon-fixed.sh status    # 状态
```

> 不要直接用 `node DualEnd-Mac/bin/qreview-dual.mjs daemon start` 裸启动——那会用**随机端口**，iPad 静态直连立刻失效（随后只能靠逃生门退回 Bonjour，受 VPN 干扰）。
> 脚本会顺手清理**孤儿 dns-sd 广播进程**（daemon 非正常退出时的残留，会导致服务名冲突/死端口——详见 07 号）。

`status` 关键字段：

| 字段 | 含义 | 健康值 |
|---|---|---|
| `state` | 守护进程状态 | `READY` |
| `daemon_id` | 守护进程身份（稳定） | 有值 |
| `bridge_port` | iPad 连接端口 | **必须是 `57689`** |
| `control_port` | 本机 CLI 控制端口（随机，无妨） | 有值 |
| `sessions` | 当前连接的 iPad 数 | 0（未连）或 1+ |
| `active_round` | 进行中的题目轮次 | 无则 null |

启动日志：`系统数据/dual-end/logs/daemon-stdout.log`。

## 三、iPad 端静态直连机制（配套）

- 连接优先级：**静态直连** `192.168.1.197:57689` → （静态连续失败 5 次）→ Bonjour 发现一轮 → （无候选）回退静态；
- 会话建立成功（WELCOME）后失败计数复位；
- **关闭静态**（回退纯 Bonjour）：UserDefaults 写 `dualend.static.disabled = true`；
- **覆盖地址/端口**：UserDefaults 写 `dualend.static.host` / `dualend.static.port`；
- 验证静态直连是否生效：Debug 构建启动日志出现 `[diag] 静态端点直连: static://192.168.1.197:57689`（且**没有** `browse results` 行）。

iPad 构建/安装/配置注入见 `05_iPad端构建安装.md`。

## 四、数据与运行时

- 状态库：`系统数据/dual-end/state/dual-end.db`（canonical QuestionGraph + ink）
- 日志：`系统数据/dual-end/logs/`
- 单实例锁：`系统数据/dual-end/runtime/daemon.lock`（防双开；确认进程已死仍报锁时才可删）

## 五、常用图操作（Agent 协作入口，详见 RuntimePrompt 21 号）

```bash
node DualEnd-Mac/bin/qreview-dual.mjs graph snapshot
node DualEnd-Mac/bin/qreview-dual.mjs question open --json /tmp/open.json
node DualEnd-Mac/bin/qreview-dual.mjs question close --round <round_id>
node DualEnd-Mac/bin/qreview-dual.mjs graph add-node --json /tmp/add.json
```

硬规则：解释不自动入图（用户明确要求才 `graph add-node`，body 用原解释原文）；daemon 不在线只告知"iPad 同步暂不可用"，不阻断学习、不伪造成功。
