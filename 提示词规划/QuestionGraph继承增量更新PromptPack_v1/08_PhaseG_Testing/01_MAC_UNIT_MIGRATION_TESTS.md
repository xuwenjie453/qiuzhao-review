# Mac Unit + Migration Tests Prompt

扩充 `DualEnd-Mac/test`，测试名称应直接表达产品不变量。

## Relation tests

- `review graph can inherit question bank graph`
- `duplicate inheritance is idempotent`
- `question bank cannot inherit review graph`
- `review cannot use second primary parent in v1`
- `self inheritance rejected`
- `cycle rejected`

## Effective view tests

- `center is never inherited`
- `temporary is never inherited`
- `inherited explanation keeps canonical node id`
- `parent later explanation becomes child visible`
- `child explanation not visible to parent or sibling`

## Mutation/revision tests

- rename/move/delete shared node write-through；
- owner + all visible child graph revisions monotonic；
- child-own mutation not fan-out to unrelated graphs；
- ink does not increment graph_revision；
- stale node/layout revision rejected。

## Migration tests

构造真实 v1 schema，而不是直接创建 v2 再改 meta。验证升级、重启、integrity、FK、已有 data/revisions 保留。
