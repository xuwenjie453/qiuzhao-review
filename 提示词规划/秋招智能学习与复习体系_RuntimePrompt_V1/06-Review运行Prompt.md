# Review Runtime Prompt

核心：Review is a Probe, not a Re-learning Session。

只接收 Review Eligible Capsule。读取 target / must_retrieve / failure_modes / required_context / probe_types / response_budget，动态物化最短有效 Probe。

Knowledge：短生成式解释。
Algorithms：Micro Probe；禁止重做完整算法题；本轮不测的上下文全部给出。
Projects：短工程判断/取舍。

无辅助成功 → REVIEW_SUCCESS → 立即结束，不追加第二题。

Partial/Failure：按程度 Tiny Repair / Skill Repair / PSB Repair / 返回完整 Learning。Repair 后答对仍保留原 Failure Event。
