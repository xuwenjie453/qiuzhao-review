# 阅读器横屏宽度适配提示词包

## 目标

指导 AI 在不破坏现有双端同步、A4 canonical 文档坐标和 PencilKit 笔迹兼容性的前提下完成：自动按 iPad 阅读区域宽度放大、首次显示页面顶部、固定缩放、禁止左右移动、只允许上下滚动，以及页内留白书写。

## 推荐执行顺序

1. `01_MASTER_EXECUTION_PROMPT.md`
2. `02_SCOPE_AND_SAFETY_PROMPT.md`
3. `03_BASELINE_RECON_PROMPT.md`
4. `04_WIDTH_FIT_IMPLEMENTATION_PROMPT.md`
5. `05_VERTICAL_SCROLL_LOCK_PROMPT.md`
6. `06_ROTATION_AND_VIEWPORT_STATE_PROMPT.md`
7. `07_PENCIL_COORDINATE_PROMPT.md`
8. `08_AUTOMATED_TEST_PROMPT.md`
9. `09_REAL_DEVICE_QA_PROMPT.md`
10. `10_CODE_REVIEW_AND_DELIVERY_PROMPT.md`

## 使用规则

- 每次只执行一个阶段，完成并记录结果后再进入下一个阶段。
- 必须先读取仓库 `AGENTS.md` 和相关 RuntimePrompt。
- 任何代码修改前记录 git 状态、当前 commit、设备和测试基线。
- 不修改 `scheduler.sqlite3`、`questions.sqlite3`、学习调度规则或 Mac canonical 数据模型。
- 不修改 `pkdrawing-v1` 数据格式，不批量重写历史笔迹。
- 签名、真机连接或 daemon 缺失时，停止并报告具体阻塞点。

## 统一完成标准

1. 横屏页面宽度适配可见阅读区域。
2. 首次进入页面顶部为 `contentOffset.y = 0`。
3. 缩放比例固定，捏合无效。
4. `contentOffset.x` 始终为 0，不发生横向回弹。
5. 只允许纵向滚动。
6. 页内左右留白可写，页面外不可写。
7. Pencil 悬停和落笔不偏移。
8. 横竖屏切换后笔迹仍与正文对齐。
9. 自动化测试和真机验收均通过。
