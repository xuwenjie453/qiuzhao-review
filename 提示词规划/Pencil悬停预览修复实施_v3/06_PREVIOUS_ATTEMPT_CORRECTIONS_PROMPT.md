# 对「暂存」版（5121d17）的修正清单

「暂存」是一次方向正确（路线 B）但有缺陷的重构，已在真机上造成“双击节点进不去/不可用”回归，故仓库回退。Phase 1 重做时**参考其 diff 但按下表逐项修正**。本文件同时是“为什么不能直接 revert 到暂存或 merge 它”的依据。

| # | 暂存版缺陷 | 后果 | v3 修正（对应 05 号条目） |
|---|---|---|---|
| 1 | `canvas.contentSize = documentSize`（canonical 单位）配 `zoomScale≈2` | 滚动范围按 UIScrollView 标准数学直接错误（横屏视口宽 ~1191 > 内容宽 595；纵向范围几乎为零），多页文档不可达——“进不去/不可用”的头号嫌疑 | contentSize 一律 display 单位 `documentSize × z`（05 §二），并在 08 号冒烟测试断言滚动范围 |
| 2 | 镜像层 `translatesAutoresizingMaskIntoConstraints=true` + 手写 layer 几何，autolayout 每轮回写 frame 与手写值打架 | 视觉漂移、时隐时现 | 所有权表（02 §3.3）+ `layoutSubviews` 兜底重申（05 §三-4）；镜像只依赖 bounds/layer，不依赖 frame |
| 3 | `applyViewport` 内 offset 夹取与 contentSize 顺序耦合不严 | 旋转后阅读位置跳变 | 固定顺序：zoom → contentSize → clamp offset（05 §二） |
| 4 | 无任何 Reader 全链路测试，未经验证直接装机 | 回归到用户手上才暴露 | 08 号 hosted 冒烟 = 硬闸门；09 号离线复现 = 手工端到端路径 |

## 可直接复用的部分（与 5121d17 diff 对照）

- `PencilToolController`：weak canvas + attach 幂等 + 双击 apply —— 正确，等价搬入。
- `ReaderHostView.updateUIViewController` 的 `pencil.attach/apply` 接线（Coordinator `attachedCanvas` 防重复挂 interaction）—— 正确，等价搬入。
- `PageCanvasView.hitTest` 的“只约束 pencil、手指放行”形式与 `contentOffset: .zero` 换算 —— 正确（05 §五，注释必须保留）。
- 新增的两个单测（canonical↔display 往返、比例失配符号反转）—— 保留并纳入 07 号矩阵。

## 五、真机/模拟器实测定案（2026-09-10 补记，采样证据）

「双击节点即卡死」的**真正根因是 SwiftUI 状态反馈死循环**，与本表 #1/#2 均无关：

```text
updateUIViewController → pencil.apply(to:isEraser:) → self.isEraser = isEraser
  （@Published 同值写入也触发 objectWillChange）
→ @StateObject 观察 → ReaderHostView 重渲染 → updateUIViewController → ∞
```

- 主线程 99% CPU，`sample` 采样栈实证（PencilToolController.swift:46 isEraser.setter 链）。
- 暂存版引入 @StateObject 接线时即带上此雷——它才是“暂存进不去节点”的真凶；
  v3 Phase1 沿用暂存接线而复发。
- 修复：`apply` 仅在 `self.isEraser != isEraser` 时写入；回归测试
  `PencilLoopGuardTests.testApplyWithSameValueDoesNotPublish` 钉死。
- 无头复现装置：`-uiTestOpenReaderNode <node_id|title>` launch argument（DEBUG）。
- #1/#2（contentSize 单位、frame 布局化）仍是正确修正，保留。

## 禁止事项

- 禁止 `git checkout 5121d17 -- <Reader files>` 整文件搬回：缺陷 #1 会原样带回。
- 禁止把“进不去节点”当成无关问题忽略：v3 的完成条件包含 08 号闸门全绿。
- 若 Phase 2/3 中复现暂存版的回归现象，优先怀疑 #1（contentSize 单位）与 #2（镜像打架），按所有权表排查。
