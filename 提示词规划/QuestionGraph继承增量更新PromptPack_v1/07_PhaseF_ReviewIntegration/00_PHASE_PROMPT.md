# Phase F — Learning / Review Integration Prompt

在 canonical/wire/iPad 已支持 inheritance 后，把业务生命周期接上。

目标链路：

```text
Question Bank learning
→ LEARNING_VERIFIED
→ Review Capsule(primary_source_question_id)
→ Scheduler
→ Review Probe materialization
→ question.open(REVIEW_CAPSULE, inherit_from=QUESTION_BANK)
→ effective Review graph
```

## 关键规则

- `source_questions` 是证据集合，不是稳定 parent selector；
- 新增 `primary_source_question_id`；
- 编译 Capsule 时只有明确来源才能写 primary source；
- 无法确定时留空并记录诊断，不猜；
- Review open parent graph 缺失时不阻塞复习；
- Runtime Agent 只声明 inherit_from，不复制 Explanation；
- GraphService 是 effective view 唯一事实计算者。

## Gate

学习系统 E2E 必须证明：verified learning → capsule 有 primary source → Review open 建 inheritance；另有 missing-primary/missing-parent 场景仍可 Review。
