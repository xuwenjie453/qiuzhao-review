# Migration Failure Recovery Prompt

如果 v1→v2 migration 失败：

1. 立即停止后续 schema mutation。
2. 确认 SQLite transaction 是否 rollback；不要再次盲跑 destructive SQL。
3. 复制/保留原 DB 文件用于诊断（不修改原件）。
4. 检查 meta.schema_version 与实际表结构是否一致。
5. 检查失败点：DDL、index、FK、事务嵌套、旧 schema 差异。
6. 写一个最小 migration regression test reproducer。
7. 修 migration runner，使：
   - 已完成 v1 不重复建；
   - 半途失败 rollback；
   - 重启可安全重试；
   - 数据/revision/dedup/journal 不丢。
8. 只有 fixture migration + integrity + restart 全通过后再处理真实 DB。

禁止把 `schema_version=2` 单独写进去绕过失败。
