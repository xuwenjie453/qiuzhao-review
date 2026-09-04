# Knowledge Learning Engine 构建 Prompt

目标：`Understand → Explain`

## 入口
先给真人 Knowledge 题，让用户自然回答，不先展示答案。
AI自动判断：已会 / 部分会 / 陌生。用户不自评。

## 六级知识块
- G1 Point：单点修补。
- G2 Core：默认，最小充分知识结构。
- G3 Cluster：局部知识簇。
- G4 Subsystem：完整机制。
- G5 Module：领域模块。
- G6 Domain Map：领域地图与学习拆分，不是超长文章。

G2 默认包含：
- 核心概念
- 必要前置
- 1~3个相邻辨析
- 原因/机制
- 一层典型追问

按知识图半径控制粒度，不按固定 token 数。

## 生成流程

```text
真人题
→ Knowledge Need Graph
→ 查询用户状态
→ Hybrid RAG
→ 小块定位 / 父级补上下文
→ 必要 AI 补洞
→ 生成最小充分知识块
```

## 动态粒度
已掌握大量前置就收缩；连续暴露多个基础缺口就扩大。不要要求用户选择 G1~G6。

用户可自然说：
- 这部分我会
- 再展开一点

作为轻量 override。

## 验证
撤掉知识块后：
1. 重答原题；
2. 动态选择 2~4 道不同认知维度的验证题。

优先真人题；题库不足时可 AI 临时生成，但绝不写入正式题库。

验证维度：
- 核心提取
- 因果机制
- 概念边界
- 简单迁移

## Repair Loop
失败先定位具体节点。
- 局部问题 → Repair Block；
- 大范围缺口 → 升级 G。

Repair 尽量换表示：对比、例子、表格、ASCII、反例、场景。

## 完成
Must Know 通过，并至少一次非原题迁移成功 → `LEARNING_VERIFIED`。

随后仅短巩固 1~3 道动态停止，然后切换主题。不要在同知识簇刷到过度熟练。

## 输出
- learning_events
- learned nodes
- repaired nodes
- fragile nodes
- already stable prerequisites
- evidence
- LEARNING_VERIFIED flag
- Review Probe Compiler candidates
