# Temporal Scheduler 构建 Prompt

你负责构建整个系统最高级决策模块。

Scheduler 不教学，只输出下一项 `TaskIntent`。

## 输入
- Active Goals
- 当前日期
- Goal Progress
- Knowledge states
- Algorithm states
- Project states
- Review schedule
- Coverage gaps
- Importance
- Historical failures
- Engine expected cost

## Memory Model
采用 FSRS-inspired：
- Difficulty D
- Stability S
- Retrievability R

R 根据 elapsed time 和 S 实时计算，不永久存储。

V1 可使用透明可解释曲线；必须保留接口，以后可以升级为完整 FSRS-6 型曲线而不改变历史 Event 数据。

## Desired Retention
不能全局固定。
根据：
- Goal type
- Importance
- Dependency value
- Goal remaining time
- engine type
动态决定。

Coverage Goal：允许普通节点更宽松，保护新学习。
Sprint：Retention / Weakness / Importance 提高。
Maintenance：降低复习频率。
Reactivation：优先代表性、高重要、过去稳定但久未检索节点。

## 任务候选
至少：
- LEARN
- REVIEW
- REPAIR
- TRANSFER / INTEGRATION

## 不是 Due Queue
`next_due_at` 只是缓存/候选时点。
到期意味着进入竞争，不意味着必须先清空。

## Utility
Review 参考：
- GoalRelevance
- Importance
- MemoryUrgency
- DependencyValue
- WeaknessFactor
- DiversityAdjustment
- ExpectedCost

New Learning 参考：
- GoalRelevance
- Importance
- CoverageNeed
- NoveltyValue
- DependencyValue
- DiversityAdjustment
- ExpectedLearningCost

不要追求虚假数学精确；要保持可解释、可调参、可版本化。

## 25天 Coverage 连续漂移
不要硬编码 Day1-8 / Day9-17。
结合：
- Goal time progress
- actual coverage progress
- review debt
- weakness
连续调整。

前期新学习强；后期 Retention / Weakness / Transfer 增强。

## Review Debt
内部计算即可，不向用户展示“欠了多少条”。
中断3~7天后，不要求先清空所有旧复习；Coverage Goal 仍然保留新学习。

## 用户临时覆盖
自然语言：
- 今天只学MySQL
- 先做算法
- 今天不做项目
- 明天有面试

可生成 session-level temporary policy，不破坏长期 Goal 历史。

## TaskIntent 输出
至少：

```json
{
  "intent_type": "LEARN",
  "engine": "Knowledge",
  "target_id": "...",
  "reason": "...",
  "goal_id": "...",
  "priority_context": {}
}
```

Scheduler 不生成题干或教学内容。

## 版本化与测试
记录 scheduling_version。
测试：
- Coverage early/mid/late
- Sprint
- Six-month reactivation
- 3-day absence with review debt
- multiple active goals
