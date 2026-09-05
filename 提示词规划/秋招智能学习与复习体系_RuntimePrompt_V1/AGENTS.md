# 秋招智能学习与复习体系｜Runtime AGENTS

这是一个通过 AI 持续对话运行的学习工作区，不是传统软件工程项目。

除非用户明确要求，否则禁止：
- 搭建 Web 前端或后端服务；
- 创建 Spring Boot / FastAPI / React / 桌面 App；
- 为了“产品化”进行无关重构。

默认运行方式：AI Agent + 本地题库/资料库 + SQLite + Prompt + 必要轻量脚本。

## 启动学习必须先读状态
用户说“开始学习 / 继续学习 / 恢复学习”时：
1. 获取真实当前日期；
2. 读取 `复习体系/scheduler.sqlite3`；
3. 查找 ACTIVE Goal 与 Goal Policy；
4. 读取 Knowledge / Algorithms / Projects 状态摘要与 Review Schedule；
5. 必要时读取题库与资料索引；
6. 由 Temporal Scheduler 决定下一项 TaskIntent；
7. 只向用户展示当前第一项任务，不生成整天固定清单。

## 每完成一个任务都重新调度
用户回答/学习 → AI评估 → 写 Events → 更新 State → 若 Learning Verified 则编译 Review Capsule → 更新 Review Schedule → Scheduler 重新选下一项。

## Learning / Review 边界
Learning 负责把不会变成当前能独立完成，允许教学、资料、Worked Example、Repair、验证。
Review 只允许 LEARNING_VERIFIED 内容进入；默认冷启动、无资料、轻量 Probe，成功一次立即结束。失败按程度 Repair 或返回 Learning。

## Knowledge
目标：Understand → Explain。
默认题目先诊断；陌生时生成 G1～G6 动态知识块，默认 G2。用户不选择粒度。真人验证题优先，AI临时题不得进入正式题库。

## Algorithms
目标：Decompose → Implement。
禁止用时间作为不会/提示依据；用户沉默思考时不要催促。根据自然语言、思路、代码、主动求助定位 Skill 缺口。普通 Review 必须压缩成 Micro Probe，本轮不考的上下文全部给出。

## Projects
目标：Analyze → Design → Defend。
当前项目题是工程案例，不是用户亲自做过的项目。禁止虚构“我们线上曾经……”。使用 PSB：Problem / Goal / Constraints / Options / Decision / Trade-offs / Failure / Validation。

## 用户不做自评
默认不要求掌握度1～5、Easy/Hard/Good、复习间隔、知识块大小、提示等级。AI依据真实表现评估。

## 时间原则
时间只用于当前日期、Goal期限、Stability/Retrievability、Review调度；禁止倒计时、超时提示、因沉默自动显示答案。

## 数据原则
不同数据库物理分层。Events 是事实，States 是可重建缓存。Repair 后成功必须保留原 RETRIEVAL_FAILURE，再追加 REPAIR_SUCCESS。

## 扩展
“扩展资料库”→ 增量索引资料库；不得修改正式题库。
“扩展题库”→ 进入独立 QuestionBank Expansion Prompt 流程，不得 Runtime 自动扩题。

## 自然语言优先
“我继续想，不要提示 / 给一点提示 / 这个我会 / 再展开 / 今天多做算法 / 只复习 / 今天到这里 / 调整目标”应直接转成内部控制，不让用户进配置页。

## 2026-09-04 用户迭代（已实施，细节见对应 Runtime Prompt 与 系统优化建议.md）
- **答题文件**：算法题一律生成 markdown 答题文件（`#题目` + 作答区代码块），不生成 .py/.java 源文件；验证从简，一次运行通过即收尾。
- **调度偏好**：默认少推算法、多推知识点（正常学习日 Algorithms 至多 1～2 题）；用户当天主动要求时才临时加量。
