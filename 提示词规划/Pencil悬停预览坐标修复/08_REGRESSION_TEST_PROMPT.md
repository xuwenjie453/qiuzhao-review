# 回归测试提示词

为 hover 坐标问题增加纯逻辑测试，并保留现有 Store、Topology 和 Reader 测试。

## 纯逻辑测试

至少覆盖：

1. canonical 点经过显示缩放后，再逆变换能回到原点；
2. 固定平移会在所有采样点产生相同偏移；
3. 缩放比例不同会产生随页面位置变化的偏移；
4. 上方/下方相反方向偏移可以被识别为 scale/anchor 错误，而非固定补偿；
5. viewport 改变不改变 canonical 页面坐标；
6. `layoutSignature` 不因 zoom 改变；
7. `pkdrawing-v1` 字符串、ink revision 和 node_id 保持不变。

## UIKit/真机测试要求

模拟器可以验证布局和状态，但 hover 必须在真实 iPad + Apple Pencil 上验证。不得用手指事件替代 hover 测试。

## 通过标准

- 上/中/下 hover 预览偏移均不超过预先定义的像素误差；
- hover 结束后 drawing 数据哈希不变；
- 实际落笔的 stroke 坐标和修复前一致；
- 新节点首次进入和旧节点重新进入都通过；
- 横竖屏、分屏和多页文档都通过。
