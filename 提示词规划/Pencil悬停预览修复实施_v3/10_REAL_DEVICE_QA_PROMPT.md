# Phase 3：真机 QA 与交付验收

实体 iPad + Apple Pencil 是唯一有效的 hover 验证环境。本阶段逐项留证据（截图/日志/数值），任何一项不过即回 Phase 1，不得带病交付。

## 装机

```bash
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader \
  -destination 'generic/platform=iOS' -configuration Debug \
  -derivedDataPath DualEnd-iPad/build/DEVICE -allowProvisioningUpdates build
xcrun devicectl device install app --device AD98BAD8-7CB8-5EE3-AC86-8517E419613F \
  DualEnd-iPad/build/DEVICE/Build/Products/Debug-iphoneos/QiuZhaoReader.app
```

（连接被重置属常见抖动，重试即可；设备需解锁并信任。）

## 验收清单（按序，逐项记录证据）

### A. 历史笔迹兼容（最高优先，先于一切新行为验证）

1. 打开**修复前已书写批注**的既有节点（如 Transformer 解释节点）：历史笔迹与正文逐字对齐、无整体偏移——两代架构数据同为 canonical，理论零迁移，必须实证；
2. 对照法：同一节点在旧构建（9866df4 版）与新构建下截图并排比对，笔迹相对正文的落点一致。

### B. 近屏实时渲染（本 bug 的直接验收）

3. 悬停：预览点出现在笔尖正下方，页面上/中/下三点各验一次；如 Phase 0 装有探针，复测 Δ ≈ 0 对比基线；
4. 书写中：墨迹跟手不偏移，“笔在附近时错位”现象消失；
5. “远离归位”现象消失（不存在先错位后归位的跳变）；
6. 多笔连续书写（笔不离开感应范围连写多笔）：所有已写笔迹保持正确位置，不再等远离才归位。

### C. 数据与同步

7. 新写笔迹：落笔位置与显示位置一致；退出重进位置不变；
8. hover / 滚动不触发上传（daemon 侧无 ink 命令）、不产生多余 ink_revision（Mac 端 `graph snapshot` 或日志核对）；
9. 退后台/杀 App 后 flush 正常，重开无丢失。

### D. 视口与交互

10. 横屏进入：页面适宽（≈2 倍）、只纵向滚动、页间 gutter 不可写（页内白纸可写）；
11. 旋转横竖屏往返：适宽更新、阅读位置保持、笔迹与正文对齐保持；
12. 多页文档滚到第 3 页书写，位置正确；
13. 双击 Pencil 切橡皮/切回；工具栏橡皮按钮可用；
14. 双击节点进入、返回、再进另一节点，无崩溃无卡死（上一轮回归的专项复验）。

### E. 记录

- 每项 PASS 附一句证据（截图文件名 / 探针数值 / 观察描述）；
- 未覆盖项（设备型号、iPadOS 版本、未测场景）如实列出；
- 任一项 FAIL：记录复现步骤与现象，回 Phase 1 修复后整个清单重跑（不允许只补测失败项）。

## 通过标准

A–D 全部 PASS 才允许在交付报告写“真机验证通过”；否则写“待真机验证 + 剩余问题清单”。
