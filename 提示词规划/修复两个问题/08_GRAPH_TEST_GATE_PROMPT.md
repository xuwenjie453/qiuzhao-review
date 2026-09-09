# 问题一：问题图测试与验收 Gate 提示词

请为问题图修复建立自动测试、真机手工测试和失败证据。

## 自动测试

至少覆盖：

- normalized ↔ local round-trip；
- 不同 viewport、safe area、横竖屏尺寸；
- hit rect center 与 visual center；
- 拖动起点偏移保持；
- 多帧 drag 不累计；
- CENTER 不产生 MOVE_NODE；
- pending/canonical/dragging 显示优先级；
- ACK、重复 ACK、CAS_MISMATCH、重试；
- 旧 command 不覆盖新 command；
- 空白点击不吞掉节点点击。

## 实体 iPad 验收

在真实 iPad 上验证：

1. 点击所有节点的视觉中心和边缘；
2. 从节点四个方向拖动；
3. 单击、双击、拖动连续交替；
4. 横竖屏切换后重复操作；
5. 断网拖动、杀进程、重启 App、恢复连接；
6. Mac 同时变更另一个节点。

## PASS 条件

- 节点中心、命中中心和拖动中心误差不超过 2pt；
- 60Hz 拖动过程中不存在明显滞后或累计漂移；
- 松手后不回到旧位置；
- 任何同步拒绝都有可解释结果；
- 现有协议、Store、拓扑测试全部通过。

