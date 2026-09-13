# Change Surface Map Prompt

基于真实代码形成文件级变更地图。

至少按以下类别列出：

### Mac canonical
- schema/migration
- QuestionGraphService
- daemon/local control
- sync session/journal（仅若必要）
- Mac tests

### Wire
- common fixtures
- codec/version fields
- patch/snapshot examples

### iPad
- Domain models
- GraphCodec/MessageCoder
- ClientStore schema/migration
- SyncEngine
- Topology
- Reader/Ink
- iPad tests

### Learning/Review
- engine schema
- probe compiler
- Review runtime/CLI
- RuntimePrompt 21
- learning E2E

对每个文件标：`MUST` / `LIKELY` / `NO CHANGE EXPECTED`。若你发现需要修改 `NO CHANGE EXPECTED` 文件，先解释原因再动手。
