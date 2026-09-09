# 最小修复实现提示词

只有完成 hover/committed 区分、偏移测量、矩阵审计和初始化时序诊断后，才能执行本阶段。

## 修复选择原则

按证据选择最小方案：

1. 若是布局未完成：在稳定布局完成后统一设置外层视口，再允许 hover 预览，避免重复重置 Canvas。
2. 若是 Canvas 内部 geometry 残留：清理 Canvas 的 contentInset、contentOffset、zoomScale 和内部滚动配置，但不改变 drawing 坐标。
3. 若是外层和 Canvas 使用两套缩放：保留单一显示矩阵，消除重复缩放或手工补偿。
4. 若是 origin/contentOffset 重复计算：只保留一个 canonical → screen 变换路径。
5. 若是 presentation layer 时序问题：使用布局完成后的稳定状态同步，而不是固定魔法延时。

## 禁止的伪修复

- 不添加固定的 `+dx/+dy` 补偿；
- 不根据 hover 位置修改 PKDrawing；
- 不把上方和下方分别用不同补偿值；
- 不禁用 Apple Pencil 书写；
- 不禁用 hover 作为默认方案；
- 不把 Canvas 从页面中移走却不提供可证明的坐标变换；
- 不修改 A4 canonical 页面尺寸或正文排版。

## 实现后必须检查

- 实际落笔位置仍正确；
- hover preview 与笔尖重合；
- hover 离开后 drawing 无变化；
- 上、中、下采样点偏移均在可接受误差内；
- 横屏宽度适配和纵向滚动没有回归；
- 历史 PKDrawing 无偏移。

每一处修改都要说明：修复了哪个已证实的矩阵/时序问题，为什么不会影响正式 drawing 坐标。
