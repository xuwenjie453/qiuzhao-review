# 代码复核与交付提示词

宣布完成前逐项复核：

- 只有外层 UIScrollView 负责滚动；
- Canvas 关闭自己的滚动和缩放；
- 使用 Reader 实际 bounds，而不是 UIScreen.bounds；
- 按宽度适配，而非按宽高最小值整页适配；
- 首次进入只初始化一次顶部位置；
- 后续 layout 保留纵向 offset；
- 横向 inset、offset 和 bounce 均已处理；
- 旋转时按 canonical Y 换算并恢复；
- 没有修改 PKDrawing 数据和 pkdrawing-v1；
- 页内整页可写、页外不可写；
- 没有引入与本功能无关的数据库或学习系统改动。

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

## 交付报告必须包含

1. 修改文件及每个文件的职责；
2. 宽度适配公式和横向锁定策略；
3. 首次顶部显示和旋转位置保持策略；
4. Pencil 坐标兼容性说明；
5. 自动化测试数量和结果；
6. 真机安装/启动结果；
7. 已知 warning 或未覆盖风险；
8. 用户下一步需要执行的真机验收步骤。

如果任一强制验收项未完成，只能报告“部分完成”，不得报告“已修复”。
