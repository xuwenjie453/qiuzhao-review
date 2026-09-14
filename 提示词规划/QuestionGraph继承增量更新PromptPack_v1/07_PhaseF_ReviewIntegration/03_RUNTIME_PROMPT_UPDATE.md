# Runtime Prompt Update Prompt

更新 Runtime 双端协议时，目标是改变 Agent 行为边界，而不是让 Prompt 代替 GraphService。

重点更新：

`提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/21_双端问题图与iPad协作协议.md`

## 必须增加的规则

1. 正式 LEARN/REPAIR Question Bank 问题继续 `question.open(QUESTION_BANK)`。
2. Review Probe 继续 `question.open(REVIEW_CAPSULE)`，并在 capsule 有明确 primary source 时声明 `inherit_from` 对应 QUESTION_BANK QuestionRef。
3. Agent **禁止**读取 parent Explanation 后逐个 `graph.add-node` 复制到 Review graph。
4. inherited Explanation 是否出现由 GraphService effective view 决定。
5. 用户在 Review 对 inherited node rename/move/Ink 都作用于共享 canonical node。
6. 用户要求删除 inherited node 时，应理解为 global shared delete；iPad 负责最终明确确认。
7. parent graph 缺失不阻塞当前 Review。
8. Review 自己新增 Explanation 归当前 Review graph，不回写原题图。

## 文案边界

不要把 storage schema、SQL、revision 算法暴露给正常学习用户。Prompt 中应表达业务动作与 Agent 责任，底层一致性留给代码。
