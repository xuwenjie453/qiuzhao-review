# Phase 2B：全链路冒烟测试（“进不去节点”回归闸门）

「暂存」版回归（双击节点进不去/Reader 不可用）没有任何测试拦截。本阶段建立**全链路 instantiate + layout + 交互模拟**的 hosted 冒烟，无论回归的具体根因是哪一行，这里先炸。

## 测试环境

- 优先在现有 `QiuZhaoReaderTests` 内直接实例化 UIKit 视图（主线程、`layoutIfNeeded` 驱动），无需窗口。
- 若 PKCanvasView/视图链需要宿主 App，则把现有 test target 配置为以 QiuZhaoReader.app 为 TEST_HOST（pbxproj 最小改动，03 号白名单允许）。

## 必须覆盖（每项都是独立 test case）

1. **入口不崩**：完整走 SwiftUI 等价链路——`ReaderHostVC()` → `configure(nodeId:markdown:drawing:)`（含 nil drawing 与非 nil drawing 两路）→ 强制 layout → 不抛异常不崩溃。
2. **视口不变量**：设置 vc.view 尺寸（横屏 1191×834 档）→ `layoutIfNeeded` 后断言：
   - `canvas.zoomScale` == `fitWidthScale(viewportWidth: canvas.bounds.width, pageWidth: 595.92)`；
   - `canvas.contentSize` == `displayContentSize(documentSize:scale:z)`（display 单位，06 #1 的直接断言）；
   - 纵向滚动范围 `contentSize.height − bounds.height > 0`（多页文档可滚）；
   - `contentView.bounds.size == documentSize`；镜像层 transform 的 a/d 分量 == z。
3. **滚动镜像**：`canvas.setContentOffset(中部)` → 断言镜像层 `position == −offset`；无异常。
4. **旋转重应用**：改 view 尺寸（竖屏档）→ layout → 断言 z 更新、canonicalTopY 保持（位置保持语义）、镜像同步。
5. **drawing 异步装载**：装载含远端笔迹的 PKDrawing 后（模拟 `loadDrawing` 路径），断言 zoom/offset 未被 loadInk 改变（几何零副作用）。
6. **Pencil 接线**：`updateUIViewController` 等价调用后，Coordinator 的 `attachedCanvas` == 当前 canvas；同一 canvas 不重复挂 interaction。
7. **多页**：超长 markdown → `pageViews.count ≥ 2`，pageRects 覆盖间隙，文档高度正确。

## 通过标准

全部 PASS + 既有测试不回归（07 号命令一并跑绿）。这是**装机前置闸门**：本阶段不绿，禁止 Phase 3。
