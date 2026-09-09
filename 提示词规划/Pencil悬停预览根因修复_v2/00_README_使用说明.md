# Pencil 悬停预览根因修复提示词包 v2

## 适用问题

本提示词包用于修复 iPad Reader 中 Apple Pencil 的 hover 预览偏移：

- Pencil 尚未接触屏幕时，预览位置偏离笔尖；
- 页面上方通常向右下偏移，页面下方通常向右上偏移；
- 真正落笔后，stroke 位于正确位置；
- Pencil 移开后，临时预览消失，页面恢复；
- 新推送的解释节点首次进入时更容易出现。

## 已知根因假设

当前 Reader 将 `PKCanvasView` 放在被外层 `UIScrollView` zoom 的 `contentView` 中。`PKCanvasView` 本身也是 `UIScrollView`，而 PencilKit 的 hover 预览是独立的临时渲染路径。外层 zoom、Canvas 内部 geometry 和首次 layout/drawing load 没有形成一个稳定且唯一的矩阵，因此 hover 使用的比例或锚点可能与实际触点不同。

观察到的“上方/下方方向相反”不是固定平移，而是缩放比例或缩放锚点误差；横向持续偏移则可能叠加了 origin、contentOffset 或 presentation transform 差异。

## 执行顺序

1. `01_MASTER_EXECUTION_PROMPT.md`
2. `02_SCOPE_AND_SAFETY_PROMPT.md`
3. `03_SYSTEM_BASELINE_PROMPT.md`
4. `04_HOVER_COMMITTED_DIAGNOSTIC_PROMPT.md`
5. `05_AFFINE_MEASUREMENT_PROMPT.md`
6. `06_VIEW_HIERARCHY_MATRIX_AUDIT_PROMPT.md`
7. `07_AB_EXPERIMENT_PROMPT.md`
8. `08_INITIALIZATION_TIMING_PROMPT.md`
9. `09_ARCHITECTURE_REPAIR_PROMPT.md`
10. `10_PENCILKIT_LIFECYCLE_PROMPT.md`
11. `11_REGRESSION_TEST_PROMPT.md`
12. `12_REAL_DEVICE_QA_PROMPT.md`
13. `13_REVIEW_AND_DELIVERY_PROMPT.md`

## 绝对约束

- 不修改学习系统、scheduler、正式题库、Mac canonical schema 或 WebSocket 协议。
- 不修改 `PKDrawing` stroke 点坐标，不迁移历史笔迹。
- 不通过固定 `+dx/+dy`、按页面区域分段补偿或魔法延迟“修复”。
- 不以禁用 Apple Pencil 书写或禁用 hover 作为默认方案。
- 没有实体 iPad + Apple Pencil 验证时，不得宣称 hover 已修复。
- 如果证据证明当前外层 zoom 架构与 hover 不兼容，应改为单一显示变换，而不是继续叠加同步代码。
