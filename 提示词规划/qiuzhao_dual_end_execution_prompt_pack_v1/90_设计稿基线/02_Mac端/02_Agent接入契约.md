# Agent 接入契约

## 1. 原则

Agent 是“哪段解释被用户指中”的语义判断者；Daemon 是“是否满足显式入图命令、body 是否不可变、CENTER 是否可删”等确定性规则执行者。

Daemon 不扫描聊天记录，不猜用户意图。

## 2. CLI

建议命令：

```bash
# 查看 daemon
node DualEnd-Mac/bin/qreview-dual.mjs status

# 开始讨论问题
node DualEnd-Mac/bin/qreview-dual.mjs question open --json request.json

# 将用户明确选中的解释加入
node DualEnd-Mac/bin/qreview-dual.mjs graph add-node --json request.json

# 结束本题
node DualEnd-Mac/bin/qreview-dual.mjs question close --round <round_id>
```

CLI 内部调用 `127.0.0.1:<control_port>`；禁止 CLI 自己直写 SQLite。

## 3. question.open 输入

```json
{
  "question_ref": {
    "source": "QUESTION_BANK",
    "question_key": "qb:Redis-01-003",
    "source_id": "Redis-01-003"
  },
  "question_body_markdown": "...题干原文...",
  "ai_title": "Redis过期删除策略",
  "agent_session_ref": "optional"
}
```

Daemon 返回：`graph_id`, `round_id`, `graph_revision`。

## 4. graph.add-node 输入

```json
{
  "round_id": "...",
  "kind": "EXPLANATION",
  "ai_title": "惰性删除与定期删除",
  "body_markdown": "用户明确指定的那段 assistant 原文 Markdown",
  "origin_turn_ref": "optional"
}
```

Daemon 验证：

- round active；
- kind 只能 EXPLANATION/TEMPORARY；
- body 非空；
- title 非空；
- TEMPORARY 自动绑定 round_id；
- EXPLANATION round_id 写 NULL。

## 5. Runtime Prompt 新增规则

实现时在 Runtime Prompt 入口增加一个 `Dual-End Contract`：

1. 每次开始围绕具体问题讨论，先 `question.open`；
2. 切题前 `question.close`；
3. 用户没有明确要求时绝不 `graph.add-node`；
4. 用户明确要求时，body 使用被指定解释原文，不做二次整理；
5. title 可概括，建议 4–18 个中文字符；
6. daemon 不在线时不阻断学习主流程，只报告“iPad 同步暂不可用”，并继续学习。
