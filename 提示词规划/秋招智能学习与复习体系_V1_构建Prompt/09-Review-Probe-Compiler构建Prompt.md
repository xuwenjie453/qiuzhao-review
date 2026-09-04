# Review Probe Compiler 构建 Prompt

目标：把复杂 Learning 压缩成未来低成本可检索的 Review Capsule。

禁止：`原题做完 → 原题直接进复习队列`。

## 输入
- learned nodes
- repaired nodes
- fragile nodes
- stable prerequisites
- source question ids
- evidence
- engine type

## 编译流程

```text
Learning Complete
→ 提取真正新学/修复能力
→ 去除已稳定前置
→ 合并过细节点
→ 判断是否值得长期保持
→ 生成 Review Capsule
→ REVIEW_ELIGIBLE
```

## 值得长期复习的条件
至少满足之一：
- 从不会到会；
- 本次发生 Repair；
- 迁移仍脆弱；
- 高频核心技能；
- 大量后续知识依赖。

## Capsule 字段
- capsule_id
- target_id
- engine_type
- must_retrieve
- known_failure_modes
- allowed_probe_types
- required_context
- response_budget
- source_questions
- eligibility_evidence
- compiler_version

## Knowledge Capsule
例如 `MySQL/GapLock`：
- must_retrieve：锁定对象、作用、与 Next-Key 的基本边界。

## Algorithm Capsule
例如 `Tree/RecursiveConstruction`：
- must_retrieve：base case、subtree decomposition、return node；
- required_context：TreeNode、参数、输入结构、返回值要求；
- allowed_probe：Complete / Construct / Repair / Boundary / StateDefinition / APIRecall / Trace / SkeletonFill；
- response_budget：small_code。

原则：本轮不测试的东西全部给出来。

## Project Capsule
例如 `MQ/PartitionConstraint`，Probe 可以是：
“增加消费者实例但吞吐不变，优先检查什么限制？”

## 过细合并
不要把 deque.append / popleft / init 分成三个 Capsule；合并成 `Python/DequeBasicOperations`。

## 输出
写各引擎自己的 review_capsules，并在 scheduler.sqlite3 激活最小 schedule 状态。绝不写入 questions.sqlite3。
