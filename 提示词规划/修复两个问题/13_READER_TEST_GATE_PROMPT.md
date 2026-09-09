# 问题二：Reader 与 Pencil 测试 Gate 提示词

请建立自动、视觉、实体设备三类验收。

## 自动测试

至少覆盖：

- A4 page width/height 和比例；
- 正文版心左右边界；
- page-fit scale 计算；
- 文字层和 Canvas 同 bounds；
- 页面外 gutter 不属于 Canvas；
- rotation 不改变 page canonical point；
- layout signature 稳定性；
- 旧 drawing 加载和保存；
- node_id 切换不串 drawing；
- 多页 pageIndex 不混淆。

## 视觉验收

用参考 PDF 作为基准，至少对比：

- 横屏整页居中效果；
- 标题粗细、大小、顶部留白；
- 正文左右边距；
- 行距和段间距；
- 二级标题蓝色和左侧竖线；
- 页脚/页码和页面阴影；
- 页面内留白与页面外灰色背景的边界。

## 真机 Pencil Gate

在真实 iPad + Apple Pencil 上执行：

1. 页面内部正文左侧画线；
2. 页面内部正文右侧画线；
3. 页面四边和四角画线；
4. 手指滚动后画线；
5. 双指放大后画线；
6. 横竖屏切换后继续画线；
7. 退出节点再进入，确认笔迹位置不变；
8. 切换另一节点，确认笔迹不串。

## PASS 条件

- 页面内部所有区域均可写；
- 笔迹相对笔尖误差不超过 2pt；
- 滚动/缩放/旋转无漂移；
- 旧笔迹完整恢复；
- 页面外灰色背景不被写入。

