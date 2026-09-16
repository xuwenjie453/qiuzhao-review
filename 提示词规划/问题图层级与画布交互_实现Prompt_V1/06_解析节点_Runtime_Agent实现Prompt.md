# 06 — “解析节点”Runtime Agent 行为实现 Prompt

本阶段不是增加新的底层 graph command，而是让 Runtime Agent 正确使用已经实现的 `parent_node_id` 原语。

## 1. 概念冻结

“解析节点”定义为：

> 用户明确指定一个现有 QuestionGraph 节点，并要求从该节点内容中围绕某个主题/部分进行收集、抽取、重新组织，生成一个新的自包含 `EXPLANATION` 子节点。

解析是 **Agent content transformation**，不是新的 node kind。

禁止新增：

```text
PARSED_NODE
PARSE_RESULT
node.parse
edge relation
source span schema
```

底层仍然只调用：

```text
graph.add-node
node_kind = EXPLANATION
parent_node_id = <source node id>
```

## 2. 必须解决 RuntimePrompt 21 的现有规则冲突

当前 RuntimePrompt 21 的普通 add-node 规则是：

- 只有用户明确要求解释入图才加节点；
- `body_markdown` 必须是用户指中的 assistant 原解释原文；
- 禁止整理改写。

**这条普通规则必须保留。**

新增一个明确、窄范围的例外：

> 当且仅当用户明确要求“解析 / 抽取 / 从某个现有节点中整理出某个主题作为子节点”时，Agent 可以读取该父节点正文，对相关内容进行跨段收集、压缩、重排和必要改写，形成一个新的自包含解释。此时新节点 body 不要求逐字等于父节点原文或某一条 assistant 消息。

不要把“展开讲讲”“解释一下”“总结一下”等普通对话自动当作解析入图。是否产生子节点仍要求用户表达了明确的入图/解析意图。

## 3. 解析工作流

当用户明确解析某节点时，Runtime Agent 应执行：

### Step A — 定位父节点

从当前 active QuestionGraph snapshot / graph query 中找到用户指代的 node。

优先按明确 node id；自然语言指代时可根据当前选中节点、唯一标题等上下文解析。若多个同名节点无法唯一确定，才需要最小澄清；不要猜错 parent。

### Step B — 获取父节点正文

读取 canonical/effective view 中该节点的 `body_markdown`。

若节点不存在、已删除或正文不可读取：不得伪造解析结果已入图。

### Step C — 围绕用户指定主题建立子内容

允许：

- 从父正文多个位置收集相关内容；
- 去掉与目标主题无关部分；
- 合并重复内容；
- 改写衔接语；
- 重新组织顺序；
- 压缩成独立可理解的知识单元。

要求：

- 只依据父节点实际提供的信息做“抽取/重组”；若要补充父节点之外的新知识，必须得到用户明确的“扩展/研究”意图，且应清楚区分来源；
- 不篡改父节点；
- 子节点应自包含，脱离父正文仍基本可理解；
- title 概括用户要求解析出的主题。

### Step D — 创建子节点

调用现有 `graph.add-node`：

```json
{
  "round_id": "<active round>",
  "node_kind": "EXPLANATION",
  "parent_node_id": "<source parent node id>",
  "ai_title": "<解析主题标题>",
  "body_markdown": "<重组后的自包含内容>"
}
```

每次命令使用新的 UUID `command_id`，遵守现有 daemon/CLI 接口。

### Step E — 结果反馈

只有 daemon 确认成功后才能告诉用户子节点已创建。

如果 daemon 不在线：

- 告知 iPad/问题图同步暂不可用；
- 可以正常在对话中给出解析内容；
- **不得**声称节点已加入；
- 不因同步失败阻断学习。

## 4. 默认 parent 行为

普通新增解释节点：

```text
用户没有指定 parent
→ 不传 parent_node_id
→ GraphService 默认 CENTER
```

用户说“把这个解释作为 X 的子节点”“从 X 解析出 Y”：

```text
→ 传 X.node_id
```

Agent 不需要自己把 CENTER id 填进所有普通命令，避免无谓耦合。

## 5. 典型例子

父节点：

```text
离线过程：RAG切块与元数据设计
```

用户：

> 解析这个节点，把其中关于“Chunks 有哪些实现方式”的内容抽出来。

正确：

```text
读取父 body
→ 收集 Fixed-size / Recursive / Structure-aware / Semantic / Parent-Child / Overlap 等相关内容
→ 重新组织成自包含说明
→ graph.add-node(EXPLANATION, parent_node_id=<父节点>)
```

图结构：

```text
CENTER
└── 离线过程：RAG切块与元数据设计
    └── Chunks 有哪些实现方式
```

后续若用户再说：

> 解析“Chunks 有哪些实现方式”，把 Semantic Chunking 单独抽出来。

则：

```text
CENTER
└── RAG切块与元数据设计
    └── Chunks有哪些实现方式
        └── Semantic Chunking
```

## 6. RuntimePrompt 21 最小更新要求

修改 `21_双端问题图与iPad协作协议.md` 时至少更新：

1. “何时发命令”中说明解析现有节点并生成子解释仍使用 `graph.add-node`；
2. 硬性规则中保留普通 body 原文规则，并新增“解析节点例外”；
3. CLI `add.json` 示例加入 optional `parent_node_id`；
4. 节点语义说明中指出 EXPLANATION 可拥有 CENTER/EXPLANATION parent；未指定默认 CENTER；
5. 明确 inherited node 不能成为当前 graph OWN child 的 parent（server same-graph validation）；
6. 不增加第四种节点 kind。

如 `15-自然语言控制协议.md` 对“加入解释”有明确映射，可增加：

```text
“解析/抽取这个节点的 X，作为子节点”
→ 读取父节点 → 重组内容 → graph.add-node(parent_node_id=父)
```

仅做最小增量，不重写整个自然语言协议。

## 7. 解析行为验收

至少人工检查这些 utterances：

### 不应创建节点

- “再详细解释一下 Semantic Chunking。”
- “总结一下刚才说的。”
- “这个地方是什么意思？”

除非用户同时明确表示加入/解析到问题图。

### 普通加入：原文规则

- “把你刚才这段解释加入问题图。”

→ body 必须是所指 assistant 原文；默认 parent CENTER。

### 解析加入：重组例外

- “解析这个节点，把关于 Chunking 实现方式的内容抽出来。”

→ 可跨父正文重组；parent=该节点。

### 明确指定父节点

- “把刚才的 Semantic Chunking 解释挂到‘Chunks有哪些实现方式’下面。”

→ 如果这是将刚才 assistant 原解释入图，body 仍原文，但 `parent_node_id` 指定该父节点。

这样可以证明：**内容来源规则**与**图结构 parent 规则**是两条正交维度，不要混为一谈。
