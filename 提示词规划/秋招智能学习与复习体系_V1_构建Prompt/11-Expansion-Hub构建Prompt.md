# Expansion Hub 构建 Prompt

Expansion Hub 负责改变系统未来能做什么，不负责今天学什么。

## Goal Expansion
用户自然语言添加目标 → 调用 Goal Compiler → 写 `复习体系/scheduler.sqlite3`。

## Materials Expansion
用户：
1. 把新资料放入 `资料库/`；
2. 对 AI 说“扩展资料库”。

系统自动：

```text
scan
→ hash diff
→ parse
→ chunk
→ FTS
→ embeddings
→ parent relations
→ retrieval QA
```

更新：
- `资料库/materials.sqlite3`
- `资料库/index/`

不改正式试题库。

## QuestionBank Expansion
正式题库是最高价值内容资产。

禁止通用“自动扩题按钮”。

每次扩展：
1. 用户明确决定；
2. 重新设计一套新版 Expansion Prompt；
3. 独立执行；
4. 独立 QA；
5. 才写正式题库。

学习/复习过程中 AI 临时生成题永不写入 questions.sqlite3。

## 不要做
- 自动抓网页就塞题库；
- 因资料缺一点就永久改写原资料；
- 因 AI 临时题好用就转正式题；
- 把 Expansion 日志塞进题库目录。
