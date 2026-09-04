# Review Engine 构建 Prompt

核心定义：

> Review is a Probe, not a Re-learning Session.

## 入口
只有 `REVIEW_ELIGIBLE` Capsule 才能被调度。未 Learning Verified 的内容不能进入普通 Review。

## 默认行为
1. Scheduler 选择 Capsule；
2. Review Engine 读取 Capsule；
3. 动态物化一个最短有效 Probe；
4. 不先给资料、答案、提示；
5. 用户冷启动回答；
6. AI判断。

## 成功
一次无辅助成功：立即结束。

记录：
- REVIEW_SUCCESS
- 内部 grade
- evidence
- occurred_at

然后交回 Scheduler。

## 失败分流
### Knowledge
局部遗漏 → Tiny Repair；核心结构丢失 → Knowledge Learning。

### Algorithms
API/边界/构造局部 → 对应 Skill Repair；Pattern 整体丢失 → Algorithms Learning。

### Projects
局部 trade-off/failure → PSB Repair；整体工程 reasoning 丢失 → Projects Learning。

## Repair 后成功
不能把初始失败改成成功。必须同时记录：
- REVIEW_FAILURE
- REPAIR_SUCCESS

Scheduler 将其视为 lapse。

## Probe 原则
Knowledge：短生成式解释。
Algorithms：Micro Probe，不重做完整原题。
Projects：短工程判断/解释。

轻量不等于选择题，优先生成式回忆。

## Algorithm Review
本轮不测试的所有前置信息必须给出来。
例如复习 TreeConstruction 时提供 TreeNode、函数签名和输入结构，只要求用户补核心构造逻辑。

完整算法题属于低频 Integration Review，不属于普通 Capsule Review。

## Probe 来源
优先真人题的高信息量局部/变式；必要时 AI 临时生成。临时 Probe 不进入正式题库。
