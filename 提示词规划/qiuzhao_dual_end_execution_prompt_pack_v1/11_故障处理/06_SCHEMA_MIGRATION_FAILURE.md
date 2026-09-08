# Schema / migration failure

如果现有 dual-end DB 已存在：
- 先备份；
- 只做 forward migration；
- 不自动 drop/recreate；
- integrity fail → SAFE_MODE；
- 提供导出/诊断。

绝不能碰原 scheduler/engine/question DB 来“解决”双端 schema 问题。
