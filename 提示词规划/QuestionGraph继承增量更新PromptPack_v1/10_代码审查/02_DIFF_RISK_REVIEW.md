# Diff Risk Review Prompt

专门审查增量修改是否过宽。

## 查找风险

- 是否顺手重构了无关 sync/Reader/Pencil；
- 是否把已有 schema/DB 重建而不是迁移；
- 是否把 required new fields 全变 optional 导致 silent downgrade；
- 是否删除旧测试或放宽断言；
- 是否用 catch-ignore 吞 migration/foreign key/CAS 错；
- 是否把 patch 全改成 snapshot，掩盖 revision model；
- 是否在 Swift cache 中保留旧 graph_id membership 假设；
- 是否出现 duplicated state：node canonical fields 同时存在 nodes_cache 和 membership row；
- 是否增加未在设计中的 per-graph layout/ink override；
- 是否将 primary_source_question_id 自动 backfill guessed values。

输出“必要改动 / 可疑扩张 / 无关改动”三类文件清单。
