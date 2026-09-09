# 问题一：统一图布几何实现提示词

根据诊断结果实现统一几何层。

## 目标

建立一个唯一的 `GraphCanvasGeometry`（名称可按现有项目调整），集中负责：

```text
normalized → screen/local point
screen/local point → normalized
node visual rect
node hit rect
link endpoints
```

禁止在多个 View 中复制坐标公式。

## 坐标规则

- canonical layout 仍为 `x_norm/y_norm ∈ [0,1]`；
- 图布使用自己的本地坐标空间，原点为 `(0,0)`；
- 归一化坐标映射到明确的 `contentRect`，不能直接隐式依赖任意 ZStack 尺寸；
- `contentRect` 为图布内部区域，顶部为标题预留空间，左右和底部保留安全 padding；
- 屏幕旋转只重新计算 screen point，不修改 canonical layout；
- 所有坐标转换都做 clamp，并保留浮点精度。

## SwiftUI 布局规则

- QuestionGraphView 必须显式填充 GeometryReader 提供的全尺寸；
- 节点外层 hit target 固定尺寸，例如 88×88pt；
- glyph 固定尺寸，例如 64×64pt；
- title 是独立 overlay，不能改变节点外层 frame；
- title 不参与 hit test；
- ChildLink 不参与 hit test；
- 不用父级隐式 padding 修正偏移；
- 不用 `UIScreen.main.bounds` 推导节点位置。

## 不变量测试

加入单元测试验证：

- 任意测试尺寸和 inset 下，normalized round-trip 误差小于 0.0001；
- 节点 visual rect 和 hit rect 共享同一 center；
- 连线端点与节点 effective position 使用同一函数；
- 横竖屏只改变 screen point，不改变 normalized 值。

完成后输出实际采用的 contentRect 参数及其理由，不要只说“已统一坐标”。

