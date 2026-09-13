# Phase 0：真机取证（go/no-go 闸门）

目的：在动架构之前，用真机数值证据确认冻结的根因（`02`），并留下修复前的偏移基线供 Phase 3 对比。**本阶段在旧架构基线（9866df4）上加探针，不修 bug。**

## 一、探针规格（只读，不改变行为）

1. 全部代码 `#if DEBUG` 包裹；不绘制任何假笔迹/覆盖层（v2 10 号纪律）。
2. 在 `AnnotatedReaderView` 上挂 `UIHoverGestureRecognizer`（simultaneous，不抢占 PencilKit 手势），每个 hover move 事件记录：

```text
timestamp
location(in: canvas), location(in: window)      ← hover 真实笔尖位置（UIKit 报告，各 view 坐标系）
zOffset
scroll.zoomScale, canvas.zoomScale              ← 两套缩放（预期 2.0 / 1.0，直接证据）
scroll.contentOffset, canvas.contentOffset
scroll.bounds, canvas.bounds, contentView.frame, contentView.bounds
canvas.frame, canvas.bounds
contentView.layer.presentation()?.transform, canvas.layer.presentation()?.transform
```

3. 输出到 App Documents 下的 `hover-probe.jsonl`（一行一事件），同时 `os_log` 带前缀 `[hover-probe]`。
4. 滚动/缩放/渲染回调时追加一条几何快照行（同上字段，无 hover 位置）。

## 二、测量协议（关键：如何得到 Δ）

预览画在哪里**程序读不到**（PencilKit 私有），只有用户看得见。因此协议必须是“**对齐预览到地标**”，而不是“对齐笔尖”：

1. 选定 3+ 个视觉地标（建议：页面标题行的某个字、页面中部某行行首、页码数字），记录地标的 canonical 坐标（由排版参数推出，或截图对照）。
2. 用户操作：**移动 Pencil 使预览点恰好压在每个地标上，停约 1 秒**。
3. 探针日志里该时刻的 `location(in: canvas)` 即真实笔尖位置 → 屏幕位置。
4. Δ = 笔尖屏幕位置 − 地标屏幕位置（地标屏幕位置 = canonical · z − offset）。

多点采样后做一次仿射拟合：`Δ = (S′−S)·P + (O′−O)`：
- Δ 随位置线性变化、两端方向相反 → 比例/锚点失配（S′≠S）；
- Δ 恒定 → 纯平移失配；
- 拟合残差大 → 记录并上报，根因模型需要修正。

## 三、对照实验（可选但强烈建议）

临时诊断构建：外层适宽缩放强制 1.0（页面缩小，仅诊断用，不交付）。若近屏错位随 z=1 消失 → 外层缩放是必要条件，根因链闭合。

同时顺带断言（写进探针日志）：`canvas.setZoomScale` 生效值、PencilKit 是否自管 contentSize（对 contentSize 手工赋值后观察是否被改写）——这两项是 Phase 1 风险登记的前置情报。

## 四、证据提取与闸门

```bash
# 从真机取日志
xcrun devicectl device copy from --device AD98BAD8-7CB8-5EE3-AC86-8517E419613F \
  --domain-type appDataContainer --domain-identifier local.qiuzhaoreview.ipad \
  --source Documents/hover-probe.jsonl --destination /tmp/hover-probe.jsonl
```

产出物（写入本包目录或交付报告）：
1. 三点以上 Δ 数值表 + 拟合结论（S′−S、O′−O）；
2. `scroll.zoomScale` vs `canvas.zoomScale` 快照；
3. 对照实验结果（若做）；
4. **go/no-go 判定**：
   - 证据与根因模型一致（存在非零 Δ 且形式可归入仿射失配）→ 进入 Phase 1；
   - Δ≈0（真机上无法复现）→ 停止，报告复现条件问题，等用户配合复现；
   - Δ 形式与仿射失配矛盾 → 停止，报告证据，根因需重审（触发 `02` 的证伪条款）。

探针构建与数据分开 commit（`phase0-probe`），探针代码在 Phase 1 实施时移除。
