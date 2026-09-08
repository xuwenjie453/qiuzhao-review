# iPad SyncEngine 合同

SyncEngine 协调 BridgeConnection + ClientStore + AppSessionModel。

Server message：
1. 检查 session epoch；
2. dedup；
3. durable apply；
4. 更新派生 UI state；
5. ACK。

Patch：
- local revision == base → apply；
- mismatch → 不 apply，SNAPSHOT_REQUEST；
- 保留 local outbox intent；
- snapshot 后重放 outbox。

Client mutation：
1. View 调 Model；
2. Model 调 ClientStore local transaction；
3. UI 从 store/result 立即更新；
4. SyncEngine 发送 outbox；
5. 只有 COMMAND_ACK 才删除。

禁止：
- socket send completion 当 server commit；
- ACK 先于 local commit；
- 新 epoch 接受旧 ACK。
