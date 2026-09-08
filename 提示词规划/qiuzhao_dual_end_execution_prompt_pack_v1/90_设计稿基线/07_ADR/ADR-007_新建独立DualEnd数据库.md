# ADR-007：双端数据使用独立 SQLite

Status: Accepted

不将 graph/layout/ink/outbox 塞入 scheduler.sqlite3。

理由：这些是展示/同步领域，高频且与学习调度事务无关。独立库让原系统可单独运行，也便于安全回滚双端功能。
