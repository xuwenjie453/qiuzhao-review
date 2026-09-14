# Manual Acceptance Scenarios

用少量可观察场景验证用户层语义。

## 场景 1：第一次学习 → 第一次复习
QB B 加 E1/E2，学习完成生成 Capsule，Review A 打开。A 应显示 CENTER_A + E1/E2，且不显示 CENTER_B。

## 场景 2：动态继承
A 已建立后重新打开 B，新加 E3。再次打开 A，E3 自动出现，不需要重新建 inheritance。

## 场景 3：兄弟共享
创建 Review C 也继承 B。在 A 重命名 E1，在 C 拖动 E1，B/A/C 最终显示相同 title/layout。

## 场景 4：子图隔离
A 新增 Review-specific X1。B/C 不应出现 X1。

## 场景 5：Ink 连续性
在 B.E1 写 Ink，A.E1 应看到；A 追加后 B/C 均看到。

## 场景 6：删除影响
打开 A.E1 删除管理 UI，应明确提示全局影响。测试数据环境确认删除后 B/A/C 都移除 E1。

## 场景 7：降级
legacy capsule 无 primary source 或 parent graph missing 时，Review 仍能正常展示自己的 CENTER/owned nodes，不报致命错误、不伪造 inherited nodes。
