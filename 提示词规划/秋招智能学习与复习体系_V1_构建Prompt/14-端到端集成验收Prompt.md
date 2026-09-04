# V1 端到端集成验收 Prompt

目标：证明系统真正形成闭环，而不是一组互不连接的 Prompt。

## 初始化
确认可读：
- questions.sqlite3
- materials.sqlite3
- scheduler.sqlite3
- knowledge.sqlite3
- algorithms.sqlite3
- projects.sqlite3

## 创建25天Goal
调用 Goal Compiler，并确认 Scheduler 能读取。

## Knowledge E2E
选择一道人类 Knowledge 题：
- cold answer
- G2/G3
- validation
- repair
- verified
- event
- capsule

模拟未来日期：
- Scheduler 选择 Review；
- one micro probe；
- success；
- reschedule。

## Algorithms E2E
选择一道人类算法题：
- natural thinking
- skill decomposition
- local skill block
- independent code
- tests
- transfer
- verified
- capsule

未来 Review：只测试一个 Component Skill，并提供完整非目标上下文。

## Projects E2E
选择一个工程问题：
- free answer
- PSB
- tradeoff
- failure mode
- transfer case
- verified
- capsule

Review：一个短 engineering probe。

## Goal Change
添加：
“15天冲刺复习已有知识”。

确认：
- 新 Goal 不删除旧 Goal；
- Scheduler policy 改变；
- Review / Importance 权重提高；
- New Learning 权重下降。

## 半年恢复
模拟180天后创建 Reactivation Goal。
确认：
- 历史事件仍在；
- Retrievability 重算；
- 代表性 Probe 重新诊断；
- 成功快速恢复 Stability；
- 失败进入 Relearning。

## 资料扩展
放入新增资料文件，运行 Material Expansion。
确认：
- hash diff
- new chunks
- FTS
- vector
- Knowledge 查询可命中

## 最终 QA
全部数据库：

```sql
PRAGMA integrity_check;
PRAGMA foreign_key_check;
```

通过后只输出简洁验收结果：
- 已建模块
- 数据库路径
- schema/prompt版本
- E2E测试结果
- Active Goal
- 已知限制
