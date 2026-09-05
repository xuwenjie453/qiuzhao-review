# Expansion Hub 与 Goal 机制

系统的扩展不只是“加题”。

Expansion Hub 包括三条路线。

## 1. Goal Expansion

用户自然语言表达新目标。

例如：

> 接下来15天冲刺已有知识。

Goal Compiler 自动形成：

- Intent；
- Horizon；
- Scope；
- Outcome；
- Strategy；
- Scheduler Policy；
- Completion Rule；
- Adaptation。

新 Goal 不删除历史 Goal。

## 2. Materials Expansion

用户：

> 放资料 + 说一声扩展。

系统增量构建 RAG 索引。

## 3. Question Bank Expansion

题库最重要。

不能自动随意扩。

每一次正式扩题：

> 单独重新设计新版 Prompt + QA。

学习过程中 AI 临时生成的：

- 验证题；
- Repair题；
- Micro Probe；
- Transfer Case；

永远不进入正式 `questions.sqlite3`。

## 4. Goal 可叠加

例如：

```text
2027秋招
├── 25-Day Coverage
├── Algorithm Foundation
└── 15-Day Final Sprint
```

Scheduler 负责解决竞争。

## 5. Goal 是目标函数，不是死日历

Goal 不应该存：

> Day 1做Java100题。

而应该告诉 Scheduler：

> 当前优化什么。

每日任务根据最新状态重新计算。
