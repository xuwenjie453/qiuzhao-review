# Revision Fan-out & Patch Routing Prompt

实现 shared node 后，最危险的错误是只推进 owner graph revision。

## 定义

```text
AffectedGraphs(node)
= owner_graph(node)
+ every descendant graph whose effective view contains node
```

V1 业务虽然是一层 QB→Review，也请把查询设计成可递归或至少逻辑上不依赖“永远一层”。

## Structural mutation

以下操作改变 effective structural view：
- parent ADD EXPLANATION；
- shared Explanation RENAME；
- shared Explanation MOVE；
- shared Explanation DELETE；
- create/remove inheritance relation。

成功事务中必须明确推进所有 affected graph 的 `graph_revision` 与 `updated_at`。

## Ink 特例

Ink 不推进 graph_revision；继续使用 ink_revision channel。

## Patch 策略

不要把 fan-out 隐藏成“给 active iPad 发一次 owner patch”。对每个受影响 graph 都必须有可恢复的 canonical revision。

推荐：
- inheritance relation 初建：child 发送 snapshot；
- shared title/layout/delete：对已订阅/active affected graph 发送相应 patch；
- 无法可靠构造某 graph patch 时，可发送该 graph snapshot，但其 revision 必须已经正确推进。

## 必测

B owns E1，A/C inherit B：
- rename E1 后 B/A/C revision 均 +1；
- move E1 同理；
- delete E1 同理；
- Ink E1 后 B/A/C graph_revision 均不变；
- A 自有 X1 mutation 不推进 B/C。
