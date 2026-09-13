# iPad 端构建与安装

## 真机（推荐，Pencil/hover 只能在真机验证）

```bash
# 1. 找设备（设备 ID 会变，以实测为准）
xcrun devicectl list devices

# 2. 构建（Automatic 签名，Team 6R3PZDAJGW（2026-09-11 起：个人免费团队，免费签名 7 天过期需重签）；需本机有开发者证书）
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader \
  -destination 'platform=iOS,id=00008132-001125311ED1401C'（具体设备目标会自动注册设备到团队，比 generic 稳） -configuration Debug \
  -derivedDataPath DualEnd-iPad/build/DEVICE -allowProvisioningUpdates build

# 3. 安装（首装/偶发 "Connection reset by peer" 属抖动，重试即可；设备需解锁）
xcrun devicectl device install app --device <设备ID> \
  DualEnd-iPad/build/DEVICE/Build/Products/Debug-iphoneos/QiuZhaoReader.app
```

Bundle ID：`local.qiuzhaoreview.ipad2`。首启会出现"本地网络用途说明"页，点继续即开始连接（**静态直连优先**，见下节；无候选时才走 Bonjour 发现）。

## 静态端点直连（2026-09-13 起，默认开启）

iPad 默认直连 `192.168.1.197:57689`（纯 IP:Port，**不碰 mDNS、不碰 DNS 解析**，免疫 VPN fake-ip 劫持）。双端网络身份与配套关系见 `04_双端Mac守护进程.md` 第一、三节。

- **正常无需任何配置**：默认值内置于 `Connectivity/BonjourBrowser.swift` 的 `StaticEndpoint`；
- **覆盖地址/端口**（Mac IP 或端口变化时，免重编译；先终止 app）：

```bash
DEV=AD98BAD8-7CB8-5EE3-AC86-8517E419613F   # 以 xcrun devicectl list devices 实测为准
APP=local.qiuzhaoreview.ipad2
# 1) 备份当前 Preferences
xcrun devicectl device copy from --device "$DEV" \
  --domain-type appDataContainer --domain-identifier "$APP" \
  --source "Library/Preferences/$APP.plist" --destination /tmp/prefs.plist
# 2) 修改（host / port 二选一或都改）
plutil -replace "dualend.static.host" -string "192.168.1.197" /tmp/prefs.plist 2>/dev/null \
  || plutil -insert "dualend.static.host" -string "192.168.1.197" /tmp/prefs.plist
plutil -replace "dualend.static.port" -integer 57689 /tmp/prefs.plist 2>/dev/null \
  || plutil -insert "dualend.static.port" -integer 57689 /tmp/prefs.plist
# 3) 推回（覆盖整个域——步骤 1 的备份就是为防此事）
xcrun devicectl device copy to --device "$DEV" \
  --domain-type appDataContainer --domain-identifier "$APP" \
  --source /tmp/prefs.plist --destination "Library/Preferences/$APP.plist"
# 4) 重启 app 生效
```

- **关闭静态直连**（回退纯 Bonjour）：同上方式写 `dualend.static.disabled = true`；
- **验证生效**：Debug 构建 `launch --console` 日志出现
  `[diag] 静态端点直连: static://192.168.1.197:57689`，且**没有** `browse results` 行；
- **逃生门**：静态连续失败 5 次后自动让 Bonjour 发现一轮（Mac IP 变化时仍能自愈），会话建立成功后计数复位。

## 模拟器（UI 冒烟用；**连不上 daemon**）

```bash
xcrun simctl boot "iPad Air 11-inch (M4)"
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -derivedDataPath DualEnd-iPad/build/DERIVED CODE_SIGNING_ALLOWED=NO build
xcrun simctl install "iPad Air 11-inch (M4)" \
  DualEnd-iPad/build/DERIVED/Build/Products/Debug-iphonesimulator/QiuZhaoReader.app
xcrun simctl launch "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad2
```

**已知限制**：App 的 WebSocket 传输要求 wifi 接口，模拟器回环（lo0）不满足 → 永远"正在连接"。
模拟器验证 UI 用**离线播种**：

```bash
python3 DualEnd-iPad/tools/seed_offline_store.py /tmp/seed.sqlite
CONTAINER=$(xcrun simctl get_app_container "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad2 data)
mkdir -p "$CONTAINER/Library/Application Support/QiuZhaoReader"
cp /tmp/seed.sqlite "$CONTAINER/Library/Application Support/QiuZhaoReader/client-store.sqlite"
xcrun simctl terminate "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad2 2>/dev/null
xcrun simctl launch  "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad2   # 离线显示种子图
```

## 诊断钩子（仅 Debug 构建生效）

```bash
# 无头复现"双击进 Reader"（不依赖手工点击）
xcrun simctl launch "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad2 \
  -uiTestOpenReaderNode "<node_id 或 title>"

# 拉取 hover/几何探针数据（追加式 jsonl）
xcrun devicectl device copy from --device <设备ID> \
  --domain-type appDataContainer --domain-identifier local.qiuzhaoreview.ipad2 \
  --source Documents/hover-probe.jsonl --destination /tmp/hover-probe.jsonl
```

历史背景：hover 偏移与"双击卡死"已于 2026-09-10 修复（见 `提示词规划/Pencil悬停预览修复实施_v3/`），Reader 为"Canvas 唯一视口 owner"架构；如行为异常先读该包 06/07 号再动手。

## 测试

```bash
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -derivedDataPath DualEnd-iPad/build/DERIVED CODE_SIGNING_ALLOWED=NO test   # 32/32 为基线
```
