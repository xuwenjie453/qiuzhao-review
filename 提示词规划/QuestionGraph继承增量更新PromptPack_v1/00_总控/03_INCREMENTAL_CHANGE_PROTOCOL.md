# Incremental Change Protocol

你必须以“小步可验证”方式更新仓库。

## 每个 Phase 开始

先声明：
- 本阶段目标；
- 将触碰的文件；
- 明确不触碰的相邻模块；
- 进入阶段前必须为绿的测试。

## 每个 Phase 中

优先顺序：

```text
Contract/Test expectation
→ minimal implementation
→ targeted tests
→ full local regression for affected subsystem
→ commit checkpoint
```

避免：
- 横跨 10+ 文件后才第一次运行测试；
- 为了让新测试绿而删除旧断言；
- 通过 broad catch/ignore 吞掉 migration、CAS、revision 错误；
- 改动与 inheritance 无关的 UI/命名/格式；
- 用临时数据库重建代替真实 migration；
- 用全量 snapshot 掩盖所有错误而不维护 graph_revision 语义。

## Checkpoint 要求

建议至少形成以下可回退 checkpoint：

- CP0 baseline evidence
- CP1 schema migration + relation tests
- CP2 effective view + mutation fan-out
- CP3 wire/fixtures
- CP4 iPad cache normalization
- CP5 UI shared interaction
- CP6 Review integration
- CP7 complete test gate

每个 checkpoint 都应能说明：如果下一阶段失败，回退到这里后系统仍是什么状态。
