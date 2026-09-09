# 自动化测试提示词

为本功能补充可重复的纯逻辑测试和 Reader 测试。几何与状态优先，依赖真实设备的内容单独标记。

## 必须覆盖

### 宽度适配

- 多个 viewport 宽度下，scaled page width 与 viewport width 误差不超过 0.5pt；
- canonical page width 始终为 595.92；
- targetScale 被限制在合法范围内。

### 初始位置

- 首次初始化后 x=0、y=0；
- 后续普通 layout 不把用户当前 y 重置为 0；
- 第二个节点进入 Reader 会重新从顶部开始。

### 横向锁定

- 非零 x offset 被修正为 0；
- 修正 x 时 y 保持不变；
- horizontal bounce 配置关闭。

### 旋转位置保持

- oldScale 与 newScale 不同时 canonicalTopY 保持；
- 恢复后的 y 被正确裁剪；
- 横向位置始终为零。

### Pencil 坐标

- `allowedPageRects` 覆盖整张页面；
- 页面外点不命中 Canvas；
- canonical 坐标在显示缩放前后保持不变；
- layoutSignature 不因 viewport 改变。

## 执行命令

```bash
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj \
  -scheme QiuZhaoReader \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO test
```

失败时保留完整错误、失败测试名和修复假设，不得通过放宽断言掩盖偏移。
