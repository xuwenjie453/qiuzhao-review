# Reader 单一内容坐标系

## 任务目标
让 Markdown 与 Ink 永久共享同一内容坐标。

## 必读设计稿
- `90_设计稿基线/04_iPad端/03_Markdown阅读器.md`
- `90_设计稿基线/07_ADR/ADR-008_Reader固定CanonicalPageWidth.md`

## 必须满足
- 唯一 scroll owner。
- MarkdownRenderedView 与 InkSurface 同 bounds。
- canonical page width。
- 横屏加 gutter，避免正文无限重排。

## 实施步骤
1. 实现 UIKit container/SwiftUI bridge。
2. 明确 content height calculation。
3. layout_signature 只由 body/width/token 决定。

## 测试要求
- scroll alignment test
- rotation/canonical width
- 50 reopen no shift visual/manual

## 禁止捷径
- 禁止两个独立 UIScrollView contentOffset 互相同步。

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
