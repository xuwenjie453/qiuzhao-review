# Learning System E2E Prompt

扩展 `学习系统/test_e2e.py` 或对应集成测试，验证业务来源链。

## Case 1 — 明确来源

- 正式 question Q 进入学习；
- LEARNING_VERIFIED；
- compile capsule；
- capsule.primary_source_question_id == Q；
- source_questions 仍保留证据列表；
- scheduler 激活 capsule 不受影响。

## Case 2 — 多来源证据

source_questions=[Q2,Q1,...]，显式 primary=Q1。断言数据库 primary=Q1，证明系统没有使用数组第一项推断。

## Case 3 — Legacy/unknown source

primary=NULL 的 capsule 仍能 materialize Review；双端 open 不建立 inheritance，但 Review 不失败。

## Case 4 — Parent graph missing

primary=Q，但 dual-end 尚无 qb:Q graph：Review graph 正常打开，无 inherited nodes，记录诊断状态，不伪造 Explanation。

原有 21+ E2E 场景必须继续通过；不得为了新字段重写旧行为。
