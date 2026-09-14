# Review Open Inheritance Flow Prompt

定位 Review Probe 物化到双端 `question.open` 的真实调用链，并在最小层增加 inheritance declaration。

## 正常路径

```text
capsule.primary_source_question_id = Q
→ parent QuestionRef = QUESTION_BANK / qb:Q
→ open/create Review graph A
→ resolve existing QuestionBank graph B
→ ensure A --SHARED_EXPLANATIONS--> B
→ return A effective snapshot
```

建议 `question.open` 支持 declarative `inherit_from`，内部调用同一个 `ensureInheritance`，避免 Agent 分两条命令造成 race。

## Parent missing

若 `qb:Q` 尚无 QuestionGraph：
- 不伪造历史 Explanation；
- Review graph 正常打开；
- 记录可诊断的 `parent_graph_missing`；
- 不因 inheritance 缺失把 Review 判失败。

如果未来选择安全创建空 parent，也必须能取得真实题干 source snapshot，且 Explanation 仍为空；V1 默认不要自动做。

## Legacy capsule

primary source NULL：不建立 inheritance，Review 继续。禁止从 `source_questions[0]` fallback。
