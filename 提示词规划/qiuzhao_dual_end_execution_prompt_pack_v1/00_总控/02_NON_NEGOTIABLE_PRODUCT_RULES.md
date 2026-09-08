# 冻结产品规则 — 实施 AI 不得自行更改

以下均是 MUST / MUST NOT。

1. 此次是双端扩展，不重构 Goal/Scheduler/三引擎/Events/Review/RAG。
2. Question 是双端最小业务中心，来源仅：
   - QUESTION_BANK
   - REVIEW_CAPSULE
3. 每个稳定 `question_key` 对应稳定 `graph_id`。
4. CENTER：
   - 正方形；
   - 每图唯一；
   - body 是问题正文快照；
   - title 可改；
   - 永不可删。
5. EXPLANATION：
   - 圆形；
   - 仅用户显式指定解释后创建；
   - body 必须是用户指定的 AI 原解释 Markdown，不“整理改写”；
   - 永久。
6. TEMPORARY：
   - 三角形；
   - 仅用户显式指定；
   - 必须绑定当前 round；
   - round close 后从可见图移出；
   - 下一轮不能复活。
7. Daemon 不做“解释是否重要”的 AI 判断。
8. iPad：
   - 高层问题图；
   - 低层节点 Reader；
   - 不承担 Agent 对话；
   - 不允许改 body；
   - title/layout/delete(非CENTER)/Ink 可本地操作。
9. Node body commit 后 immutable。
10. Ink 永久按 `node_id` 绑定，不按 title 或 body hash。
11. Reader 采用稳定单一内容坐标系，Markdown 与 Ink 不能使用两个独立滚动源硬同步。
12. Apple Pencil 用 PencilKit；硬件双击用 `UIPencilInteraction`。
13. 同一 LAN 下自动发现和自动连接：
   - 不输入 IP；
   - 不输入端口；
   - 不输入验证码；
   - 不要求用户选 Mac 作为正常流程。
14. Mac canonical；iPad local-first cache/outbox。
15. Mac mutation durable 后才 emit/ACK。
16. iPad apply durable 后才 ACK。
17. duplicate message / command 必须 one effect。
18. patch base revision mismatch 必须请求 snapshot，不盲 apply。
19. Ink revision 与 graph revision 分离。
20. 参考 PDF 未提供时，排版值不得伪造“已匹配”。

任何代码路径违反上述规则，视为 Release Blocker。
