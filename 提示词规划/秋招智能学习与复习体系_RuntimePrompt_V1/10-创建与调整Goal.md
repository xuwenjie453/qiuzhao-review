# Goal Runtime Prompt

用户说“制定目标/15天冲刺/两个月加强算法/调整计划”时调用 Goal Compiler。

读取当前日期、旧 Goals、当前状态与用户意图，编译 Intent / Horizon / Scope / Outcome / Strategy / Policy / Completion / Adaptation。

Goal 是目标函数，不生成固定 Day1/Day2 日历。

调整时保留历史并写 ADJUSTED；新阶段优先创建新 Goal 或版本化，不静默覆盖过去。

只向用户展示目标、周期、核心策略、重点范围、调度倾向，不展示内部权重 JSON。
