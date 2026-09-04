# 25-Day Coverage Goal Bootstrap Prompt

这是系统第一个正式 Goal。

用户意图：

> 用大约25天快速建立尽可能广泛的秋招技术能力覆盖，先大量掌握陌生知识，再逐渐提高复习、迁移和整合。Knowledge、Algorithms、Projects 都必须实际学习。

## Goal Type
- COVERAGE
- ACQUISITION

Strategy：`COVERAGE_FIRST`

## Scope
至少：
- Knowledge/*：高优先；
- Algorithms/*：高优先；
- Projects/*：中高优先。

不要因为 Projects 数量少就完全拖到最后。

## Completion
不要求：
- 2385题全部做完；
- 所有节点长期稳定；
- 每天固定题量。

目标：
> 最大化核心秋招能力的有效覆盖，同时保护重要已学内容不发生大规模遗忘。

## 时间策略
Goal Progress 早期：Coverage / New Learning 高。
中后期：Retention / Weakness / Importance / Transfer 逐渐提高。
使用连续权重漂移，不硬切三个阶段。

## New Learning 优先
优先：
- ★★★★★ / ★★★★☆；
- 基础依赖节点；
- Java / JVM / JUC / Spring / MySQL / Redis；
- OS / Networks / DataStructures / 408基础；
- AI / RAG / Agent；
- 核心算法模式；
- 核心工程问题。

同时保持领域多样性，不长期卡在一个子类。

## Review
只复习 Learning Verified Capsule。
使用轻量 Probe。
Coverage First 下，不允许 Review Debt 吞掉全天。

## Bootstrap 初始状态
历史为空时：
- 不为所有题预创建 mastery=0；
- 没有证据就是未知；
- 状态节点随真实学习自然生长。

## 输出
写入 scheduler.sqlite3：
- goal
- scopes
- policies
- CREATED event
- ACTIVATED event

并让 Scheduler 立即产生第一个 TaskIntent。
