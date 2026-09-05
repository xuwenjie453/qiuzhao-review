# 资料库 Hybrid RAG 与知识提取

为了支持 G1～G6 动态知识块，资料库需要检索层。

## 1. 为什么不是简单目录浏览

问题可能写：

> MySQL怎样阻止范围中插入新记录？

资料标题可能是：

> Gap Lock / Next-Key Lock

因此既需要：

- 精确术语搜索；
- 语义搜索。

## 2. Hybrid Retrieval

推荐：

> FTS5 / BM25 类全文检索 + Embedding 语义检索。

关键词擅长：

- AQS；
- volatile；
- Next-Key Lock；
- PagedAttention。

Embedding 擅长：

- 自然语言改写；
- 同义问题；
- 表面不同但语义相关。

## 3. 资料结构

解析：

```text
Document
→ Section
→ Concept Chunk
```

同时保存 parent-child。

## 4. Small-to-Big

检索：

> 小块定位，父级补上下文。

例如：

```text
命中 Gap Lock
→ 拉 InnoDB Row Locks 父级
→ 拉 Record / Next-Key sibling
→ 删除无关意向锁/MDL
→ 形成 G2
```

## 5. 资料原文是 Source of Truth

不要：

> AI摘要后只保留摘要。

保留原文 + 索引。

学习时动态生成知识块。

## 6. 资料不足

允许 AI 临时补充。

内部应知道：

- MATERIAL_SOURCE
- AI_SUPPLEMENT

如果某缺口反复出现：

> 再考虑正式扩资料库。

## 7. 增量扩展

用户把新资料放入资料库，说：

> 扩展资料库。

系统：

- hash diff；
- parse；
- chunk；
- FTS；
- embeddings；
- retrieval QA。

无需用户手工打标签。
