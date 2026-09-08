# Bonjour 自动发现与连接

## 1. 产品体验

用户只需要：

- Mac daemon 正在运行；
- iPad Reader 已启动；
- 两者同一 LAN。

不出现 IP 输入框，不出现端口输入，不出现 6 位配对码。

## 2. 服务

Bonjour service type：

`_qiuzhaoreview._tcp`

TXT 最小字段：

```text
proto=1
daemon_id=<stable uuid short>
workspace=<workspace fingerprint short>
bridge=ws
```

不要把 secret 放 TXT。

## 3. iPad 发现

使用 Network.framework `NWBrowser` 浏览 Bonjour。iPad `Info.plist` 必须包含：

- `NSLocalNetworkUsageDescription`
- `NSBonjourServices` 包含 `_qiuzhaoreview._tcp`

第一次触发本地网络访问时，iPadOS 会显示系统授权；这是 OS 权限，不属于“手动配对”。如果用户拒绝，App 必须明确显示“本地网络权限被拒绝，无法自动发现 Mac”，不能伪装为“Mac 不在线”。

## 4. 自动选择策略

发现多个 daemon 时仍不要求手工选择：

1. 如果存在已缓存 `preferred_daemon_id` 且在线，连接它；
2. 否则过滤 `proto=1`；
3. 按 `daemon_id` 稳定排序选择第一台；
4. 成功完成 WELCOME 后缓存为 preferred。

这符合个人单 Mac 场景，同时保持确定性。

## 5. 重连

指数退避建议：0.5s, 1s, 2s, 4s, 8s，之后固定 10s；发现结果变化可立即打断退避尝试。App 在前台时持续浏览；后台不承诺常驻连接，恢复前台后立即重连。
