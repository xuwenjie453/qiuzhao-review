# Phase H Release Gate Evidence

审计日期：2026-09-14（Asia/Shanghai）

| gate | status | evidence / limitation |
|---|---|---|
| schema v1→v2、FK/index | PASS | `StateDb` additive migration + `graph_inheritance` FK/index；Mac tests 通过 |
| effective view / owner / visibility | PASS | Mac inheritance test：Review own CENTER + inherited persistent EXPLANATION，共享 `node_id` |
| rename/move/delete fan-out | PASS | affected graph ids 与每图 revision；全局 tombstone delete |
| Ink node-scoped、不推进 graph_revision | PASS | 保持既有 `putInk` 路径；未改 graph revision |
| CAS/dedup/durable journal | PASS | 原有 Mac/bridge/idempotency tests 全通过（43 项） |
| Review primary source | PASS | schema/compiler/CLI 显式 `primary_source_question_id`；无数组首项推断 |
| Review open inheritance / missing parent | PASS | `question.open` 支持 `inherit_from`；parent 缺失返回诊断字段但继续打开 |
| wire v2 / fixtures | PASS | v2 协商、v1 明确兼容；旧 client 遇继承图返回 `UPGRADE_REQUIRED`；新增 3 个 fixtures |
| iPad membership / inherited UX / delete warning | PASS | canonical node + membership cache、链路 badge、共享删除警告已实现 |
| iPad build | PASS | `xcodebuild ... build` 成功 |
| iPad simulator unit test | BLOCKED | 当前机器 Simulator 启动测试 runner 反复返回 `Application failed preflight checks (Busy)`；不是代码编译错误 |
| Learning E2E | PASS | `python3 学习系统/test_e2e.py`：23 PASS / 0 FAIL |
| main runtime DB | NOT_RUN | 本次只在 feature branch 改代码/Prompt；未写入 `main` 运行数据库 |
| true-device acceptance | NOT_RUN | 需要实际 iPad 与局域网环境 |
