# 代码审查总控

每个 Phase 结束后，选择相关专项 reviewer prompt。Reviewer 应基于真实 diff/source/test，不根据实现者自述直接 PASS。

所有 reviewer 输出统一：
- BLOCKER
- MAJOR
- MINOR
- PASS evidence

Release 前全部 BLOCKER 必须为 0。
