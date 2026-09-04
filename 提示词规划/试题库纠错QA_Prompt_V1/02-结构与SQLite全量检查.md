# 结构与 SQLite 全量检查

必须 100% 执行。

## SQLite

运行：

```sql
PRAGMA integrity_check;
```

要求结果：

`ok`

## Markdown ↔ SQLite

全库提取：
- question_id
- importance
- markdown_path
- question_text
- answer

检查：
- 1:1
- 无孤儿
- 无重复ID
- 路径存在
- 星级与importance一致
- answer一致

## ID路径

例如：

`Java-003-017`

必须位于：

`Knowledge/Java/Java-003.md`

## 空字段

禁止：
- 空题干
- 空答案
- 空ID
- importance不在1–5
