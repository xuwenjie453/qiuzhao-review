# Read Order & Authority Prompt

在写任何代码之前，按以下顺序读取并建立事实表。

## 必读顺序

### A. 仓库运行规则
- `/AGENTS.md`
- `/README.md`
- `/双端更新实施状态.md`
- `/双端Release验收清单.md`

### B. QuestionGraph 继承权威设计
- `90_设计稿基线/01_产品与领域/04_问题图领域模型.md`
- `90_设计稿基线/01_产品与领域/05_问题图继承与共享解释节点.md`
- `90_设计稿基线/03_协议与同步/03_GraphSnapshot与Patch.md`
- `90_设计稿基线/03_协议与同步/04_ClientCommand与冲突处理.md`
- `90_设计稿基线/04_iPad端/02_问题图Topology设计.md`
- `90_设计稿基线/05_集成与迁移/04_迁移与兼容策略.md`
- `90_设计稿基线/05_集成与迁移/06_问题图继承实施清单.md`

### C. 当前代码
至少读取：
- `DualEnd-Mac/src/store/state-db.mjs`
- `DualEnd-Mac/src/graph/question-graph-service.mjs`
- `DualEnd-Mac/src/daemon.mjs`
- `DualEnd-Mac/src/bridge/sync-session.mjs`
- `DualEnd-iPad/QiuZhaoReader/Domain/Models.swift`
- `DualEnd-iPad/QiuZhaoReader/Store/ClientStore.swift`
- `DualEnd-iPad/QiuZhaoReader/Sync/SyncEngine.swift`
- Topology / Reader / Pencil 相关实现
- `学习系统/lsys/schema.py`
- `学习系统/lsys/probe_compiler.py`
- Review runtime/CLI 与 RuntimePrompt 21 双端协议

## 输出要求

开始编码前先输出一个简短的“权威事实表”：

| 主题 | 冻结设计 | 当前代码 | 是否存在 gap |
|---|---|---|---|
| node ownership | ... | ... | ... |
| inheritance relation | ... | ... | ... |
| effective view | ... | ... | ... |
| revision fan-out | ... | ... | ... |
| iPad membership cache | ... | ... | ... |
| capsule primary source | ... | ... | ... |

若设计与代码冲突，以设计为目标；若两份设计文档互相冲突，停止实现并明确指出具体冲突，不要自行选一套语义。
