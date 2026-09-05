# Goal-aware Temporal Scheduler

Scheduler 是整个系统最高级的决策模块。

它不回答：

> 哪些题到期？

而回答：

> 在当前 Goal、日期、记忆、覆盖和成本约束下，下一单位注意力投入哪里最有价值？

## 1. 两只时钟

### Memory Clock
这个 Capsule 离上次成功多久，当前 R 多低。

### Goal Clock
距离当前目标结束还有多久。

两者必须共同决定调度。

## 2. Desired Retention

不同 Goal 对记忆保持要求不同。

### Coverage
允许普通内容下降到较低 R，保护新学习空间。

### Sprint
提高 Retention、Importance、Weakness 权重。

### Maintenance
低成本维持。

### Reactivation
快速重新诊断过去学过但久未检索内容。

## 3. Due 只是候选

`next_due_at`

不是：

> 今天必须完成。

而是：

> 成为一个高价值 Review Candidate。

## 4. Review Utility

可综合：

- Goal Relevance
- Importance
- Memory Urgency
- Dependency Value
- Recent Weakness
- Diversity
- Expected Cost

## 5. Learning Utility

可综合：

- Goal Relevance
- Importance
- Coverage Need
- Novelty Value
- Dependency Value
- Diversity
- Expected Learning Cost

## 6. Review 与 New Learning 统一竞争

Coverage Goal 下：

> 不能让 Review Debt 吞掉全部时间。

即使有大量到期旧内容：

- 优先重要节点；
- 优先依赖节点；
- 同时继续新学习。

## 7. 连续权重漂移

25天计划不硬切 Day1-8 / Day9-17。

随着：

- 日期进度；
- 实际覆盖进度；
- Review Debt；
- 弱项数量；

连续改变权重。

## 8. 半年后 Reactivation

系统不显示：

> 800条逾期。

而是优先：

- ★★★★★；
- 基础依赖；
- 过去稳定；
- 久未检索；
- 具有代表性的 Capsule。

用轻量 Probe 快速重新估值。
