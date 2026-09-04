# SQLite 极简规范

## 文件

根目录：

`questions.sqlite3`

## Schema

```sql
CREATE TABLE IF NOT EXISTS questions (
    question_id   TEXT PRIMARY KEY,
    importance    INTEGER NOT NULL CHECK (importance BETWEEN 1 AND 5),
    markdown_path TEXT NOT NULL,
    question_text TEXT NOT NULL,
    answer        TEXT
);
```

## 规则

只有正式纳入 Markdown 的题进入数据库。

不建立：
- source
- company
- year
- duplicate
- rejected
- crawl
- review
- tag

## 一致性

必须检查：

1. Markdown 每个 question_id 在 SQLite 恰好一行
2. SQLite 每个 question_id 在 Markdown 恰好出现一次
3. markdown_path 指向真实文件
4. importance 为 1–5
5. question_text 为完整题干
6. answer 对应 Markdown 答案
