# Markdown block renderer

## 任务目标
实现不依赖 WebView 的可预测 Markdown 阅读渲染。

## 必读设计稿
- `90_设计稿基线/04_iPad端/03_Markdown阅读器.md`

## 必须满足
- 支持 headings/paragraph/bold/italic/lists/inline code/fenced code/blockquote/links/hr/simple tables。
- 正文不可编辑。
- 不执行 raw HTML/script。

## 实施步骤
1. 先盘点当前 Agent 输出真实 Markdown 子集。
2. 实现 block parser/renderer 或复用 reading-system 合适 renderer。
3. 对 code block/table 做长内容安全布局。

## 测试要求
- golden markdown fixtures
- long code
- table
- unicode/CJK

## 禁止捷径
- 禁止用 WebView 作为默认捷径，除非有明确证据能满足稳定坐标且经过设计冲突审查。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
