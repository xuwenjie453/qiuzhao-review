# 05 Notebook 目录 CLI 与打印 Prompt

本步骤只实现 Notebook 目录管理与“打印所有笔记本和对应自制图”。

## 一、用户语义

用户说：

```text
列出所有笔记本
打印所有笔记本
列出我的笔记
列出所有自制图
查看笔记目录
```

统一解释为：

```text
Notebook System 中的全部 Notebook
+
Notebook System 中的全部 NotebookGraph
```

绝不查询 Review QuestionGraph。

---

## 二、最小 CLI

建议独立入口，或在现有 CLI 下建立清晰 namespace。

推荐命令：

```text
notebook create --title <title>
notebook rename --id <notebook_id> --title <title>
notebook delete --id <notebook_id>
notebook list
notebook show --id <notebook_id>
notebook tree

note-graph create --json <file> [--notebook <notebook_id>]
note-graph open --id <graph_id>
note-graph rename --id <graph_id> --title <title>
note-graph delete --id <graph_id>
note-graph move --id <graph_id> --notebook <notebook_id>
note-graph unfile --id <graph_id>
```

CLI 必须调用 Notebook service/API，不要让 CLI 到处散落 SQL。

---

## 三、tree 输出

`notebook tree` 是本轮关键交付。

人类可读输出示例：

```text
我的笔记

📒 Redis
├── Redis为什么使用跳表
├── AOF与RDB
└── 缓存一致性

📒 阅读方法
├── 为什么完整阅读会形成任务感
└── 如何建立局部认知阵地

📂 未归档
├── 名称为什么塑造理解
└── 一个尚未分类的问题
```

要求：

- Notebook 顺序稳定；
- Notebook 内 Graph 顺序使用 membership.position；
- 未归档永远最后显示；
- 空 Notebook 可以显示，也可以明确标注“（空）”；
- title 中特殊字符不得破坏输出；
- 不显示 Review Graph。

---

## 四、JSON 输出

CLI/API 同时提供结构化结果，便于 Agent 使用：

```json
{
  "notebooks": [
    {
      "notebook_id": "nb-...",
      "title": "Redis",
      "graphs": [
        {
          "graph_id": "ng-...",
          "title": "AOF与RDB"
        }
      ]
    }
  ],
  "unfiled": [
    {
      "graph_id": "ng-...",
      "title": "名称为什么塑造理解"
    }
  ]
}
```

不要在此 JSON 中加入 Review `question_source/question_id/capsule_id/custom_id`，因为 NotebookGraph 不具有这些身份。

---

## 五、目录操作语义

### move

```text
Graph 未归档 -> Notebook A
Graph A -> Notebook B
```

都只改 membership。

不得改变：

```text
graph_id
node_id
node/layout revision（除非你专门给 membership 自己 revision）
Graph 内容
```

### unfile

只删除 membership，Graph 保留。

### delete notebook

```text
删除 Notebook
-> membership 删除
-> Graph 保留
-> Graph 出现在未归档
```

### delete graph

才真正删除 NotebookGraph 及其 NoteNode/Layout/Ink。

---

## 六、打印范围硬约束

`notebook tree` 不得通过以下任何方式偷懒：

- 调用现有 `custom list`；
- 查询 Review `graphs WHERE question_source='USER_AUTHORED'`；
- ATTACH dual-end review DB 后混合输出；
- 把 Review USER_AUTHORED 当 NotebookGraph。

Notebook tree 必须只从 notebook canonical store 构造。

---

## 七、Local API（如需要）

如果项目采用 localhost control service，可以提供：

```text
GET  /notebooks
GET  /notebooks/tree
GET  /notebooks/:id
GET  /note-graphs/:id

POST /notebook-command
```

命令：

```text
notebook.create
notebook.rename
notebook.delete
note-graph.create
note-graph.rename
note-graph.delete
note-graph.move
note-graph.unfile
```

保持 Notebook endpoint 与 Review `/command` 语义分离，避免未来混用 command kind。

---

## 八、Agent/Runtime 文档

如果需要让 Agent 自然语言调用 Notebook，新增独立 Notebook 协议文档，不要把它写进 Review 调度规则内部。

自然语言映射示例：

```text
“建一个叫 Redis 的笔记本” -> notebook.create
“把这张自制图放进 Redis” -> note-graph.move
“列出我的笔记” -> notebook.tree
```

只有用户明确指向 Notebook 系统时才调用。

---

## 九、测试

至少覆盖：

1. tree 列出所有 Notebook；
2. 每个 Notebook 子图完整；
3. 未归档完整；
4. 空 Notebook 行为确定；
5. move 后只改变目录；
6. delete notebook 后 Graph 进入未归档；
7. delete graph 后从 tree 消失；
8. tree 在 Review DB 有大量 USER_AUTHORED 图时仍不显示它们；
9. JSON 与文本 tree 表达同一集合；
10. 排序稳定、可重复。
