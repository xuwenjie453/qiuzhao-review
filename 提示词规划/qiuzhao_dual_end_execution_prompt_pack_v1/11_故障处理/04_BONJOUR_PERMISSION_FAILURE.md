# Local Network / Bonjour 故障排查

按顺序：
1. Info.plist `NSLocalNetworkUsageDescription`
2. `NSBonjourServices` 包含 `_qiuzhaoreview._tcp`
3. Mac daemon 实际 advertise
4. 防火墙/LAN isolation
5. iPad 系统 Local Network 权限
6. NWBrowser state/error

用户拒绝权限时 UI 必须显示权限拒绝，不做手动 IP 兜底来绕过产品要求。
