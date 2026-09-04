# 秋招智能学习与复习体系 V1

基于 `试题库/`（真人题库）与 `资料库/`（教学资料源）构建的目标驱动学习系统。
闭环：`Goal → Scheduler → LEARN/REVIEW → Event → Capsule → Review → State → 再调度`。

## 运行

```bash
python3 学习系统/cli.py init          # 创建全部数据库(幂等)
python3 学习系统/cli.py seed          # 按试题库子类播种引擎节点(幂等)
python3 学习系统/cli.py bootstrap     # 首个 Goal: 25-Day Autumn Recruitment Coverage
python3 学习系统/cli.py task          # 下一项 TaskIntent(LEARN/REVIEW/REPAIR)
```

## 数据层(物理边界, 架构冻结)

```text
scheduler.sqlite3              # goals/policies/sessions/review_schedule(只放根目录)
Knowledge/knowledge.sqlite3    # 节点/关系/learning_events/states/review_capsules
Algorithms/algorithms.sqlite3  # 同上, skill_nodes 支持 TEMPORARY/PERSISTENT
Projects/projects.sqlite3      # 同上, engineering_nodes 含 PSB
资料库/materials.sqlite3        # Hybrid RAG: documents/chunks/FTS5/embeddings
试题库/questions.sqlite3        # 正式题库, 学习系统只读, 永不写入
```

## 会话方式(人机分工)

用户只负责**看、想、说、写代码**；AI(助手)负责判断、检索、教学、评估、记录、调度。
在本仓库中开启会话直接说"开始学习"即可，助手将：

1. 运行 `task` 取得 TaskIntent；
2. LEARN：给出真人原题 → 用户自然作答 → AI 诊断(已会/部分会/陌生) → Hybrid RAG 检索资料库 →
   动态生成 G1~G6 最小充分知识块(不问用户要粒度) → 撤块重答+2~4道验证 → `learn-verify` 生成 Capsule；
3. REVIEW：只给一个 Micro Probe 冷启动 → AI 判定 → `review-grade`；**成功一次立即结束**；
4. 失败 → Tiny Repair / 回 Learning，`REVIEW_FAILURE` 与 `REPAIR_SUCCESS` 两事件并存，不覆盖事实。

自然语言随时覆盖(生成 session 级临时策略，不动长期 Goal)：
"今天只学MySQL" / "先做算法" / "这部分我会" / "再展开一点" / "明天有面试"。

## 记忆模型

FSRS-inspired：Difficulty D / Stability S / Retrievability R。
`R = (1 + 0.2346·t/S)^-0.5`（透明幂曲线，R 运行时计算不存储；接口不变可升级 FSRS-6 拟合参数）。
Desired Retention 由 Goal 类型 + 进度连续漂移决定（Coverage 早期0.80→后期0.90），不是全局常数。
`next_due_at` 只是候选时点，**不是 Due Queue**；LEARN/REVIEW 在统一效用函数下竞争，
Coverage Goal 下新学习有保底权重，不允许 Review Debt 吞掉新学习。

## 扩展(Expansion Hub)

- **Goal Expansion**：`cli.py add-goal "15天冲刺复习已有知识"` → Goal Compiler
- **Materials Expansion**：新资料放入 `资料库/` 后 `cli.py expand-materials` → hash diff 增量索引
- **QuestionBank Expansion**：正式题库只读。扩展必须由用户单独发起、单独设计新版扩展 Prompt，学习系统禁止自动写题。

## 检索(Hybrid RAG)

- SQLite FTS5（trigram，中文子串可查）按词项检索，词项按稀缺度加权；
- Embedding 语义检索（V1 为确定性 char-bigram 哈希向量，接口不变可换真实模型）；
- 0.5/0.5 融合；Small-to-Big：Concept 命中 → 按需拉 Section/Document 父块。

```bash
python3 学习系统/cli.py retrieve "间隙锁 next-key"
python3 学习系统/cli.py small-to-big --chunk chk-xxxx
```

## 事件重放与验收

- `cli.py replay`：events → replay → 重建 Current State（状态可随时删除重建）
- `cli.py integrity`：五库 `PRAGMA integrity_check` + `foreign_key_check` + schema_version
- `python3 学习系统/test_e2e.py`：21项端到端验收（临时环境，不污染正式库）

## 版本

- schema_version 1.0（各库 `schema_meta`）
- scheduling_version ts-v1（调度权重/曲线参数，可调参版本化）
- prompt_version engine-v1 / rpc-v1（学习与 Capsule 编译契约）
