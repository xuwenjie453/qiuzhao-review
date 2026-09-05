# Learning 与 Review 的职责分离

## Learning Engine

目标：

> 把“现在不会”转化为“现在能够无辅助完成”。

允许：

- 教学；
- 资料；
- Worked Example；
- Prompting；
- Repair；
- 多次验证；
- 迁移题。

结束状态：

`LEARNING_VERIFIED`

## Review Engine

目标：

> 检查过去学会的能力今天是否仍能提取。

默认不教学。

流程：

```text
Cold Probe
↓
Success
→ 立即结束

Partial / Failure
→ Repair 或返回 Learning
```

## 为什么必须分开

如果 Review 同样重新讲一遍内容：

- 无法测出真正长期记忆；
- 复习成本无限膨胀；
- 用户产生“熟悉感 = 掌握”的错觉。

如果 Learning 过早结束：

- 根本没有建立 schema；
- Review 队列会充满“其实从没学会”的内容。

所以：

> 只有 Learning Verified 的能力，才拥有 Review Eligibility。
