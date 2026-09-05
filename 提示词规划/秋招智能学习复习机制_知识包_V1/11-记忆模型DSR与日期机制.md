# Difficulty / Stability / Retrievability 记忆模型

长期记忆不能保存成：

`mastered = true`

因为半年后会失真。

## 1. Difficulty｜D

表示：

> 对这个用户而言，该能力的稳定记忆有多难建立。

不是题目客观难度。

## 2. Stability｜S

表示：

> 记忆衰减速度。

可以理解为：

> 在不复习情况下，Retrievability 下降到约 90% 所对应的时间尺度。

S 越大，记忆越稳定。

## 3. Retrievability｜R

表示：

> 如果现在突然测试，成功从长期记忆中提取的预测概率。

R 随：

`当前日期 - 上次有效提取`

下降。

## 4. 为什么日期是核心

例如：

```text
2026-09-05 GapLock Learning Verified
2026-09-08 Review Success
2026-09-15 Review Success
```

到了 2027-03：

历史仍然保留。

但当前 R 应显著下降。

因此：

> 曾经掌握 ≠ 现在一定会。

同时：

> 现在忘了 ≠ 从未学过。

## 5. 初始 Stability

Review Capsule 只有在 Learning Verified 后出生。

初始 S 可以根据学习证据决定：

### 较弱
Repair 多次、刚刚勉强通过。

### 较强
无辅助原题正确 + 迁移成功。

## 6. Review 成功

跨日期成功：

> S 增长。

成功次数越多，长期间隔自然扩大。

## 7. Review 失败

失败：

> S 降低，但不归零。

如果历史曾非常稳定：

> Relearning 通常比首次学习快。

## 8. Repair 后成功不能覆盖原失败

必须保留：

- RETRIEVAL_FAILURE
- REPAIR_SUCCESS

调度模型要知道真正的延迟检索失败过。
