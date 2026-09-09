# Pencil 悬停预览坐标修复提示词包

## 问题定义

当前 iPad Reader 中，Apple Pencil 仅在悬停预览阶段出现坐标偏移：悬停时上方笔迹向右下、下方笔迹向右上；真正接触屏幕后落笔位置正确；Pencil 离开后页面恢复正常。

这说明优先怀疑 PencilKit 临时 hover preview 与外层 UIScrollView 缩放矩阵不同步，而不是 `PKDrawing` 数据损坏。

## 目标

- hover 预览点与 Pencil 笔尖重合；
- 上下不同位置不再出现相反方向的偏移；
- 实际落笔位置保持现状，不被修复破坏；
- hover 离开后 committed drawing 不发生任何变化；
- 横屏宽度适配、纵向滚动、A4 canonical 坐标和历史笔迹继续兼容；
- 不改变 `pkdrawing-v1`、node_id、ink_revision 或数据库 schema。

## 执行顺序

1. `01_MASTER_EXECUTION_PROMPT.md`
2. `02_SCOPE_AND_SAFETY_PROMPT.md`
3. `03_HOVER_VS_COMMITTED_DIAGNOSTIC_PROMPT.md`
4. `04_AFFINE_OFFSET_MEASUREMENT_PROMPT.md`
5. `05_VIEWPORT_MATRIX_AUDIT_PROMPT.md`
6. `06_INITIALIZATION_TIMING_PROMPT.md`
7. `07_FIX_IMPLEMENTATION_PROMPT.md`
8. `08_REGRESSION_TEST_PROMPT.md`
9. `09_REAL_DEVICE_PENCIL_QA_PROMPT.md`
10. `10_REVIEW_AND_DELIVERY_PROMPT.md`

## 绝对规则

- 先证明偏移发生在 hover preview，再修改代码。
- 不通过修改 PKDrawing 点坐标“修复”预览问题。
- 不为规避问题禁用 Apple Pencil 书写。
- 不把页面截图或 PDF 图片替代 PKCanvasView。
- 不修改学习系统、Mac canonical 协议或正式题库。
- 没有真机验证时，不得宣称 hover 坐标问题已修复。
