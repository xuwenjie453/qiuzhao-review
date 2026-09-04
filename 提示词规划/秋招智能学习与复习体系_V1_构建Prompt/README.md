# 秋招智能学习与复习体系 V1｜构建 Prompt 包

本包用于基于现有 `试题库/` 与 `资料库/` 构建长期自适应学习与复习体系。

核心闭环：

```text
Goal → Temporal Scheduler → Learning / Review → Events → State → Reschedule
```

核心原则：
- 用户主要负责看、想、说、写；AI负责判断、检索、教学、评估、记录和调度。
- 时间只用于记忆和调度，不用于打断用户思考。
- 只有 `LEARNING_VERIFIED` 的内容才能进入 Review。
- Review 是轻量探针，不是重新上课；一次成功立即结束。
- 原题不直接等于复习任务。
- 题库、资料库、复习体系数据库物理分层。
- 正式题库禁止被学习系统随意自动扩展。

推荐执行顺序：
1. `00-总控构建Prompt.md`
2. `01-架构冻结与目录边界.md`
3. `02-SQLite-Schema与事件系统.md`
4. `03-资料库Hybrid-RAG构建Prompt.md`
5. `04-Goal-Compiler构建Prompt.md`
6. `05-Temporal-Scheduler构建Prompt.md`
7. `06-Knowledge-Engine构建Prompt.md`
8. `07-Algorithms-Engine构建Prompt.md`
9. `08-Projects-Engine构建Prompt.md`
10. `09-Review-Probe-Compiler构建Prompt.md`
11. `10-Review-Engine构建Prompt.md`
12. `11-Expansion-Hub构建Prompt.md`
13. `12-25天Coverage-Goal-Bootstrap.md`
14. `13-Session-UX-QA恢复.md`
15. `14-端到端集成验收Prompt.md`
16. `15-实现依据与外部规范.md`

建议正式目录：

```text
复习体系/
├── scheduler.sqlite3
├── Expansion/
│   ├── Goals/
│   ├── Materials/
│   └── QuestionBank/
├── Knowledge/
│   └── knowledge.sqlite3
├── Algorithms/
│   └── algorithms.sqlite3
├── Projects/
│   └── projects.sqlite3
└── Prompts/

资料库/
├── 原始资料...
├── materials.sqlite3
└── index/

试题库/
├── Knowledge/
├── Algorithms/
├── Projects/
└── questions.sqlite3
```
