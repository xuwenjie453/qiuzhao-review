# Phase 01 — 基线侦察 Prompt

本阶段禁止实现 inheritance。目标是建立可信基线与变更面。

## 任务

1. 获取当前 branch/commit/status，确认没有未理解的工作区改动。
2. 读取现有 Mac/iPad/Learning 代码与测试。
3. 检查当前 schema version、wire version、iPad cache schema。
4. 运行现有测试：Mac、bridge/fixtures、学习系统、iPad build/unit（环境允许时）。
5. 记录所有已有失败，不要先修。
6. 形成 inheritance change surface map。

## 必须回答

- 当前 `nodes.graph_id` 在所有读写路径中如何被解释？
- snapshot 是 owner-only 还是有任何 membership 概念？
- `graph_revision` 在 add/rename/move/delete 哪些路径增加？Ink 是否独立？
- daemon 如何把 mutation result 转换为 patch？
- iPad `nodes_cache` 是否假设一个 node 只属于一个 graph？
- Review Capsule 从哪里得到 source question？
- Review `question.open` 的调用链在哪里？
- migration runner 是否存在，还是只有 empty DB DDL？

## 输出

提交一份不修改代码的侦察摘要，包括：baseline commands/results、关键文件、风险点、预计 Phase B-F 修改面。
