# 基线侦察与真机几何采集提示词

在任何实现前，完成以下调查并形成一份 `tmp/dual-end-fix-baseline.md`（如仓库已有状态文件，追加而不是覆盖）。

## 代码调查

检查并记录：

- `QuestionGraphView` 的父容器、GeometryReader 尺寸、safe area、NavigationStack 结构；
- 节点 glyph、frame、overlay、contentShape、position/offset、scale、shadow；
- 单击、双击、拖动、背景点击的手势优先级和 gesture mask；
- `dragTransient`、snapshot layout、outbox、layout revision 的写入和清除顺序；
- Reader 的 UIScrollView、contentView、markdownView、PKCanvasView 约束；
- `contentInset/contentOffset/zoomScale/contentSize` 的实际值；
- ink 的格式、版本、node_id 绑定和 ACK/reject 处理；
- 现有测试覆盖范围。

## 运行时采集

在开发模式增加或临时启用日志，至少采集：

```text
viewport frame
graph content frame
safeAreaInsets
node canonical normalized point
node effective screen point
node visual frame
node hit frame
gesture start location
gesture current location
gesture coordinate space
dragging/pending/canonical state
layout revision / command id
Reader page frame
text frame
canvas frame
outer contentInset/contentOffset
canvas contentInset/contentOffset/zoomScale
```

必须在 iPad Air 11-inch 横屏和竖屏各采集一次；至少覆盖 CENTER 和 TEMPORARY 两个节点。

## 基线操作

按以下顺序执行并录像或截图：

1. 点击中心节点；
2. 点击临时节点；
3. 点击空白；
4. 从节点左侧、中心、右侧各拖动一次；
5. 双击节点；
6. 横竖屏旋转；
7. Reader 内在正文和左右留白各画一笔；
8. 滚动后重复书写；
9. 断网拖动后恢复网络。

不要根据主观“看起来偏了”直接修复。先用采集数据判断偏移是平移、比例、命中区域、状态回滚还是网络回放。

