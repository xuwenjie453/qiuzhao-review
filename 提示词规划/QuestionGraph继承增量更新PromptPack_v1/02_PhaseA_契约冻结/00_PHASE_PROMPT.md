# Phase A — 契约冻结 Prompt

本阶段的目标不是改实现，而是把设计稿翻译成可执行、不含歧义的实现契约与测试断言。

## 冻结项

确认并写入阶段记录：

- child source = REVIEW_CAPSULE；parent source = QUESTION_BANK。
- kind = SHARED_EXPLANATIONS。
- V1 runtime child 最多一个 primary parent。
- inherited kinds = EXPLANATION only。
- inherited node identity unchanged。
- effective view = owned visible + inherited explanation。
- parent 新 Explanation 动态可见。
- child Explanation 不反向传播。
- rename/move/delete structural change 影响 owner + visible descendants 的 graph_revision。
- Ink 不进入 graph_revision。
- inherited delete = global delete + UI warning。
- primary_source_question_id 是明确来源锚点。
- missing parent 不阻塞 Review。

## 必须产出

把上述契约映射到待新增测试名称。每条产品规则至少对应一个自动测试或明确的手工 Gate。

如果当前设计稿中有无法直接实现的矛盾，停止在本阶段提出冲突；不要通过改语义来“解决”。
