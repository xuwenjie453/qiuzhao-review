# Hover 与正式笔迹区分提示词

必须先证明偏移是临时 preview，而不是 `PKDrawing` 或触点坐标损坏。

## 三段式测试

对同一节点、同一方向、同一缩放执行：

1. Pencil 不接触屏幕，在页面上方/中部/下方 hover，截图记录预览位置；
2. 接触屏幕画一条短线，记录实际 stroke 起点和页面文字的相对位置；
3. 移开 Pencil、退出 Reader、重新进入，确认 drawing 和页面关系。

## 必须记录

```text
hover 开始/更新/结束时间
touch began/ended 时间
canvasViewDrawingDidChange 时间
PKDrawing revision 与 SHA-256
```

结论必须采用以下格式：

```text
偏移层：hover preview / committed drawing / 两者 / 未确定
落笔是否正确：是 / 否
移开是否恢复：是 / 否
hover 是否改变 drawing：是 / 否
证据：截图、日志、数据哈希
```

如果移开后仍偏移或重进后笔迹改变，暂停本包的 hover-only 修复，转入正式触点坐标诊断。
