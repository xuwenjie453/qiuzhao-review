# 问题一：单击、双击、拖动手势实现提示词

请重构节点交互，使手势在 iPadOS 上具有确定的优先级。

## 手势语义

```text
单击节点：选中并打开节点信息
双击节点：进入 Reader，不同时打开单击面板
拖动节点：只移动节点，不触发单击
点击空白：清除焦点
CENTER：可点、可双击，不可拖动
```

## 手势坐标

- 使用命名坐标空间 `graph-canvas`；
- DragGesture 必须读取本地 `value.location`；
- 不使用“当前渲染位置 + 累计 translation”；
- 拖动开始时记录 `grabOffset = nodeCenter - startLocation`；
- 当前帧位置为 `currentLocation + grabOffset`，再反归一化；
- 拖动期间位置更新不能使用 spring animation；
- 只允许 scale/shadow/描边使用轻量动画。

## 手势组合

不要简单堆叠 `.gesture`、`.highPriorityGesture`、`.onTapGesture`。使用明确的 exclusive/simultaneous 组合，确保 double tap 不触发单 tap，drag 超过阈值后 tap 失败。

背景点击不能放置一个会覆盖节点命中区域的全屏透明 View。若使用父级 `SpatialTapGesture`，必须根据触点和节点 hit rect 判断：触点落在节点内则不清除，只有落在空白才清除。

## 验收

从每个节点的左、中心、右三处拖动；快速拖动、慢速拖动、斜向拖动各一次。记录节点中心与 Pencil/手指触点误差。目标是无累计漂移、无方向性偏移、无松手跳回。

