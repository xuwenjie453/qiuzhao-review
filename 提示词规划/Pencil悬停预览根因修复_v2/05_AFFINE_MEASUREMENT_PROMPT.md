# 三点仿射偏移测量提示词

不能用“看起来向右下”作为根因。请在同一页、同一方向和同一 hover 距离采集至少三个点。

## 采样

建议页面 canonical Y：

```text
上方  P1 = (pageWidth/2, 180)
中部  P2 = (pageWidth/2, 420)
下方  P3 = (pageWidth/2, 660)
```

每个点记录：

```text
实际 Pencil 落点/参考点
hover 预览中心
Δx = hover.x - actual.x
Δy = hover.y - actual.y
当前 scroll.zoomScale
当前 contentOffset
```

## 判断

- `Δx、Δy` 近似常数：优先检查 origin、safe area、contentInset、contentOffset；
- `Δy` 随页面 Y 线性变化并在中部反转：缩放比例或锚点错误；
- `Δx` 随 Y 变化：旋转/剪切或复合 transform；
- 只有首次进入出现：初始化时序或旧 presentation layer；
- 外层 zoom=1 消失：外层 zoom 与 hover preview 不兼容的证据。

输出拟合式：

```text
P_actual = O + S·P
P_hover  = O' + S'·P
ΔP       = (S'-S)·P + (O'-O)
```

不得用单一补偿值替代拟合结果。
