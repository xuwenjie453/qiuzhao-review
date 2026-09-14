# Learning Event → Primary Source Trace Prompt

在给 Capsule 填 `primary_source_question_id` 前，先证明该来源能从真实学习上下文稳定获得。

## 追踪任务

检查：
- `learning_events.question_id` 如何写入；
- LEARNING_VERIFIED 是否保留当前正式题 identity；
- Algorithms/Knowledge/Projects 的 learn verify 调用是否都能拿到 question_id；
- Repair/Transfer 生成 capsule 时可能没有单一正式题的情况。

## 规则

优先来源：当前产生该长期记忆 Capsule 的明确正式 Question Bank 会话。

不得：
- 按最近一个 learning_event 猜；
- 从 `source_questions` 排序猜；
- 从 target_id 映射到任意题；
- 为了提高 inheritance 覆盖率伪造 primary source。

如果某路径无法稳定得到来源，明确保留 NULL，并在后续架构优化中单独处理。
