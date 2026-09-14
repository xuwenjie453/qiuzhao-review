# Inheritance Contract Audit Prompt

在进入 Mac 实现前做一次反例审计。逐一回答系统在以下场景必须发生什么：

1. Review A 继承 QB B，B 有 E1/E2。
2. A 与 B 的 CENTER 文本不同。
3. B 后来新增 E3。
4. A 自己新增 X1。
5. 第二个 Review C 也继承 B。
6. A 重命名 E1。
7. C 拖动 E1。
8. B 给 E1 写 Ink。
9. A 删除 E1。
10. parent graph 不存在。
11. `primary_source_question_id` 缺失。
12. 重复提交相同 inheritance relation。
13. child 想继承 REVIEW_CAPSULE。
14. parent 想继承 child 形成 cycle。
15. iPad 持有旧 revision 时 sibling 修改 shared node。

把每个场景写成 `Given / When / Then`。其中 1–9 必须有明确一致的最终 canonical state。完成此审计后才能进入 Phase B。
