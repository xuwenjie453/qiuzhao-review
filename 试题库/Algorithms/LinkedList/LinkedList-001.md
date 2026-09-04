### LinkedList-001-001 | ★★★☆☆

**题目：** 反转单向链表

给定 n 个整数构成的链表，反转后输出序列。

**输入格式**

第一行 n（0 ≤ n ≤ 1e5）。
第二行 n 个整数（n=0 时此行可能为空）。

**输出格式**

反转后的序列，空格分隔；空链表输出空行。

**示例输入**

```
5
1 2 3 4 5
```

**示例输出**

```
5 4 3 2 1
```

**答案（Python 3）：**

```python
import sys

class Node:
    __slots__ = ("val", "next")
    def __init__(self, val):
        self.val = val
        self.next = None

def solve():
    data = sys.stdin.read().split()
    n = int(data[0]) if data else 0
    vals = data[1:1+n]
    head = None
    for v in reversed(vals):      # 头插法建表
        node = Node(int(v))
        node.next = head
        head = node
    # 迭代反转
    prev, cur = None, head
    while cur:
        nxt = cur.next
        cur.next = prev
        prev = cur
        cur = nxt
    out = []
    while prev:
        out.append(str(prev.val))
        prev = prev.next
    print(" ".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
面试要求掌握指针迭代法：prev/cur 双指针，依次把 cur.next 指向 prev 并前移。ACM 里通常用数组模拟：读入数组后逆序输出即可——但面试手写节点版是必备能力，本题保留节点实现展示。


### LinkedList-001-002 | ★★★★☆

**题目：** 合并两个有序链表

给定两个升序链表，合并为一个新升序链表并输出序列。要求按节点逐个比较拼接（不得简单拼接数组后排序）。

**输入格式**

第一行 n 和 n 个升序整数。
第二行 m 和 m 个升序整数。
（0 ≤ n, m ≤ 1e5）

**输出格式**

合并后的升序序列，空格分隔。

**示例输入**

```
3 1 3 5
3 2 4 6
```

**示例输出**

```
1 2 3 4 5 6
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    idx = 0
    n = int(data[idx]); idx += 1
    a = list(map(int, data[idx:idx+n])); idx += n
    m = int(data[idx]); idx += 1
    b = list(map(int, data[idx:idx+m])); idx += m
    # 用数组模拟链表拼接过程
    res = []
    i = j = 0
    while i < n and j < m:
        if a[i] <= b[j]:
            res.append(a[i]); i += 1
        else:
            res.append(b[j]); j += 1
    res.extend(a[i:])
    res.extend(b[j:])
    print(" ".join(map(str, res)))

if __name__ == "__main__":
    solve()
```

**解析：**
哑结点 + 双指针逐个比较摘链：谁小接谁，最后把剩余部分整体接上。归并排序的 merge 过程即是此题。

