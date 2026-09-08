# 跨端错误模型合同

Mac domain error：
```text
code
message
retryable
details
```

iPad 映射：
- retryable transport → 自动重试；
- revision conflict → reconcile；
- center delete → UI rollback + developer diagnostic；
- permission denied → 本地权限 UX；
- protocol unsupported → 停止重试并提示升级；
- safe mode → 只读 cache/服务器状态提示；
- daemon unavailable → offline cache。

用户文案与 machine code 分离。
