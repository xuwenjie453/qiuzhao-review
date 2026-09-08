# iPad Architecture Reviewer

检查：
- 完整 Xcode app target；
- Store/Connectivity/Sync/UI 分层；
- network callback 不直接改 canonical UI state；
- cache-first startup；
- offline可读；
- no PairingView；
- Topology 与 Reader 分层；
- MainActor 上无明显 DB/blob I/O。
