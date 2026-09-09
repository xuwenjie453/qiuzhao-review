# Master Prompt：修复 Pencil hover 预览坐标偏移

你负责 iPad Reader 中 Apple Pencil hover 预览坐标错误的诊断和修复。已知现象是：仅悬停时预览偏向右下/右上，实际落笔正确，Pencil 离开后恢复正常。

## 目标体验

1. Pencil 悬停预览与笔尖位置重合。
2. 页面上方、中部、下方的预览不再出现方向相反的偏移。
3. 实际落笔仍位于正确位置。
4. hover 结束后 `PKDrawing` 不被改变。
5. 横屏宽度适配、只纵向滚动和页面内留白书写继续有效。

## 必须按顺序执行

1. 阅读 `AGENTS.md`、本目录所有阶段提示词和 Reader 相关 RuntimePrompt。
2. 记录 git 状态、当前 commit、设备连接、iPadOS 版本和测试基线。
3. 阅读 `AnnotatedReaderView`、`ReaderHostView`、`ReaderTypography`、`PencilToolController` 及已有测试。
4. 先在真机确认“preview 偏移、落笔正确、离开恢复”的三段式现象。
5. 测量上/中/下三个位置的偏移，判断是平移、缩放、锚点还是时序问题。
6. 审计外层 UIScrollView、contentView、PageCanvasView 的 frame/bounds/transform/contentOffset/zoomScale。
7. 检查新节点首次 configure、首次 layout 和异步 drawing load 的时序。
8. 只选择有证据支持的最小修复方案。
9. 添加不依赖真机的数学/状态回归测试。
10. 在真实 iPad 上验证 hover、落笔、旋转、重新进入和历史笔迹。
11. 输出根因证据、改动文件、测试结果、warning 和未覆盖风险。

## 强制约束

- A4 canonical 坐标保持 `595.92 × 842.88`。
- 不修改 `PKDrawing` 的 stroke 点坐标。
- 不修改 `pkdrawing-v1`、node_id、ink_revision、blob 或数据库 schema。
- 不使用 `UIScreen.main.bounds` 作为 Reader 几何来源。
- 不添加第二套手工屏幕到 Canvas 坐标换算，除非先证明系统路径无法正确工作并记录替代方案。
- 不以禁用 Pencil hover 或禁用 Pencil 书写作为默认修复。
- 不动学习调度、Mac canonical 图或正式题库。

## 停止条件

若无法区分 preview 和 committed drawing、设备未连接、签名不可用、测试失败原因不明，停止并报告，不要猜测修改。
