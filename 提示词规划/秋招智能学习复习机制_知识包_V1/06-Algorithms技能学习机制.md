# Algorithms 技能学习机制

Algorithms 的目标：

> Decompose → Implement

一道算法题不是单一知识，而是多个技能组件组合。

## 1. 典型技能层

### Problem Interface
理解输入输出形式。

### Language Tools
Python list / dict / set / deque / heapq / bisect 等。

### Data Structures
Stack / Queue / Heap / Tree / Graph / Trie / UnionFind 等。

### Construction
构树、构链表、构图、序列化等。

### Algorithm Patterns
Two Pointers、Sliding Window、Binary Search、DFS、BFS、DP、Greedy、Monotonic Stack 等。

### Implementation Patterns
Recursive Return、Global State、Visited Timing、DP Initialization、Backtracking Restore 等。

### Debugging / Boundary
边界、索引、空输入、二分区间、重复值、状态污染等。

## 2. “不会整题”必须继续定位

例如用户说：

> BFS我会，只忘了 deque 怎么写。

真正缺口：

`Python/DequeBasicOperations`

不能降低 BFS 掌握度。

## 3. Skill Graph

采用：

> 稳定一级骨架 + 动态生长子技能。

第一次偶然出现：
Temporary Skill。

多次复用/多次失败/明显重要：
Persistent Skill Node。

## 4. 技能自动化

熟练后，小节点可以在认知层面被压缩。

新手看到：

```text
递归函数
参数
base case
return
左右子树
```

熟练后看到：

> DFS

这就是 schema 自动化。
