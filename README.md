# 秋招智能学习与复习体系

一个 **Agent 原生**（AI 持续对话驱动）的秋招技术备考工作区：以真人真题题库为命题源、本地教材资料为教学源，由"目标编译器 + 时序调度器 + 三引擎 + 记忆模型 + 复习探针"构成闭环——不是刷题软件，是"帮你把不会变成会、并保证学过的不忘"的学习系统。

> 使用者：秋招备考中的个人用户。用法：与任意具备文件/SQLite/搜索能力的 AI Agent 对话，说「开始学习」即可。
> 仓库地址：https://github.com/xuwenjie453/qiuzhao-review

---

## 一、目录总览

```text
秋招智能学习与复习体系/            ← 仓库根（即学习工作区根）
├── AGENTS.md                  # 新 AI 接管本系统的引导入口（必读）
├── README.md                  # 本文件
├── scheduler.sqlite3          # 控制层：Goal/Policy/会话/复习时序
├── Knowledge/                 # Knowledge 引擎库（控制层数据）
├── Algorithms/                # Algorithms 引擎库
├── Projects/                  # Projects 引擎库
├── 试题库/                    # 真人技术题库（只读资产，2383 题）
│   ├── Knowledge/  Algorithms/  Projects/   # 三大类 49 个英文子类
│   └── questions.sqlite3      # 题库 1:1 索引
├── 资料库/                    # 教学资料源（本地资产，不入 git）
│   ├── Agent面试资料/ Java面试资料/ 2027-CSKAOYAN-eBooks-main/   # 160+ 篇 md 教程
│   ├── 408计算机专业基础综合/ 计算408真题/ …                      # 教材与真题 PDF
│   ├── materials.sqlite3      # Hybrid RAG 索引（本地生成，可 expand-materials 重建）
│   └── index/
├── 学习系统/                  # V1 系统实现代码（CLI + Python 包）
│   ├── cli.py  test_e2e.py  README.md
│   └── lsys/                  # schema / db / goal_compiler / scheduler /
│                              # engines / probe_compiler / review_engine / rebuilder / materials_rag
└── 提示词规划/                # 全部 Prompt 包（构建期 + 运行期）
    ├── 试题库最终扩展Prompt_V4/          # 题库扩展规范（构建题库用）
    ├── 试题库纠错QA_Prompt_V1/           # 题库纠错 QA 规范
    ├── 秋招智能学习与复习体系_V1_构建Prompt/  # 系统构建规范
    └── 秋招智能学习与复习体系_RuntimePrompt_V1/  # ★ 运行期 Prompt 包（日常学习用）
```

## 二、三大内容资产

### 1. 试题库 —— 真人命题空间（2383 题）
- 全部来自**真实人类题源**：2020 至今真人面经/笔经 + **2009–2025 共 17 年 408 统考单选真题**（633 题）；AI 禁止自编正式题
- 三大类：`Knowledge`（Java/JUC/JVM/Spring/MySQL/Redis/OS/网络/AI/RAG/Agent…）、`Algorithms`（手撕代码，附 Python3 解答）、`Projects`（工程案例追问）
- 每条含永久题号 `<子类-文件-序号>`、重要度星级、题干、答案、极简解析；Markdown 与 `questions.sqlite3` 严格 1:1
- 已过两轮 QA 纠错（错误率 <2%，408/算法全量核验），题号永久冻结

### 2. 资料库 —— 教学源 + Hybrid RAG（160+ md 教程，**本地资产，不入 git**）
- 全部资料（Agent/Java 面试 md、27 王道 408 四科 Markdown、PDF 教材与真题）仅存在于你的本地 `资料库/`，GitHub 仓库不含任何资料内容
- `materials.sqlite3`：Document → Section → Concept 三级切块 + **FTS5（trigram 中文全文）** + **语义向量**双路检索、词项稀缺度加权融合、Small-to-Big 父块补上下文（克隆仓库后放入资料并运行 `expand-materials` 即可重建）
- 学习时按需检索最小充分知识（G1~G6 动态粒度），**不预生成固定 AI 摘要**；内容政策：跳过模拟题/README

### 3. 提示词规划 —— 构建期与运行期 Prompt 包
- 构建期：题库扩展 V4 / 题库纠错 QA V1 / 学习体系构建 V1（均已执行完毕，留档可复现）
- **运行期：`秋招智能学习与复习体系_RuntimePrompt_V1/`** —— 日常每个学习会话的执行契约（调度、三引擎教学、复习、事件记录、会话恢复等 20+ 份）

## 三、系统如何运转

```text
Expansion Hub (Goal/资料扩展)
   ↓
Goal Stack ──→ Temporal Scheduler ──→ 下一项 TaskIntent
(Goal Compiler)   (FSRS 式记忆模型)        LEARN / REVIEW / REPAIR
                                              ↓
                        Knowledge(Understand→Explain) / Algorithms(Decompose→Implement)
                        / Projects(Analyze→Design→Defend)
                                              ↓
                                        Learning Events(事实, 带时间戳)
                                              ↓
                    LEARNING_VERIFIED ──→ Review Probe Compiler ──→ Capsule(轻量压缩)
                                              ↓
                                  Temporal Scheduler (统一效用竞争, 再调度)
```

关键机制（不追求 UI 复刻，全在对话中发生）：

| 机制 | 规则 |
|---|---|
| 人机分工 | 用户：看/想/说/写代码；AI：判断、检索、教学、评估、记录、调度。**用户不做自评**（无 Easy/Hard/掌握度） |
| Learning vs Review | 只有 `LEARNING_VERIFIED` 能进 Review；Review 是轻量探针，**成功一次立即结束**；原题不直接进复习队列，先经 Probe Compiler 压缩成 Capsule |
| 记忆模型 | FSRS-inspired：Difficulty / Stability / Retrievability（R 运行时计算不存储，`R=(1+0.2346·t/S)^−0.5`）；Desired Retention 由 Goal+进度动态漂移，不是全局常数 |
| 调度 | 不是 Due Queue：`next_due_at` 只决定"进入竞争"；LEARN/REVIEW/REPAIR 按统一效用竞争；Coverage Goal 下新学习有保底，**Review Debt 不许吞掉新学习**；25 天策略连续漂移（前期强覆盖 → 后期重保持/弱点/迁移） |
| 时间哲学 | 日期用于调度与遗忘；禁止倒计时/沉默超时提示/思考时长判定 |
| 事件事实性 | Events 是事实、States 是可重放投影；Repair 后答对**必须保留原失败事件再追加 REPAIR_SUCCESS**；不伪造成功 |
| 数据库边界 | scheduler / Knowledge / Algorithms / Projects / materials 五库物理分离，跨库用 ATTACH；**questions.sqlite3 只读**，Runtime 禁止自动扩题 |

## 四、开始使用（日常对话）

在仓库内开一个 AI Agent 会话，直接说：

```text
开始学习            # 取 Active Goal → 调度 → 展示当前一项任务（真人题）
继续 / 我还在想     # 接着当前任务，不要催促
这个我会 / 完全不会 / 再展开一点 / 给一点提示
今天多做一点算法 / 今天不做项目 / 只复习
今天先到这里        # 干净收尾，只落真实事件
恢复上次学习
制定目标 / 未来15天冲刺            # Goal Compiler
扩展资料库                        # 增量索引新放入的教程
```

新 AI 首次接管请先读根 `AGENTS.md`。

## 五、CLI 速查（学习系统/代码层）

```bash
python3 学习系统/cli.py status           # 当前 Goal、三引擎状态、复习预算
python3 学习系统/cli.py task             # 打印下一项 TaskIntent(LEARN/REVIEW/REPAIR)
python3 学习系统/cli.py integrity        # 五库 integrity + foreign_key 检查
python3 学习系统/cli.py replay           # 事件重放，重建 Current State
python3 学习系统/cli.py expand-materials # 资料库增量索引(新资料放入资料库后执行)
python3 学习系统/cli.py retrieve "间隙锁 next-key"   # Hybrid RAG 检索教学块
python3 学习系统/cli.py add-goal "15天冲刺复习已有知识"
python3 学习系统/test_e2e.py             # 21 项端到端验收(临时环境, 不污染正式库)
```

> 说明：正常学习会话由 AI 读取状态并调度，CLI 是兜底/审计工具，用户无需手动执行。

## 六、当前进度（截至最近一次落库）

- Active Goal：**25-Day Autumn Recruitment Coverage**（COVERAGE_FIRST，2026-09-04 ~ 09-29）
- 学习事件落库：Knowledge 9 项 LEARNING_VERIFIED / Algorithms 2 项 / Projects 1 项，其余挂 LEARNING 或 Repair
- 复习 Capsule 17 个已进入时序（Knowledge 14 / Algorithms 2 / Projects 1），进度随时以 `scheduler.sqlite3` 与三引擎库为准

## 七、许可与说明

本仓库内容仅供个人秋招复习使用。试题来自公开面经与统考真题。资料库（王道教材 Markdown、面试资料、PDF 教材与真题等）**仅保存在本地、不入 git**，版权归原作者所有，请勿用于商业分发；克隆仓库后按需自行放置资料并运行 `expand-materials` 重建检索索引。
