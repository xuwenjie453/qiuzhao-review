# Master Prompt：实现 iPad 阅读器横屏宽度适配

你负责本仓库 iPad Reader 的受限功能更新：进入节点后，页面按当前阅读区域宽度自动铺满，并锁定为只能上下滚动。

## 任务目标

1. 双击节点进入 Reader 后无需手动双指放大。
2. A4 页面宽度自动适配当前 iPad 窗口宽度。
3. 初次进入显示第一页最顶部。
4. 页面不可缩放、不可左右拖动、不可左右回弹。
5. 手指只负责上下滚动，Apple Pencil 负责书写。
6. 页面正文和左右留白均可书写，页面外 gutter 不接受笔迹。
7. 横竖屏或分屏变化时重新计算显示比例并尽量保持阅读位置。

## 执行顺序

1. 读取并遵守 `AGENTS.md`。
2. 阅读器相关 RuntimePrompt 和本目录其他阶段提示词。
3. 记录 git 状态、当前 commit、Xcode scheme、物理设备信息和测试基线。
4. 检查 `ReaderHostView`、`ReaderHostVC`、`AnnotatedReaderView`、`ReaderTypography` 和 PencilKit 保存链路。
5. 写出当前坐标树和 UIScrollView 所有者关系。
6. 只修改阅读器视口层，不重做学习系统或同步协议。
7. 实现宽度适配。
8. 实现横向锁定和纵向滚动约束。
9. 实现旋转/分屏状态迁移。
10. 验证 Pencil 坐标和历史笔迹。
11. 执行自动化测试、真机测试和 `git diff --check`。
12. 输出改动文件、验证结果、警告、未验证项目和真机测试步骤。

## 技术约束

- canonical A4 页面坐标保持 `595.92 × 842.88`。
- 正文排版参数和 `layoutSignature` 不因显示缩放改变。
- 不直接修改 `PKDrawing` 的点坐标。
- 不给页面、正文、Canvas 分别使用不同缩放比例。
- `PageCanvasView` 仍覆盖 canonical 文档区域并拒绝页面外写入。
- 不删除或迁移已有笔迹数据库记录。
- 不使用 `UIScreen.main.bounds` 代替 Reader 实际可见区域。
- 不在每次 `layoutSubviews` 中无条件重置纵向滚动位置。

## 停止条件

若需要修改 Mac 协议、数据库 schema、旧笔迹格式，或签名/真机不可用，立即停止并报告，不要自行扩大范围。
