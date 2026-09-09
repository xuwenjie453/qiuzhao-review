# 新节点初始化时序诊断提示词

重点验证新推送解释节点首次进入 Reader 时，layout、zoom、Canvas 和 drawing load 是否存在竞争。

## 必须追踪的事件

按时间顺序记录：

1. graphState 收到新节点；
2. `fullScreenCover` 出现；
3. `ReaderHostView.load()` 设置 markdown；
4. `ReaderHostVC.configure()`；
5. `AnnotatedReaderView.init`；
6. `renderDocument()` 完成；
7. Canvas 加入 contentView；
8. 第一次 `layoutSubviews`；
9. `targetScale` 计算；
10. `setZoomScale` 完成；
11. 异步 drawing load 完成；
12. `loadInk()` 执行；
13. Pencil hover 开始。

## 对比实验

至少执行：

- 进入后立即 hover；
- 进入后等待 500ms 再 hover；
- 进入后等待 1s 再 hover；
- 同一节点第二次进入；
- 不加载已有 drawing 的空白节点；
- 横屏和竖屏分别进入。

## 判断

如果等待后问题消失，优先判定为初始化时序/hover 缓存刷新问题；如果等待后仍存在，优先回到矩阵审计。

不得通过简单延迟几十毫秒作为最终修复，除非能证明延迟等待的是哪个明确的 layout/transition 完成条件，并说明设备差异风险。
