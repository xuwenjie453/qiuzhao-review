# One-Shot Bootstrap Prompt

如果需要把整个任务一次性交给 coding agent，把本文件作为入口，并要求它首先读取 `00_总控/00_MASTER_INCREMENTAL_UPDATE_PROMPT.md`。

## 指令

你要完成 QuestionGraph 继承的增量实现，但必须内部按 Phase A-H 串行推进，不得一次性大改。

执行：

```text
Read authority
→ Baseline evidence
→ Phase A contract
→ Phase B Mac canonical
→ Phase C wire
→ Phase D iPad store
→ Phase E iPad UI
→ Phase F Review integration
→ Phase G tests
→ Phase H release gate
→ Independent review
```

每个 Phase 通过 Gate 后才继续。遇到测试失败自行定位并修复；遇到设计冲突才停止。不要为了减少工作量跳过 migration、iPad cache normalization、revision fan-out 或 Learning E2E。

最后提交一个完整 PR，PR body 必须列出 migration/wire version、关键语义、测试证据、NOT_RUN/BLOCKED 项与已知风险。
