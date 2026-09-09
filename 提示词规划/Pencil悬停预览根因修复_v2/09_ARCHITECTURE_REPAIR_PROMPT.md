# 架构级坐标修复提示词

只有完成矩阵审计和 A/B 实验后才能执行本阶段。

## 首选目标

Reader 中只能存在一套从 canonical page 到屏幕的显示变换：

```text
screen = pageOrigin + pagePoint × displayScale
```

文字层、页面背景、Canvas 必须共享同一页面坐标和同一显示变换。

## 方案选择顺序

### 方案一：取消 Canvas 的父级 zoom transform（优先）

如果 A/B 证明父级 zoom 导致 hover 错位，优先让页面以最终显示宽度布局，而不是让 `PKCanvasView` 处于被父级缩放的 transform 下。可以保留 canonical 计算，但显示层不再把 Canvas 放在会被另一个 UIScrollView 缩放的层级中。

必须保证：

- 页面显示宽度仍填满横屏 Reader 区域；
- 只纵向滚动；
- Canvas 与文字同 frame；
- 历史 drawing 仍直接按原 canonical 坐标加载。

### 方案二：让同一个 ScrollView 成为唯一 viewport owner

如果不能取消外层 zoom，必须证明 Canvas 内部不会再参与任何独立缩放/offset，并在稳定 viewport commit 后启用 hover。不能同时用两个滚动容器做 offset/zoom 硬同步。

### 方案三：重新设计页面容器

只有前两种方案无法满足约束时，才考虑每页独立容器或 PDF/PencilKit overlay。必须先提供旧 `PKDrawing` 坐标兼容证明，不允许直接迁移点坐标。

## 明确禁止

- 根据 hover 位置加补偿；
- 上方和下方使用不同补偿；
- 乘/除 `PKDrawing` 点坐标；
- 将屏幕像素写入 Mac 协议；
- 用 `UIScreen.main.bounds` 代替 Reader 实际 bounds。

实现后说明每一层 transform 的来源，以及为何只剩一套矩阵。
