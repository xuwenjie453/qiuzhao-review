# 代码复核与交付提示词

交付前逐项复核：

- 是否证明问题只存在于 hover preview？
- 是否保留了实际落笔路径？
- 是否通过三个以上位置的偏移测量？
- 是否解释了上方下方相反方向偏移对应的 scale/anchor 误差？
- 是否只保留一套 canonical → screen 变换？
- 是否避免嵌套 UIScrollView 的重复缩放影响 hover？
- 是否在稳定 layout 后处理 Canvas，而非依赖魔法延时？
- 是否没有修改 PKDrawing 点坐标？
- 是否没有改变 `pkdrawing-v1`、node_id、ink_revision 和数据库 schema？
- 是否保留横屏宽度适配、纵向滚动和页面内留白书写？

## 验证命令

```bash
git diff --check
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj \
  -scheme QiuZhaoReader \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO test

xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj \
  -scheme QiuZhaoReader \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## 交付报告

必须包含：

1. 根因证据和偏移数学特征；
2. 修改文件及职责；
3. 视口/Canvas 矩阵修复说明；
4. 初始化时序修复说明；
5. 自动化测试结果；
6. 真机 Apple Pencil hover 结果；
7. 历史笔迹兼容性结果；
8. 已知 warning、未覆盖设备和剩余风险。

如果 hover 仍有偏移，只能报告“未完成”，不得用“实际落笔正确”替代 hover 验收。
