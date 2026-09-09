# Hover 预览与正式笔迹区分提示词

在任何实现前，必须证明偏移属于临时 hover preview。

## 三段式验证

对一个已有笔迹的节点执行：

1. Pencil 尚未接触屏幕时悬停，截取偏移状态；
2. Pencil 接触屏幕并画短线，记录新笔迹落点；
3. Pencil 移出页面后，再截取页面状态并重新进入节点。

确认：

- 悬停时偏移的是临时预览或 hover 视觉层；
- 接触屏幕后新 stroke 的 canonical 位置正确；
- 移开后旧 drawing 和新 drawing 均恢复/保持正确；
- 数据库 blob 和 revision 没有被 hover 事件修改。

## 不能混淆的情况

如果移开后仍然偏移，或重新进入节点后偏移仍存在，则不是纯 hover 问题，必须转入正式触点坐标诊断，暂停本提示词包的默认修复。

## 记录内容

记录以下时间线：

```text
Reader configure 时间
首次 layout 完成时间
targetScale 设置时间
drawing 加载完成时间
开始 hover 时间
开始 touch 时间
stroke committed 时间
hover 离开时间
```

记录每个阶段 `zoomScale`、`contentOffset`、Canvas frame/bounds 和页面方向。

## 诊断结论格式

输出：

```text
偏移层：hover preview / committed drawing / 未确定
偏移是否持久化：是 / 否
落笔是否正确：是 / 否
离开 hover 是否恢复：是 / 否
证据：截图、日志、数据对比
```
