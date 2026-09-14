# Definition of Done

以下全部满足，QuestionGraph inheritance 增量更新才算完成：

- [ ] 权威设计未被重新解释。
- [ ] Mac schema version 升级且 v1→v2 无损 migration 测试通过。
- [ ] graph_inheritance relation 有 source/self/cycle/cardinality guard。
- [ ] Review effective view 包含 own CENTER + inherited EXPLANATION。
- [ ] CENTER/TEMPORARY 不继承。
- [ ] inherited node same node_id。
- [ ] parent later Explanation 动态进入 child。
- [ ] child own Explanation 不进入 parent/sibling。
- [ ] shared rename/move/delete write-through。
- [ ] Ink node-scoped shared。
- [ ] affected graph structural revisions 正确 fan-out。
- [ ] Ink 不推进 graph_revision。
- [ ] wire DTO/fixture/version 完整。
- [ ] iPad canonical node/cache membership 正规化。
- [ ] snapshot/patch/outbox/durability 恢复语义通过。
- [ ] inherited delete 明确全局影响确认。
- [ ] review_capsules 有 primary_source_question_id。
- [ ] 不从 source_questions[0] 推断。
- [ ] Review open 自动声明 inheritance。
- [ ] missing parent / legacy capsule graceful degradation。
- [ ] Mac/Bridge/iPad/Learning automated tests 全绿。
- [ ] Release checklist 更新。
- [ ] 真机未执行项被诚实标记 NOT_RUN，而非 PASS。
