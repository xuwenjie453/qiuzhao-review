# 实际变更面（基线后）

| 类别 | 文件 | 标记 | 变更 |
|---|---|---|---|
| Mac canonical | `DualEnd-Mac/src/store/state-db.mjs` | MUST | schema v2、真实 additive migration、`graph_inheritance` |
| Mac canonical | `DualEnd-Mac/src/graph/question-graph-service.mjs` | MUST | effective view、继承声明、祖先/后代 fan-out、共享节点 mutation |
| Mac canonical | `DualEnd-Mac/src/daemon.mjs` | MUST | affected graph patch/snapshot routing |
| Wire | `DualEnd-Mac/src/protocol/envelope.mjs`, `src/util.mjs`, `src/bridge/sync-session.mjs` | MUST | protocol v2 negotiation；v1 client 遇继承图返回 `UPGRADE_REQUIRED` |
| iPad | `Domain/Models.swift`, `Protocol/GraphCodec.swift` | MUST | owner/visibility/parent graph 解码 |
| iPad | `Store/ClientStore.swift` | MUST | owner cache + graph membership cache additive migration；snapshot/patch membership apply |
| Learning/Review | `学习系统/lsys/schema.py`, `db.py`, `probe_compiler.py`, `cli.py` | MUST | `primary_source_question_id` migration and explicit compiler/CLI input |
| Runtime Prompt | `提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/21_双端问题图与iPad协作协议.md` | MUST | Review inherit_from and shared-node behavior boundaries |
| Fixtures | `DualEnd-common/fixtures` | NO CHANGE EXPECTED | existing v1 fixtures remain valid under explicit v1 compatibility; new inheritance fixtures pending |
| iPad UI | `Topology`, `Reader/Ink` | NO CHANGE EXPECTED | existing node-level rendering works with DTO additions; warning/delete confirmation UI follow-up pending |
