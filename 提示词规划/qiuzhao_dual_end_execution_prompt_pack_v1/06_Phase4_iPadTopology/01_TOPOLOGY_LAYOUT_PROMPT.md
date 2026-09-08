# Topology 画布与确定性布局

## 任务目标
实现 CENTER 居中、子节点 radial slot 和 USER_PINNED。

## 必读设计稿
- `90_设计稿基线/04_iPad端/02_问题图Topology设计.md`

## 必须满足
- CENTER square / EXPLANATION circle / TEMPORARY triangle。
- 标题在节点上方最多2行。
- 子节点可低强调线连中心。
- 坐标存 0..1。

## 实施步骤
1. 实现 layout reducer。
2. 首次节点 golden-angle slot。
3. 旋转/尺寸变化从 normalized position 重算像素。
4. pinned node 不自动重排。

## 测试要求
- shape snapshot/UI tests
- deterministic positions
- persist/relaunch positions

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
