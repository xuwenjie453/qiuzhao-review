# 代码复核与交付提示词

交付前逐项回答：

## 根因证据

- 是否完成 hover/committed 区分？
- 是否完成上/中/下三点偏移测量？
- 是否完成 outer zoom、Canvas geometry、初始化时序 A/B？
- 是否解释了纵向方向反转对应的比例/锚点误差？

## 架构检查

- Reader 是否只剩一个显示变换来源？
- 是否消除了 `PKCanvasView` 与父级 UIScrollView 的重复 viewport 影响？
- Canvas、文字、页面是否同一 canonical 原点和 frame？
- 是否没有把屏幕坐标写入 drawing 或协议？

## 数据兼容

- `PKDrawing` 点坐标是否未改？
- `node_id`、`ink_revision`、`blob_sha256`、`pkdrawing-v1` 是否保持兼容？
- hover 是否不会产生 outbox/ink revision？

## 验证报告

必须包含：

1. 修改文件和每处改动目的；
2. 关键矩阵修复前后对照；
3. 自动化测试结果；
4. 真机 hover 三点结果；
5. 正式落笔、旋转、滚动、历史笔迹结果；
6. 未覆盖设备、系统版本和剩余风险。

如果没有实体 Pencil 或 hover 仍偏移，最终状态必须写“未完成/待真机验证”，不得写 PASS。
