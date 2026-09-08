# 长任务实施状态协议

在仓库根创建或更新 `双端更新实施状态.md`，用于长任务跨上下文恢复。不要把它当设计真源。

建议结构：

```markdown
# 双端更新实施状态
## 当前阶段
Phase X / Task Y

## 已完成
- ...

## 正在做
- ...

## 测试证据
- `command` → PASS/FAIL

## 阻塞
- ...

## 未决但不阻塞
- 参考 PDF typography calibration

## 已确认的不变量
- center immutable...
```

每个 Phase 完成后更新一次。

如果 Agent 上下文被截断，新 Agent 先读：
1. 本提示词包入口；
2. 设计 brief；
3. `双端更新实施状态.md`；
4. 当前 diff；
然后继续，不从头推翻实现。
