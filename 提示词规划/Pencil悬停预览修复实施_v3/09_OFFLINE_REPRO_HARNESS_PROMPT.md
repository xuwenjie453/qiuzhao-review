# Phase 2C：离线端到端复现装置（长期资产）

目的：模拟器内 App 的 WebSocket 传输要求 wifi 接口、连不上本机 daemon（lo0 不满足，Bonjour 解析失败），导致模拟器无法自然获得图数据。本装置用**播种本地缓存**的方式让 App 离线显示节点，从而：

- 手工端到端验证“双击节点 → Reader 打开 → 滚动/书写路径存在”（Bug 2 类回归的 5 分钟手工路径）；
- 为今后一切 Reader 回归提供不依赖 daemon/Bonjour 的复现环境。

App 离线显示原理：`AppSessionModel.bootstrap()` 先读 `store.cachedGraphState()`（`cachedOffline` 相位即可渲染缓存图），不需要网络。

## 实施步骤

1. **生成种子库（推荐用 ClientStore 自身，不手写 SQL）**：
   - 读 `DualEnd-iPad/QiuZhaoReader/Store/ClientStore.swift` 与 `DualEnd-common/fixtures/` 的协议 fixtures；
   - 写一个小工具（Swift 测试或脚本，放 `DualEnd-iPad/tools/`）：用 ClientStore 的公开 API 把一个含 CENTER + 超长 EXPLANATION 节点的 snapshot 应用进全新 `client-store.sqlite`（长正文用于压多页分页）；
   - 兜底方案：按 ClientStore schema（`nodes_cache`/`graphs_cache`/`active_state` 等）裸 SQL 插入，但必须先读源码核对字段与约束。
2. **注入模拟器**：

```bash
xcrun simctl boot "iPad Air 11-inch (M4)"
xcrun simctl install "iPad Air 11-inch (M4)" <app>
CONTAINER=$(xcrun simctl get_app_container "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad data)
mkdir -p "$CONTAINER/Library/Application Support/QiuZhaoReader"
cp seed/client-store.sqlite "$CONTAINER/Library/Application Support/QiuZhaoReader/"
# 首启权限说明不拦截：种 UserDefaults
/usr/libexec/PlistBuddy -c "Add :dualend.permission.note.shown bool true" \
  "$CONTAINER/Library/Preferences/local.qiuzhaoreview.ipad.plist"
xcrun simctl launch "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad
```

3. **验证清单**：
   - 问题图页面离线显示 2 个节点（徽章“离线 · 显示本地内容”）；
   - 双击 CENTER 与双击 EXPLANATION 都能进入 Reader；
   - Reader 打开后页面适宽、可纵向滚动（多页到底）、Pencil 事件路径存在（模拟器无真笔迹，只验证不崩溃、滚动流畅）；
   - 退出重进不崩溃、无残留状态。

## 维护约定

- 种子生成脚本入库（`DualEnd-iPad/tools/`），README 注明用途；
- 本装置不依赖 daemon，也不得反向要求改 daemon/协议；
- 每次怀疑 Reader 回归，先跑本装置再上真机。
