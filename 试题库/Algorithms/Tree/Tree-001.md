### Tree-001-001 | ★★★★☆

**题目：** 数组中的第 K 个最大元素

给定数组，求第 k 大的元素（重复元素按位置计，即排序后第 n-k+1 位）。

**输入格式**

第一行 n, k（1 ≤ k ≤ n ≤ 1e5）。
第二行 n 个整数 ai（|ai| ≤ 1e9）。

**输出格式**

一个整数。

**示例输入**

```
6 2
3 2 1 5 6 4
```

**示例输出**

```
5
```

**答案（Python 3）：**

```python
import sys
import heapq

def solve():
    data = sys.stdin.read().split()
    n, k = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    heap = []
    for x in a:
        heapq.heappush(heap, x)
        if len(heap) > k:
            heapq.heappop(heap)
    print(heap[0])

if __name__ == "__main__":
    solve()
```

**解析：**
小顶堆维护 k 个最大值：遍历数组，堆大小超过 k 弹出堆顶，最后堆顶即第 k 大，O(n log k)；n 全量排序 O(n log n) 也可过但不是考点。进阶：快速选择 O(n) 平均。


### Tree-001-002 | ★★★★☆

**题目：** 合并 K 个有序数组

给定 k 个升序数组，合并为一个升序序列输出。

**输入格式**

第一行 k（1 ≤ k ≤ 100）。
接下来 k 行：每行先 m_i（0 ≤ m_i ≤ 1e4），后跟 m_i 个升序整数。

**输出格式**

合并后的序列，空格分隔（全空时输出空行）。

**示例输入**

```
3
3 1 4 7
2 2 5
3 3 6 9
```

**示例输出**

```
1 2 3 4 5 6 7 9
```

**答案（Python 3）：**

```python
import sys
import heapq

def solve():
    data = sys.stdin.read().split()
    idx = 0
    k = int(data[idx]); idx += 1
    rows = []
    for _ in range(k):
        m = int(data[idx]); idx += 1
        rows.append(list(map(int, data[idx:idx+m]))); idx += m
    heap = []
    for rid, row in enumerate(rows):
        if row:
            heapq.heappush(heap, (row[0], rid, 0))
    out = []
    while heap:
        v, rid, j = heapq.heappop(heap)
        out.append(str(v))
        if j + 1 < len(rows[rid]):
            heapq.heappush(heap, (rows[rid][j+1], rid, j+1))
    print(" ".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
小顶堆多路归并：堆中放每路的（当前值, 路号, 下标），弹出最小值后推进该路下一元素。总元素 N、路数 k，复杂度 O(N log k)——优于全部合并后排序的 O(N log N)。


### Tree-001-003 | ★★★★☆

**题目：** 前 K 个高频元素

输出数组中出现频率前 k 高的元素（并列时输出值较小的），按"频率降序、值升序"输出 k 个。

**输入格式**

第一行 n, k（1 ≤ k ≤ n ≤ 1e5）。第二行 n 个整数。

**输出格式**

一行 k 个整数，空格分隔。

**示例输入**

```
6 2
1 1 1 2 2 3
```

**示例输出**

```
1 2
```

**答案（Python 3）：**

```python
import sys
import heapq
from collections import Counter

def solve():
    data = sys.stdin.read().split()
    n, k = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    cnt = Counter(a)
    heap = []
    for v, c in cnt.items():
        heapq.heappush(heap, (c, -v))
        if len(heap) > k:
            heapq.heappop(heap)
    items = [(-c, -negv) for c, negv in heap]   # (频次, 值)
    items.sort()                                  # (-频次, 值) 升序 = 频次降序、值升序
    print(" ".join(str(v) for _, v in items))

if __name__ == "__main__":
    solve()
```

**解析：**
Counter 计数 + 小顶堆维护 (频次, 值) 前 k 个（频次相同值小优先弹出——按题目要求构造比较键为 (频次, -值)）；O(n log k)。


### Tree-001-004 | ★★★☆☆

**题目：** 二叉树的层序遍历

给定二叉树的层序序列（-1 表示该位置无节点，空子树同样占位），按层输出遍历结果，每层一行。忽略空节点。

**输入格式**

第一行 n（节点占位数 ≥ 1）。
第二行 n 个整数，表示层序序列（-1 表示空）。

**输出格式**

若干行，每行为一层节点值，空格分隔。

**示例输入**

```
9
3 9 20 -1 -1 15 7 -1 -1
```

**示例输出**

```
3
9 20
15 7
```

**答案（Python 3）：**

```python
import sys
from collections import deque

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    seq = [int(x) for x in data[1:1+n]]
    if not seq or seq[0] == -1:
        return
    root = [seq[0]]
    qi = deque([root])           # 队列存"节点桶"（长度1的列表），便于修改
    idx = 1
    levels = [[seq[0]]]
    cur_level = [root[0]]
    # 重新用标准 BFS 分层
    class T:
        def __init__(self, v):
            self.v = v; self.l = None; self.r = None
    rootT = T(seq[0])
    dq = deque([rootT])
    idx = 1
    levels = [[seq[0]]]
    while dq:
        size = len(dq)
        layer = []
        for _ in range(size):
            node = dq.popleft()
            for pos in ("l", "r"):
                if idx < n:
                    v = seq[idx]; idx += 1
                    if v != -1:
                        child = T(v)
                        setattr(node, pos, child)
                        layer.append(v)
                        dq.append(child)
        if layer:
            levels.append(layer)
    for layer in levels:
        print(" ".join(map(str, layer)))

if __name__ == "__main__":
    solve()
```

**解析：**
按"下标法"由层序序列建树：第 i 个位置的节点，其左右孩子位于 2i+1 与 2i+2（-1 视为 None，其子树占位仍可能存在需跳过——严格层序含空占位时用队列逐个消费序列更稳，本题采用"队列消费序列"实现：出队一个节点，从序列取两个孩子）。BFS 时记录每层节点数分层输出。


### Tree-001-005 | ★★★☆☆

**题目：** 二叉树的最大深度

给定二叉树的层序序列（-1 表示该位置无节点），输出最大深度（根节点深度为 1）。

**输入格式**

第一行 n（占位数 ≥ 1）。
第二行 n 个整数（-1 表示空）。

**输出格式**

一个整数。

**示例输入**

```
9
3 9 20 -1 -1 15 7 -1 -1
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys
from collections import deque

class T:
    __slots__ = ("l", "r")
    def __init__(self):
        self.l = None
        self.r = None

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    seq = [int(x) for x in data[1:1+n]]
    if n == 0 or seq[0] == -1:
        print(0)
        return
    root = T()
    dq = deque([root])
    idx = 1
    while dq and idx < n:
        node = dq.popleft()
        for attr in ("l", "r"):
            if idx < n:
                v = seq[idx]; idx += 1
                if v != -1:
                    child = T()
                    setattr(node, attr, child)
                    dq.append(child)
    depth = 0
    dq = deque([root])
    while dq:
        depth += 1
        for _ in range(len(dq)):
            node = dq.popleft()
            if node.l: dq.append(node.l)
            if node.r: dq.append(node.r)
    print(depth)

if __name__ == "__main__":
    solve()
```

**解析：**
与 A-TREE-001 相同的层序建树，BFS 按层扩展时计数层数；或建树后 DFS 递归 `depth = 1 + max(l, r)`。注意空树的深度为 0。


### Tree-001-006 | ★★★☆☆

**题目：** 对称二叉树

给定层序序列（-1 表空，同 A-TREE-001 约定）建树，判断是否轴对称。

**输入格式**

一行：n 与 n 个整数层序序列。

**输出格式**

`true` 或 `false`。

**示例输入**

```
7
1 2 2 3 4 4 3
```

**示例输出**

```
true
```

**答案（Python 3）：**

```python
import sys
from collections import deque

class T:
    __slots__ = ("v", "l", "r")
    def __init__(self, v):
        self.v = v; self.l = None; self.r = None

def build(seq):
    n = len(seq)
    if n == 0 or seq[0] == -1:
        return None
    root = T(seq[0]); dq = deque([root]); idx = 1
    while dq and idx < n:
        node = dq.popleft()
        for attr in ("l", "r"):
            if idx < n:
                v = seq[idx]; idx += 1
                if v != -1:
                    ch = T(v); setattr(node, attr, ch); dq.append(ch)
    return root

def is_mirror(a, b):
    if a is None and b is None:
        return True
    if a is None or b is None:
        return False
    return a.v == b.v and is_mirror(a.l, b.r) and is_mirror(a.r, b.l)

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    seq = [int(x) for x in data[1:1+n]]
    root = build(seq)
    print("true" if is_mirror(root, root) else "false")

if __name__ == "__main__":
    solve()
```

**解析：**
双指针递归：isMirror(l,r)——l.r 与 r.l 比、l.l 与 r.r 比；迭代法用队列存对称位置对。


### Tree-001-007 | ★★★★☆

**题目：** 验证二叉搜索树

给定层序序列（-1 表空）建树，判断是否为合法 BST（严格左小右大）。

**输入格式**

一行：n 与 n 个整数层序序列（节点值 |v| ≤ 1e9）。

**输出格式**

`true` 或 `false`。

**示例输入**

```
7
5 1 4 -1 -1 3 6
```

**示例输出**

```
false
```

**答案（Python 3）：**

```python
import sys
from collections import deque

class T:
    __slots__ = ("v", "l", "r")
    def __init__(self, v):
        self.v = v; self.l = None; self.r = None

def build(seq):
    n = len(seq)
    if n == 0 or seq[0] == -1:
        return None
    root = T(seq[0]); dq = deque([root]); idx = 1
    while dq and idx < n:
        node = dq.popleft()
        for attr in ("l", "r"):
            if idx < n:
                v = seq[idx]; idx += 1
                if v != -1:
                    ch = T(v); setattr(node, attr, ch); dq.append(ch)
    return root

def valid(node, lo, hi):
    if node is None:
        return True
    if not (lo < node.v < hi):
        return False
    return valid(node.l, lo, node.v) and valid(node.r, node.v, hi)

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    seq = [int(x) for x in data[1:1+n]]
    root = build(seq)
    print("true" if valid(root, float("-inf"), float("inf")) else "false")

if __name__ == "__main__":
    solve()
```

**解析：**
中序遍历必须严格递增。递归法要传上下界（不能只比较父子——孙辈可能违反祖先约束）。


### Tree-001-008 | ★★★★☆

**题目：** 二叉树的右视图

给定层序序列（-1 表空）建树，输出从右侧看每层最右节点值。

**输入格式**

一行：n 与 n 个整数层序序列。

**输出格式**

一行整数，空格分隔。

**示例输入**

```
7
1 2 3 -1 5 -1 4
```

**示例输出**

```
1 3 4
```

**答案（Python 3）：**

```python
import sys
from collections import deque

class T:
    __slots__ = ("v", "l", "r")
    def __init__(self, v):
        self.v = v; self.l = None; self.r = None

def build(seq):
    n = len(seq)
    if n == 0 or seq[0] == -1:
        return None
    root = T(seq[0]); dq = deque([root]); idx = 1
    while dq and idx < n:
        node = dq.popleft()
        for attr in ("l", "r"):
            if idx < n:
                v = seq[idx]; idx += 1
                if v != -1:
                    ch = T(v); setattr(node, attr, ch); dq.append(ch)
    return root

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    seq = [int(x) for x in data[1:1+n]]
    root = build(seq)
    if root is None:
        return
    dq = deque([root])
    out = []
    while dq:
        size = len(dq)
        for i in range(size):
            node = dq.popleft()
            if i == size - 1:
                out.append(str(node.v))
            if node.l: dq.append(node.l)
            if node.r: dq.append(node.r)
    print(" ".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
层序 BFS 每层取最后一个；DFS 也可：每层首次到达（depth==len(res)）的右先序节点。

