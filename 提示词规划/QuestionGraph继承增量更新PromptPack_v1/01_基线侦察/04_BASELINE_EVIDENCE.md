# QuestionGraph 继承增量更新：基线证据

执行分支：`prompt/question-graph-inheritance-incremental-v1`

基线日期：2026-09-14（Asia/Shanghai）

本记录只描述改动前事实，不包含运行数据库快照；`main` 仍是运行分支。

## 测试证据

| subsystem | command | pass/fail | count | notes |
|---|---|---:|---:|---|
| Mac canonical | `cd DualEnd-Mac && npm test` | PASS | 39 | 改动前基线；Node test runner，0 failures |
| Learning system | `python3 学习系统/test_e2e.py` | PASS | 22 | 临时测试库，0 failures；未触碰正式题库 |
| iPad | `xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -derivedDataPath /tmp/qiuzhao-inheritance-baseline-derived CODE_SIGNING_ALLOWED=NO test` | PASS | 32 | Simulator unit/UI tests，0 failures；仅有 destination capability warning |

## 当前实现事实

- Mac `StateDb` 的 `SCHEMA_VERSION` 为 1，启动时仅执行 v1 DDL；尚无真实迁移 runner。
- Mac `QuestionGraphService.visibleNodes()` 只读取当前 `nodes.graph_id`，没有继承关系、effective view 或 owner/inherited visibility。
- Mac daemon/bridge 只路由单图 patch，结构变更只 bump 当前 graph revision。
- Wire snapshot/patch 与 iPad `GraphNodeDTO` 尚无 `owner_graph_id`、`visibility`、`parent_graphs` 等继承字段。
- iPad `nodes_cache` 以 `node_id` 为主键并带单一 `graph_id`，没有 graph membership cache，无法安全表达共享节点的多图归属。
- Learning review capsule 只有 `source_questions` JSON，没有显式 `primary_source_question_id`。

## 证据边界

以上测试证明改动前主流程可运行，不证明继承功能已存在。后续每个 checkpoint 必须追加针对新不变量的测试证据，并区分 `PREEXISTING` 与 `REGRESSION`。
