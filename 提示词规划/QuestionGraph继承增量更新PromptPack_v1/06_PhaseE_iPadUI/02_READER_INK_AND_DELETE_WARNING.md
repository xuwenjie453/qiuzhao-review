# Reader / Ink / Shared Delete Prompt

## Reader

Inherited node 双击后继续：

```text
ReaderRoute(node_id)
```

Reader 不应关心当前 node 是 OWN 还是 INHERITED 才能读取 body/Ink。它读取的是 canonical node identity。

## Ink

- Pencil drawing 仍绑定 `node_id`；
- 在 parent B 给 E1 写字，再从 child A 打开 E1 必须看到同一 drawing；
- 在 child A 继续写，回 parent B 必须看到合并后的 canonical drawing；
- Ink revision 继续单独处理，不触发 graph_revision。

## Delete warning

OWN Explanation：沿用普通删除确认。

INHERITED Explanation：必须显示语义明确的警告，例如：

> 这是共享解释节点。删除会同时影响原题图以及所有继承该解释的问题图。

只有用户明确确认后才 queue delete command。

V1 禁止实现“仅从当前复习图隐藏”按钮，因为设计没有 exclusion override/tombstone 语义。
