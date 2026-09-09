# 根因 A/B 实验提示词

通过最小可逆实验区分“外层 zoom 架构问题”和“初始化时序问题”。实验代码只允许用于诊断分支，不能直接作为最终修复。

## A：外层 zoom 对照

分别运行：

```text
方案 A1：outer UIScrollView zoomScale = 1
方案 A2：当前横屏 fit-width zoomScale ≈ 2
```

保持页面、Canvas、drawing 和 Pencil 姿态不变。若 A1 正常、A2 偏移，则确认父级 zoom 是必要条件。

## B：内部 Canvas 对照

比较以下状态，但不修改 drawing：

```text
B1：canvas contentSize = bounds，内部 zoom=1，offset=0
B2：不手工重置 canvas contentSize，只由 PKCanvasView 管理
```

如果 B1/B2 结果不同，说明内部 Canvas geometry 参与了 hover 矩阵。

## C：初始化时序对照

对新节点分别在以下时刻 hover：

```text
进入后立即
等待 500ms
等待 1s
canvasViewDidFinishRendering 后
```

若只有早期时刻失败，记录具体未稳定的 frame/transform，不得把固定等待时间当最终方案。

## 输出

| 实验 | 条件 | hover 偏移 | 正式落笔 | drawing 哈希 | 结论 |
|---|---|---|---|---|---|
