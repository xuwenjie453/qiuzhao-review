# 知识块生成与 Repair

## 1. Knowledge Need Graph

收到问题后，系统先分析：

- Domain
- Target Concept
- 当前回答需要哪些维度
- 必要前置
- 容易混淆概念
- 一层自然追问

然后结合历史状态：

> 删除已经稳定掌握的前置。

## 2. 资料召回

不是直接 Top-K chunks 全部展示。

流程：

```text
问题
→ Atomic Retrieval
→ Parent Expansion
→ Sibling Retrieval
→ 去除无关内容
→ AI补资料缺口
→ 形成知识块
```

## 3. 验证题

知识块关闭后：

1. 重答原题；
2. 再用 2～4 个不同认知角度动态验证。

优先真人题。

如果真人题不够：

> AI可临时生成诊断题。

临时题不进正式题库。

## 4. Repair Loop

验证失败：

```text
定位失败节点
↓
缺口是否仍在当前结构内部？
├── 是 → Repair Block
└── 否 → 扩大 G 级别
```

## 5. Repair 不能简单重复原材料

优先换表示形式：

- 比较；
- 表格；
- ASCII；
- 示例；
- 反例；
- 场景。

## 6. 完成后不刷到过度熟练

完成当前结构：

> 只做短巩固，随后切换领域。

长期强化交给未来不同日期的 Review。
