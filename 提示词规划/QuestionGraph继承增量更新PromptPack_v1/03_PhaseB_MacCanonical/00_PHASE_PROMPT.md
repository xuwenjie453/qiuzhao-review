# Phase B — Mac Canonical Prompt

本阶段只解决 Mac canonical truth：schema migration、inheritance relation、effective view、shared mutation、revision fan-out。不要先改 iPad UI。

## 修改目标

- `SCHEMA_VERSION` 从 1 升到 2。
- 建立真实 migration runner，可从 existing v1 DB 升级。
- 新增 `graph_inheritance`。
- QuestionGraphService 能建立/查询 inheritance。
- snapshot 返回 effective view。
- inherited command 必须先验证 view visibility。
- shared structural mutation 触发 affected graphs revision fan-out。
- 现有 node/layout/ink identity 与 CAS 不改变。

## 阶段 Gate

至少满足：

- v1 DB migration 无损；
- relation idempotent；
- source type/self/cycle guard；
- CENTER/TEMPORARY 不继承；
- inherited Explanation 保持 same node_id；
- parent 后增 Explanation child 可见；
- child 新 Explanation parent/sibling 不可见；
- rename/move/delete shared mutation 最终 parent/children 一致；
- old graph without inheritance 行为与 v1 相同。

未通过这些测试不得进入 Wire/iPad。
