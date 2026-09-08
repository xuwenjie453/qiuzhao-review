# Mac StateDB 合同

建议职责：唯一持有 `dual-end.db` 连接/transaction primitive。

建议接口（伪代码）：
```text
StateDB.open(path)
StateDB.migrate()
StateDB.integrityCheck() -> IntegrityReport
StateDB.read(fn)
StateDB.transaction(fn)
StateDB.close()
```

要求：
- 打开即设置 WAL/FULL/FK/busy_timeout；
- schema version 存 meta/migrations；
- transaction callback 内异常必须 rollback；
- 不在 StateDB 内实现“CENTER 禁删”等高层规则，除 DB constraint/trigger；
- DB API 不返回裸 statement 给 WebSocket/HTTP handler 长期持有；
- body immutable trigger 必测；
- recovery/integrity 不允许自动删除损坏 DB。

并发：
- Node 端确保所有 write 经过有限串行/SQLite transaction；
- 同一 command 不拆成多个独立 transaction。

测试：
- reopen；
- rollback；
- busy/error；
- trigger；
- foreign keys。
