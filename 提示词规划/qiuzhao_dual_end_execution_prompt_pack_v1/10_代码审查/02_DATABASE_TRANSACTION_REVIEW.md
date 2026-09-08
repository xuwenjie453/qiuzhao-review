# Database / Transaction Reviewer

检查 Mac：
- WAL/FULL/FK；
- migration；
- command dedup 与 mutation 同 transaction；
- journal 与 mutation 同 transaction；
- commit 后才 emit；
- safe mode；
- busy/error handling。

检查 iPad：
- ClientStore actor；
- UI mutation 先 local durable；
- snapshot/patch transaction；
- inbox dedup；
- outbox ACK 前不删；
- background flush Ink。
