# Runtime Agent Adapter 合同

Agent 是语义定位器，不是 Graph DB writer。

`question.open` 时机：
- TaskIntent 真正开始围绕一道正式题；
- Review probe 真正开始作答。

`node.add` 时机：
- 用户明确：“把这段/刚才第二个解释加入图”；
- 用户明确临时/长期语义，默认策略按 Runtime Prompt 设计，不能 AI 猜重要性。

body：
- 当前 assistant explanation 的 exact Markdown span；
- 不把用户文字混入；
- 不总结、不润色。

title：
- Agent 生成简短概括；
- title 失败不应改写 body。

`question.close`：
- 切题；
- task complete；
- review probe complete；
- 用户结束该题。

Daemon offline：
- 学习继续；
- add 不能伪报成功。
