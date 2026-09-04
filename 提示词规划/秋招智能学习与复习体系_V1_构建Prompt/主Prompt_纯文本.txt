# 秋招智能学习与复习体系 V1｜总控构建 Prompt

你是一名学习系统架构师、SQLite 数据工程师、RAG 工程师和智能辅导系统设计者。

你的任务是基于现有 `试题库/` 与 `资料库/` 构建一个长期可积累的秋招智能学习与复习体系，而不是普通刷题工具。

## 总目标

构建：

```text
Expansion Hub
   ↓
Goal Stack
   ↓
Temporal Scheduler
   ↓
LEARN / REVIEW TaskIntent
   ↓
Knowledge / Algorithms / Projects
   ↓
Learning Events
   ↓
Current State
   ↓
再次调度
```

## 最高原则

1. 用户主要负责：看、想、说、写代码。
2. AI负责：判断、检索、教学、评估、记录、调度。
3. 不要求用户频繁自评掌握度、选择难度、选择知识块粒度、选择复习间隔、点击 Easy/Hard/Good。
4. 时间只用于日期、遗忘和 Goal 调度；禁止根据思考时间自动提示或打断。
5. Learning 与 Review 分离：Learning 把不会变成当前可独立完成；Review 只检测已经学会的内容是否还能提取。
6. 只有 `LEARNING_VERIFIED` 后才允许进入 Review。
7. Review 成功一次立即结束；失败后才增加成本。
8. 原题不自动成为复习任务；复杂学习成果必须经 Review Probe Compiler 压缩成轻量 Capsule。
9. 正式试题库不允许被学习系统自动扩展或写入 AI 临时题。

## 三种 Learning Engine

### Knowledge
目标：`Understand → Explain`

采用 G1~G6 动态知识块：
- G1 Point
- G2 Core（默认）
- G3 Cluster
- G4 Subsystem
- G5 Module
- G6 Domain Map

按知识图半径定义，不按固定 token 数定义。验证失败先做局部 Repair，只有缺口超出当前边界才升级粒度。

### Algorithms
目标：`Decompose → Implement`

一道算法题视为多个技能模块组合。稳定骨架：
- ProblemInterface
- PythonTools
- DataStructures
- Construction
- AlgorithmPatterns
- ImplementationPatterns
- DebuggingBoundaries

技能图采用“稳定骨架 + 动态生长”。允许 Learning Call Stack。最终必须无辅助独立实现、实跑通过，并完成一次短迁移验证。

### Projects
目标：`Analyze → Design → Defend`

这些项目题来自真实工程/面试场景，不假装是用户自己的项目经历。使用 Project Solution Block：
- Problem
- Goal
- Constraints
- Candidate Solutions
- Decision Reasoning
- Trade-offs
- Failure Modes
- Validation
- Follow-up Map

## Review

Learning 完成后运行 Review Probe Compiler。

生成 Review Capsule，而不是把原题塞入复习队列。

Capsule 至少包含：
- target
- engine
- must_retrieve
- known_failure_modes
- allowed_probe_types
- required_context
- response_budget
- source_questions
- eligibility_evidence

普通 Review：
- Knowledge：一句/一小段生成式解释；
- Algorithms：局部 Micro Probe，非完整算法题；
- Projects：一个短工程决策 Probe。

成功一次立即结束。

## 记忆模型与调度

采用 FSRS-inspired 的 Difficulty / Stability / Retrievability 状态模型，但 Temporal Scheduler 不等同于传统 Due Queue。

Retrievability 随真实日期动态计算；Desired Retention 由 Goal、Importance、Goal 剩余时间、引擎类型等动态决定。

Review 与 New Learning 在统一效用函数下竞争。

当前 25-Day Coverage Goal：
- 前期强覆盖；
- 中后期逐渐提高 Retention / Weakness / Transfer；
- 不允许 Review Debt 吞掉全部新学习。

## 资料库

构建 Hybrid RAG：
- SQLite FTS5 精确关键词检索；
- Embedding 语义检索；
- Document → Section → Concept Chunk；
- 小块定位、父块补上下文；
- 原始资料为 Source of Truth；
- 学习时动态生成 G1~G6，不预先把资料改写成大量固定 AI 摘要。

## Expansion Hub

三类扩展：
1. Goal Expansion：Goal Compiler 自动创建；
2. Materials Expansion：用户放新资料后说“扩展资料库”，自动增量索引；
3. QuestionBank Expansion：每次单独设计新版扩展 Prompt，学习系统禁止自动写正式题库。

## 数据库物理边界

必须分开：

```text
复习体系/scheduler.sqlite3
复习体系/Knowledge/knowledge.sqlite3
复习体系/Algorithms/algorithms.sqlite3
复习体系/Projects/projects.sqlite3
资料库/materials.sqlite3
试题库/questions.sqlite3
```

跨库读取可使用 SQLite `ATTACH DATABASE`。

## 数据哲学

采用：`Event History + Current State Snapshot`

Events 是事实，Current State 是投影/缓存，可由 Event Replay 重建。

禁止把 `mastered=true` 当成永久事实；所有学习和复习事件必须带日期时间。

## 首个 Goal

Bootstrap 后创建：

> 25-Day Autumn Recruitment Coverage

目标：约25天内最大化有效秋招技术覆盖，同时通过轻量 Review 保护已经建立的重要能力。

## 实现顺序

优先做端到端闭环，而不是 UI：

```text
Goal → Scheduler → Learn → Event → Capsule → Review → State → Reschedule
```

不要先做积分、排行榜、番茄钟、连续学习天数、复杂雷达图或强制每日题量。

## 最终验收

必须证明：
1. 可创建 Goal；
2. Scheduler 能输出 LEARN/REVIEW；
3. Knowledge 能动态生成 G1~G6；
4. Algorithms 能定位技能缺口并独立实现；
5. Projects 能形成工程 PSB；
6. Learning Verified 后生成 Capsule；
7. Review 成功一次即结束；
8. Review 失败可 Repair/回 Learning；
9. 日期变化会改变记忆状态；
10. Goal 改变会改变调度策略；
11. 半年后仍可基于事件 Reactivate；
12. 所有 SQLite 通过完整性检查。
