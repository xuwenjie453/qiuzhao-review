# 偏移数学测量提示词

你需要通过三个或更多页面位置测量偏移，不能只凭“看起来向右下”。

## 采样点

在同一页面、同一 zoom、同一 hover 状态下，选择：

```text
上方：Y = 200
中部：Y = 420
下方：Y = 650
```

记录每个采样点的：

```text
Δx = hover 预览 x - 实际 x
Δy = hover 预览 y - 实际 y
```

## 判断规则

### 固定平移

若所有点的 `Δx`、`Δy` 基本相同，说明是 origin、safe area、contentInset 或 contentOffset 平移错误。

### 缩放比例错误

若 `Δy` 随页面 Y 线性变化，且上方为正向下偏、下方为正向上偏，说明 hover preview 使用了不同的纵向 scale 或错误的缩放锚点。

### 以 hover 点为中心的压缩

若偏移方向在 hover 位置附近反转，说明预览层可能使用 Pencil 位置或旧中心点作为 transform anchor。

### 旋转/剪切

若 `Δx` 随 Y 或 `Δy` 随 X 变化，考虑 transform matrix 中存在 rotation 或 shear，不得使用单一 x/y 补偿。

## 公式

比较：

```text
P_actual = S × P + T
P_hover  = S' × P + T'
ΔP       = (S' - S) × P + (T' - T)
```

把测量结论映射为：平移、缩放、锚点或复合矩阵，并给出误差范围。

## 输出

输出采样表：

| 页面位置 | 实际点 | hover 点 | Δx | Δy | 解释 |
|---|---|---|---:|---:|---|

没有测量数据时，不得进入实现阶段。
