# 范围与安全边界

## 一、允许修改的文件（白名单之外一律不动）

```text
DualEnd-iPad/QiuZhaoReader/Reader/AnnotatedReaderView.swift    ← 架构实施主体
DualEnd-iPad/QiuZhaoReader/Reader/ReaderHostView.swift         ← Pencil 生命周期接线
DualEnd-iPad/QiuZhaoReader/Pencil/PencilToolController.swift   ← attach/apply 生命周期
DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift       ← 07/08 号测试
DualEnd-iPad/QiuZhaoReader.xcodeproj/project.pbxproj           ← 仅当测试需要 host app 或新文件入 target 时的最小改动
DualEnd-iPad/tools/ 或 DualEnd-iPad/scripts/（新建）            ← 09 号离线播种脚本
.gitignore                                                     ← 可追加 DualEnd-iPad/build/
```

Phase 0 探针代码允许临时出现在 Reader 文件内，但必须 `#if DEBUG` 包裹并在 Phase 1 实施时移除或收敛。

## 二、禁止修改（违反即失信）

- `DualEnd-Mac/` 全部（store/bridge/daemon/协议 fixtures）。
- WebSocket 协议、canonical schema、`DualEnd-common/`。
- 学习系统（`学习系统/`）、五个 SQLite 库、`试题库/questions.sqlite3`、其他 `提示词规划/` 既有包。
- 任何 `PKDrawing` 数据迁移逻辑；不得出现对 stroke 点坐标的乘除或平移。
- `ReaderTypography` 的 canonical 数值（595.92/842.88 及排版 token）。

## 三、Git 纪律

```bash
# 起点：HEAD detached 于 9866df4（旧架构基线）
git switch -c fix/pencil-live-render-v3     # 工作分支，从此分支上实施
# main 保持指向 5121d17 不动；交付后是否合并由用户决定
```

- 每阶段独立 commit：`phase0-probe`（诊断构建）、`phase1-architecture`、`phase2-tests`、`phase3-qa-evidence`。
- 「暂存」(5121d17) 只读参考：`git show 5121d17 -- DualEnd-iPad/QiuZhaoReader/Reader/AnnotatedReaderView.swift`。禁止 `git revert` / `git merge 5121d17` 一把梭——它的 contentSize 单位是错的（见 `06`）。
- 失败回退只回退当前阶段 commit。

## 四、环境事实与命令速查（执行前核对仍然有效）

| 项 | 值 |
|---|---|
| 真机 | iPad Air 11-inch (M4)，CoreDevice ID `AD98BAD8-7CB8-5EE3-AC86-8517E419613F`，已配对 |
| 签名 | Automatic，Team `GUS56DYZ6W`，本机有有效 Apple Development 证书 |
| 模拟器 | `iPad Air 11-inch (M4)` |
| Bundle ID | `local.qiuzhaoreview.ipad` |
| daemon | `node DualEnd-Mac/bin/qreview-dual.mjs daemon start/status`（只读使用，不改代码） |

```bash
# 模拟器构建 + 测试
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -derivedDataPath DualEnd-iPad/build/DERIVED CODE_SIGNING_ALLOWED=NO test

# 真机构建 + 安装（第一次连接被重置属常见抖动，重试即可）
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader \
  -destination 'generic/platform=iOS' -configuration Debug \
  -derivedDataPath DualEnd-iPad/build/DEVICE -allowProvisioningUpdates build
xcrun devicectl device install app --device AD98BAD8-7CB8-5EE3-AC86-8517E419613F \
  DualEnd-iPad/build/DEVICE/Build/Products/Debug-iphoneos/QiuZhaoReader.app

# 模拟器装 App（离线验证，见 09 号）
xcrun simctl install "iPad Air 11-inch (M4)" <app路径>
xcrun simctl launch  "iPad Air 11-inch (M4)" local.qiuzhaoreview.ipad
```

## 五、红线（继承 v2，全文有效）

- 不做 `+dx/+dy` 或分区域补偿；不乘除 PKDrawing 点坐标；不把屏幕坐标写入协议。
- 不用 `UIScreen.main.bounds` 替代 Reader 实际 bounds。
- 不禁用 hover / Pencil 书写 / 滚动。
- 没有真机验证不得宣称修复。
