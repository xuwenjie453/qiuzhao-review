# daemon 幂等性缺陷：iPad"永久失联"根因报告与修复方案

- 发现时间：2026-09-13 13:44（五组锁屏对照实验结束后的追加观察中意外复现）
- 发现方式：Mac 侧现场取证（daemon 运行日志 + `dual-end.db` 查证 + 源码审读）
- 状态：**根因确认（代码级），修复方案已定，待用户批准实施**
- 关联文档：`00_五组实验总报告.md`（同日）

---

## 一、故障现象

用户在 40M 实验成功恢复后再次锁屏/解锁 iPad，App 不再恢复连接（徽章停留
"离线/正在连接"）。**与历史症状一致：长锁屏后失联、且以往"杀掉 App 重开"
这一最后手段在历史场景中也会失效。**

Mac 侧现场（13:44:07 取证）：

```text
daemon 进程: 活着（READY，bridge 65023，daemon_id 13b21820d37d）
sessions: 0
bridge TCP: 62507/62508/62509/62523/62524/62525 + 新增 62574/62575/62613/62614
           —— 全部 CLOSED（新端口 = iPad 反复重连的尸检记录）
daemon 日志: 每个连接循环打印同一模式——
  [daemon] upgrade 101 -> 192.168.1.200     ← WS 握手成功
  [daemon] ipad connected
  [daemon:error] onMessage error UNIQUE constraint failed: sync_journal.message_id
  ← 会话死亡；iPad ~10s 后重试，再死，无限循环
```

**结论：这次不是发现层/网络层问题——iPad 一直能找到并连上 daemon，
是 daemon 在应用层把每个会话杀死。**

## 二、证据链（全部 FACT）

1. `系统数据/dual-end/state/dual-end.db` 表结构：
   ```sql
   CREATE TABLE sync_journal(
     server_seq INTEGER PRIMARY KEY AUTOINCREMENT,
     message_id TEXT NOT NULL UNIQUE,   -- ★ 唯一约束
     ...)
   ```
2. `message_id='x'` 的行已存在（COUNT=1，历史上第一条 HELLO 写入）。
3. `DualEnd-Mac/src/bridge/sync-session.mjs:80`：
   ```js
   this.store.journal('x', 'WELCOME', null, { device_id: this.deviceId });
   //               ^^^ 硬编码 message_id
   ```
4. `DualEnd-Mac/src/store/state-db.mjs:137`：
   ```js
   'INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at) VALUES (?,?,?,?,?)'
   // 裸 INSERT，无 ON CONFLICT 处理
   ```
5. `sync-session.mjs:112 / :156`：`onClientCommand` / `onInkPut` 用**客户端
   envelope 的 message_id** 落 journal，重放消息必撞已有行。
6. iPad 侧（`DualEnd-iPad/.../SyncEngine.swift:100-112`）：outbox 为**持久化
   重放**设计——`onSocketOpen` → `restoreInflightToPending()` → `replayOutbox()`，
   未收到 ACK 的消息按**原 message_id** 重发。**这是协议正确行为
   （at-least-once + 服务端幂等去重），违反契约的是 daemon。**

## 三、两个缺陷的机制分析

### 缺陷 A：`journal('x')` 硬编码——每次 HELLO 必炸（背景噪声）

- 首条 HELLO 写入 `message_id='x'` 后，**此后每次连接的 HELLO 都在
  `sync-session.mjs:80` 抛 UNIQUE 异常**；
- 异常被 `onMessage` 的 try/catch 吞掉（只打日志），但导致：
  - `emit('hello')`（:81）不执行；
  - onHello 内的主动 snapshot 推送（:83-86）不执行；
- **为什么系统至今"看起来正常"**：WELCOME 在炸点**之前**（:73）已发出，
  iPad 收到 WELCOME 后会**主动**发 `SNAPSHOT_REQUEST` 续命（onSnapshotRequest
  路径无缺陷）——今天五组实验的"成功恢复"全部走的这条侥幸通道。
- 危害：每次连接日志报错 + hello 事件丢失 + 依赖客户端自救。

### 缺陷 B：客户端消息重放撞唯一键——"毒 outbox 项"永久炸弹（真凶）

形成时序（毒项诞生的唯一窗口）：

```text
iPad 发送 INK_PUT/CLIENT_COMMAND(message_id=M)
  → daemon: runCommand/putInk 执行成功
  → daemon: journal(M) 写入成功            ← M 已永久入库
  → daemon: 发送 ACK … ✗ 连接恰在此间死亡   ← ACK 未送达
  → iPad: M 留在持久 outbox（INFLIGHT→PENDING）
此后每一次连接（包括杀 App 后重开）：
  → replayOutbox 重发 M（同 message_id，协议正确）
  → daemon: journal(M) → UNIQUE 异常 → ACK 永远发不出
  → 会话死亡 → 重试 → 再死 → ∞
```

- 毒项跨 App 重启存活（存在 ClientStore 持久 outbox）→ **"杀掉 App 重开
  也无效"的直接解释**；
- `onInkPut` 有内层 catch 会回 COMMAND_REJECTED（iPad 收到 rejection 会清项，
  可自愈）；`onClientCommand` 的 journal 异常直接冒到外层 catch——**ACK 既没发、
  rejection 也没发**，死得最干净，是循环的主力嫌疑路径；
- 连接被关闭的直接触发点【UNKNOWN】（异常被 catch 后按代码不应杀会话；
  可能是异常路径的连带行为，修复后复测即可确认）。

## 四、历史症状统一解释

| 历史观察 | 本根因的解释 |
|---|---|
| 长锁屏后失联 | 锁屏制造了"journal 已写、ACK 未达"的时序窗口 → 毒项形成 |
| 杀 App 重开也无效（间歇） | 毒项在持久 outbox，重放即撞墙；无毒项时一切正常 → "间歇性" |
| 五组对照实验 0 复现 | 实验期间无毒项；用户失败的那次恰在毒项形成后（13:37 起 daemon 日志实证循环） |
| 12:27 发现 daemon 已死+残锁 | 独立的 daemon 稳定性隐患（死因未查），它同时是制造 ACK 丢失窗口的放大器 |
| Mac 熄屏 | 已由实验排除（1212 采样零断档） |
| Bonjour/发现层/iOS 恢复逻辑 | 本次实证全部无关（iPad 一直在连） |

**结论：所谓"长锁屏失联"是复合事件——锁屏/断连只是毒项的孵化器，
真正的病灶是 daemon 缺失消息幂等。**

## 五、修复方案（Mac 端，3 处改动）

### 5.1 `state-db.mjs`：journal() 幂等化（核心）

```js
// 修改前
const r = this.store.prepare(
  'INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at) VALUES (?,?,?,?,?)'
).run(message_id, kind, graphId ?? null, JSON.stringify(payloadObj), nowIso());
return Number(r.lastInsertRowid);

// 修改后：冲突 = 该消息已处理过 → 返回已有 server_seq（幂等），调用方照常 ACK
const r = this.store.prepare(
  `INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at)
   VALUES (?,?,?,?,?)
   ON CONFLICT(message_id) DO NOTHING`
).run(message_id, kind, graphId ?? null, JSON.stringify(payloadObj), nowIso());
if (r.changes === 0) {
  const row = this.store.prepare('SELECT server_seq FROM sync_journal WHERE message_id=?')
    .get(message_id);
  return Number(row?.server_seq ?? 0);
}
return Number(r.lastInsertRowid);
```

### 5.2 `sync-session.mjs:80`：消灭硬编码 'x'

```js
// 修改前
this.store.journal('x', 'WELCOME', null, { device_id: this.deviceId });
// 修改后
this.store.journal(`welcome-${this.epoch}`, 'WELCOME', null, { device_id: this.deviceId });
// epoch 每会话唯一（:67），天然幂等且可追溯
```

### 5.3 `onClientCommand` / `onInkPut`：重放 = 补 ACK（语义修正）

journal 幂等化后此两处**无需改动即自动正确**：重放消息 → journal 返回已有序号
→ ACK 照常发送（`:113` / `:157`）→ iPad 清项，毒项自愈。
（可选加固：`onClientCommand` 把 journal/ACK 段纳入内层 try，失败时回
COMMAND_REJECTED，避免任何未来异常静默吞 ACK。）

### 5.4 不改的部分

- iPad 端零改动（outbox 重放是正确设计）；
- 协议、schema、心跳、双端 fixtures 均不动；
- 既有 30 项 Mac 测试应全绿（`cd DualEnd-Mac && node --test test/`），
  新增幂等重放单测：同 message_id 二次 journal 返回同 seq、二次
  CLIENT_COMMAND 只产生一次效果并补发 ACK。

## 六、验证计划

1. 修后重启 daemon → 观察 iPad（无需操作）应自动恢复；
2. 复测毒项自愈：修复前 iPad 的 pending 项在首次重放后收到 ACK 清空；
3. 回归：Mac 测试 30+N 全绿；重做一次 20 分钟锁屏解锁，恢复延迟应 ≤ 退避
   首跳（~1-2s 级）且 daemon 日志不再出现 UNIQUE 错误；
4. 观察项：连接是否仍被异常关闭（若 5.1-5.3 修后仍有关闭现象，
   说明另有触发点，再追）。

## 七、遗留与关联问题（独立跟踪）

1. **daemon 生存性**：本会话两次发现 daemon 死亡（09-10 残锁、09-13 12:27
   残锁），死因未查（候选：随启动终端关闭/未脱离会话/崩溃）——它是制造
   ACK 丢失窗口的放大器，建议下一轮排查（launchd 服务化）；
2. **daemon 侧 CLOSED fd 堆积**（本次 10 个）：会话清理路径的次要泄漏，
   修复 5.3 时顺带观察，必要时补 sockets.delete 时序；
3. **iPad 侧 R1-R5 加固方案**（浏览器看门狗/前台复位等）：优先级维持
   "体验优化"——本根因修复后，恢复延迟与僵尸场景的价值重新评估。

## 八、Git 与执行

- 实施分支建议：`fix/daemon-sync-journal-idempotency`（基于当前
  `fix/pencil-live-render-v3`）；
- 单一 commit：3 处代码 + 单测；实施后 daemon 需重启一次生效；
- 本报告与 `00_五组实验总报告.md` 同目录归档。
