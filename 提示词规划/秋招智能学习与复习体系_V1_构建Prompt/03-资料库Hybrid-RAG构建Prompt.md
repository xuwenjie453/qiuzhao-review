# 资料库 Hybrid RAG 构建 Prompt

目标：支持 Knowledge Engine 根据真人题和用户当前缺口，提取“最小充分知识结构”，并按 G1~G6 动态扩大。

## 原则
- 原始资料是 Source of Truth。
- 不只保存 AI 摘要。
- 不破坏原文件。
- G1~G6 在学习时动态生成，不预生成成固定材料。

## 结构解析

```text
Document → Section → Concept Chunk
```

保留：
- heading_path
- parent_chunk_id
- source_path
- start/end offset

## Retrieval Chunk 粒度
- Atomic：单概念、小块。
- Local：局部 Section。
- Module：较大父块。

注意：这是检索粒度，不是 G1~G6 教学粒度。

## Hybrid Retrieval
并行：
1. SQLite FTS5 keyword retrieval；
2. Embedding semantic retrieval。

融合后 rerank。

技术精确名词优先保证关键词检索能力；自然语言改写依赖语义检索。

## Small-to-Big
用 Atomic 命中定位，再按当前问题：
- 拉取必要 parent；
- 拉取 sibling；
- 裁掉无关内容。

## Knowledge Need Graph
输入真人题后解析：
- domain
- target concept
- answer dimensions
- prerequisites
- contrast concepts
- likely followups

结合用户历史状态，扣除已稳定前置。

## 资料不足
允许 AI 临时补洞，但内部标记：
- MATERIAL_SOURCE
- AI_SUPPLEMENT

不能假装 AI 补充来自原资料。

## 增量索引
使用 `path + content_hash` 判断：
- unchanged
- modified
- new
- deleted

只重建必要文档。仅当 embedding 模型或 chunk 算法整体变化时 full rebuild。

## 资料扩展 UX
用户只需：
1. 把新文件放入资料库；
2. 说“扩展资料库”。

系统自动：scan → hash diff → parse → chunk → FTS → embeddings → parent relations → retrieval QA。

输出：materials.sqlite3、index/、ingestion/retrieval 接口与 QA。
