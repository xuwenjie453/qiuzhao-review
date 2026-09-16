# 04 — 回归测试与最终验收 Prompt

这是本 Bugfix 的完成门槛。不能只以“肉眼看起来不闪了”为结论，必须把 Node Drag 与 Canvas Pan 的状态隔离写成回归测试。

## 1. 先确认现有测试结构

当前 iPad tests 集中在：

```text
DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift
```

已有 `TopologyLogicTests` 覆盖：

- normalized/screen round trip；
- viewport clamp；
- visualPoint / graphPoint inverse transform；
- parent resolution。

优先在现有测试文件中增加纯逻辑测试，不要为了这个 Bug 引入大型 UI test framework。

## 2. 必须新增的不变量测试

### Test A — transient node drag 不改变 viewport constraint centers

构造：

```text
canonical/pending positions 固定
同一节点给多个不同 dragTransient
```

验证 viewport constraint centers 的计算不读取 transient。

如果 helper 仍在 View private scope 难测试，可将“stable position / constraint centers”中最小纯逻辑提取到可测 helper；不要因此重构整个 View。

核心断言：

```text
transient A != transient B
constraintCenters(A) == constraintCenters(B)
```

### Test B — Node Drag 时 canvas offset 不变

构造：

```text
committedCanvasOffset = 非零合法值
canvasDragTranslation = zero
stable centers 固定
节点 transient 连续变化
```

验证每一步 clamp 结果一致：

```text
O0 == O1 == O2 == ...
```

核心业务不变量：

```text
Δnode != 0
ΔcanvasOffset == 0
```

### Test C — Canvas Pan 仍可改变 offset

构造 blank-start pan 的 proposed offsets：

```text
committed offset + translation
```

验证：

- clamp 后 offset 随 translation 改变；
- 超界时仍 clamp；
- node canonical normalized position 不需要参与任何 mutation。

核心不变量：

```text
ΔcanvasOffset != 0
ΔcanonicalNode == 0
```

### Test D — pan 后 Node Drag inverse transform 仍正确

已有 transform test 可扩展成：

```text
graphPoint G
viewportOffset O
visual = G + O
inverse(visual, O) == G
```

再验证同一视觉 drag delta：

```text
O = 0 时的 canonical delta
==
O != 0 时的 canonical delta
```

这能防止为了修闪烁误删 inverse transform。

### Test E — visual hit testing 仍使用 viewport offset

验证：

- 节点 pan 后旧位置不应命中；
- 新视觉位置应命中；
- CENTER 同样算 node hit area。

防止 gesture ownership 回归。

## 3. Gesture ownership 人工/可测检查

至少覆盖这些场景：

| 场景 | 期望 |
|---|---|
| 从 EXPLANATION 中心开始拖 | Node Drag；Canvas 不动 |
| 从节点 hit rect 边缘开始拖 | Node Drag；Canvas 不动 |
| 从 CENTER 开始拖 | CENTER 不动；Canvas 也不动 |
| 从空白开始拖，途中经过节点 | 始终 Canvas Pan |
| 从节点开始拖，途中移到空白 | 始终 Node Drag |
| pan 后再从节点开始拖 | Node Drag canonical delta 正确，Canvas 不动 |

若当前单元测试无法直接驱动 SwiftUI gesture，可把 start-location ownership 判断抽成纯函数并测它。

## 4. 父子连线回归

创建层级：

```text
CENTER
└── A
    └── B
```

拖动 B 时验证：

- B 实时移动；
- A → B 连线终点实时移动；
- A、CENTER 视觉位置不因 viewport 改变而跳动；
- committed canvas offset 保持不变。

拖动 A 时：

- CENTER → A 与 A → B 两条相关连线实时更新；
- viewport 仍不应跟随。

## 5. 手工 Simulator / 真机验收

若环境有 Xcode/Simulator，必须执行：

1. 打开已有多个节点的问题图；
2. 先从空白 pan 到一个明显非零 offset；
3. 选择边缘 EXPLANATION 节点；
4. 连续缓慢拖动节点 3–5 秒；
5. 再快速大幅拖动；
6. 观察整个过程中背景、其它节点和 viewport 是否固定；
7. 松手后确认节点保持新位置；
8. 刷新/重连确认 canonical move 正确；
9. 再从空白拖动画布，确认 Canvas Pan 没被修坏；
10. 从 CENTER 起手拖动，确认既不移动 CENTER，也不触发 pan。

通过标准：

```text
Node Drag 期间只有目标节点及与其相连的线发生必要的局部几何变化；
整个 pannable layer 不发生额外位移。
```

## 6. 闪烁验收

不能只说“闪烁减少”。应确认：

- Node Drag 期间 `committedCanvasOffset` 不变；
- `canvasDragTranslation` 对 node-start drag 为 zero；
- `liveCanvasOffset` 不因 `dragTransient` 改变；
- SwiftUI layer `.offset(liveCanvasOffset)` 不被 node transient 反复驱动。

如果仍闪烁，检查顺序：

1. 是否仍有某个 clamp 调用使用 transient-aware `point(for:)`；
2. `viewportOffset` 是否在 NodeShapeView drag session 中被其它状态更新改变；
3. 是否有 animation 绑定到整个 canvas offset/layer；
4. hit testing 是否因 visual/canonical coordinate 混淆导致 gesture ownership 抖动。

不要先靠关闭 animation 解决；先确认状态依赖已正确隔离。

## 7. 运行测试

根据仓库实际 Xcode project/target 执行可用测试。

若有 Xcode CLI，优先运行对应 test target；命令以当前工程实际 scheme 为准，不要凭空猜 scheme。

若环境无 Xcode：

- 不得声称 iPad tests passed；
- 至少做静态代码审计；
- 最终报告明确写出未运行的 Simulator/真机项。

## 8. 最终审计清单

完成前逐项回答：

- [ ] viewport constraint centers 是否完全排除了 `dragTransient`？
- [ ] node rendering 是否仍使用 `dragTransient`？
- [ ] parent-child links 是否仍实时跟随 node drag？
- [ ] Node Drag 时 `liveCanvasOffset` 是否稳定？
- [ ] Canvas Pan 是否仍从 blank 正常工作？
- [ ] start-on-node 是否全程不会 pan？
- [ ] CENTER 起手是否不会 pan？
- [ ] pan 后 node inverse transform 是否仍正确？
- [ ] Canvas Pan 是否仍不产生 MOVE_NODE？
- [ ] 是否只修改 iPad Topology/tests 所需文件？
- [ ] 是否没有触碰 Mac/schema/sync/parent model？

全部满足才算修复完成。
