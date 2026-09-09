# 自动化回归测试提示词

保留现有 Store、Topology、GraphCodec、Reader viewport 测试，并增加不依赖实体 Pencil 的纯逻辑覆盖。

## 必须覆盖

1. canonical → display → canonical 往返误差接近 0；
2. 固定 origin 偏移在三点上为常数；
3. 缩放比例不同会产生随页面 Y 变化的误差；
4. 上方/下方方向相反可识别为 scale/anchor 错误；
5. 横屏/竖屏 viewport 改变不修改 canonical 页面坐标；
6. `layoutSignature` 不因显示缩放改变；
7. `node_id`、`ink_revision`、`pkdrawing-v1` 和 drawing 哈希不因 hover 改变；
8. 页面内整张白纸可写，页面外不可写；
9. 外层只纵向滚动，Canvas 不拥有第二套滚动/缩放状态；
10. 新节点配置与 drawing 异步装载不会造成第二次错误 viewport 提交。

## 测试命令

```bash
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj \
  -scheme QiuZhaoReader \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO test
git diff --check
```

模拟器不能验证真实 hover；不得用模拟器通过替代 Pencil Gate。
