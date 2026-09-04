# Session / UX / QA / Recovery Prompt

## Session 状态机

启动：

```text
open system
→ current date
→ active goal
→ read state summaries
→ scheduler
→ TaskIntent
```

### LEARN

```text
TaskIntent
→ Engine
→ 用户自然回答/思考
→ AI诊断
→ 按需教学
→ 验证
→ LEARNING_VERIFIED
→ Event
→ Review Probe Compiler
→ Capsule
→ Scheduler
```

### REVIEW

```text
TaskIntent
→ Capsule
→ Micro Probe
→ cold retrieval
→ SUCCESS → Event → End → Scheduler
→ PARTIAL/FAILURE → Repair/Learning → Event → Scheduler
```

## UX原则
用户绝大多数时候只做：
- 看
- 想
- 说
- 写

系统默认不问：
- 今天学哪类？
- 难度几分？
- Easy/Hard？
- 掌握度1~5？
- 几天后复习？
- G2还是G3？

## 自然语言覆盖
支持：
- 我继续想，不要提示
- 给一点提示
- 这部分我会
- 再展开一点
- 今天先学MySQL
- 今天不做项目
- 明天有面试
- 调整目标

## 心流保护
禁止：
- 思考倒计时；
- 自动催促；
- 长时间无输入后弹“需要帮助吗”；
- 高频评分面板；
- 大量元管理操作。

## QA
每个数据库：

```sql
PRAGMA integrity_check;
PRAGMA foreign_key_check;
```

必须通过。

## Versioning
至少保存：
- schema_version
- prompt_version
- scheduler_version
- review_compiler_version
- material_index_version

## Recovery
- 重大修改前备份相关数据库；
- Current State 可以由 Events replay；
- Session 中断不能伪造完成事件；
- Prompt/Scheduler 升级后历史仍可重新计算。

## 半年恢复 QA
模拟：
1. Learning Verified；
2. 多次 Review Success；
3. 时间推进180天；
4. 创建 Reactivation Goal；
5. Scheduler 重新估值；
6. 不能仍显示“永久掌握”；
7. 也不能当作从未学习。

## Review Debt QA
模拟3~7天未使用：
- 不要求先清空所有复习；
- Coverage Goal 仍继续新学习；
- 高重要 Review 优先恢复。

## Algorithm Review QA
- 普通 Capsule 不生成完整 LeetCode 题；
- required_context 完整；
- 只测试目标技能；
- 成功一次结束。

## AI 临时题 QA
不得写入：
- questions.sqlite3
- 正式题库 Markdown
