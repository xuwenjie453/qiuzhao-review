# Projects 工程案例学习机制

Projects 的目标：

> Analyze → Design → Defend

当前题目来自真实项目面试问题，但不是用户亲自做过的项目。

因此学习的是：

> 工程问题求解方法

而不是虚构项目经历。

## 1. Project Solution Block

每个 PSB 包含：

- Problem
- Goal
- Constraints
- Candidate Solutions
- Decision Reasoning
- Trade-offs
- Failure Modes
- Validation
- Follow-up Map

## 2. 先自由回答，再教学

用户先说：

> 如果是这个场景，我会……

AI再诊断。

如果只是技术知识缺失：
调用 Knowledge Engine。

如果是工程决策链缺失：
生成 PSB / Repair。

## 3. 内部评价维度

AI内部评估：

- Problem Framing
- Constraint Awareness
- Technical Correctness
- Decision Reasoning
- Trade-off Awareness
- Failure Handling
- Validation

但用户不需要看复杂分数。

只反馈当前最值得修的 1～2 个问题。

## 4. 禁止虚构经历

推荐：

> “在这种场景下，一种合理方案是……”

禁止无事实依据：

> “我们线上曾经……”
> “我亲自把QPS从X提高到Y……”

## 5. 完成

用户能够在表面变化的工程案例中：

- 识别问题；
- 给出方案；
- 解释选择；
- 说明代价；
- 处理失败路径。

达到后进入 Review。
