# Phase H — Release Prompt

本阶段不再增加功能，只验证系统是否达到可合并/发布状态。

## 先决条件

- Phase A-G 全部完成；
- 没有未解释的 failing test；
- migration 已用 existing v1 fixture 验证；
- Review integration 已通过业务 E2E；
- release branch/diff 中没有与 inheritance 无关的大规模重构。

## 任务

1. 跑完整 Mac、Wire、iPad、Learning 测试。
2. 运行 DB integrity/FK/migration restart 检查。
3. 审查 RuntimePrompt 与代码契约一致。
4. 更新双端 Release 验收清单，新增 inheritance section。
5. 有真机则执行共享 title/layout/Ink 一轮；无真机明确 NOT_RUN。
6. 生成最终 change/risk/test report。

任何 Gate 不满足则不得把状态写成“全部完成”。
