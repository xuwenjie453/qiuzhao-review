# Capsule Schema & Compiler Prompt

修改三引擎 review_capsules schema 与 `probe_compiler.py`。

## Schema

为 Knowledge/Algorithms/Projects 共用 capsule 形态加入：

```text
primary_source_question_id TEXT NULL
```

它是 inheritance anchor，不替代 `source_questions`。

## Compiler API

让 `compile_capsule(...)` 可以显式接收 `primary_source_question_id`。

规则：
- 从一次明确正式题学习/Repair 生成 capsule 时调用方传入该 question_id；
- 多来源证据仍写 `source_questions`；
- primary source 不从数组顺序推断；
- 如果调用上下文无法证明 primary source，写 NULL。

## Migration

已有 capsule row 升级后 primary source 默认 NULL。不要回填猜测。

## 测试

- 新 capsule 正确持久化 primary source；
- source_questions 多元素时 primary source 可与第一个不同；
- legacy capsule NULL 保持可读取/可复习；
- 不改变 scheduler capsule_id identity。
