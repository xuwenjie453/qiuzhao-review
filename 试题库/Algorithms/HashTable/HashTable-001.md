### HashTable-001-001 | ★★★☆☆

**题目：** 两数之和

给定数组和目标值 target，求数组中两个不同位置的数之和等于 target 的下标（从 1 开始，输出较小的在前）。数据保证恰好存在一组解。

**输入格式**

第一行 n, target（2 ≤ n ≤ 1e5）。
第二行 n 个整数 ai（|ai| ≤ 1e9）。

**输出格式**

一行两个整数 i j（1-based，i < j），用空格分隔。

**示例输入**

```
4 9
2 7 11 15
```

**示例输出**

```
1 2
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n, target = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    seen = {}
    for i, x in enumerate(a):
        if target - x in seen:
            print(seen[target - x] + 1, i + 1)
            return
        seen[x] = i

if __name__ == "__main__":
    solve()
```

**解析：**
一遍哈希：遍历数组，对当前 x 先查哈希表中是否有 target-x（记录的是之前的下标），有则输出，否则把 x:idx 存入。O(n)。


### HashTable-001-002 | ★★★★☆

**题目：** 字母异位词分组

给定 n 个仅含小写字母的字符串，把字母异位词（字母相同、顺序可不同）分到同一组。输出每组：组内成员保持输入顺序，组与组之间按"组内字典序最小成员"的字典序升序排列；组内成员用空格分隔。

**输入格式**

第一行 n（1 ≤ n ≤ 1e4）。
第二行 n 个字符串 si（|si| ≤ 20）。

**输出格式**

每组一行（格式见题面），共若干行。

**示例输入**

```
6
eat tea tan ate nat bat
```

**示例输出**

```
eat tea ate
bat
tan nat
```

**答案（Python 3）：**

```python
import sys
from collections import defaultdict

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    words = data[1:1+n]
    groups = defaultdict(list)
    for w in words:
        groups["".join(sorted(w))].append(w)   # 先按字母集合收集异位词组
    merged = {}
    for members in groups.values():
        merged[min(members)] = members         # 组键取"组内字典序最小成员"
    for key in sorted(merged):
        print(" ".join(merged[key]))

if __name__ == "__main__":
    solve()
```

**解析：**
哈希分组：key 用"组内字典序最小成员"（`min(成员列表)`），成员列表保持输入顺序；组间按 min 成员排序后输出。另一常见做法是用 `"".join(sorted(s))` 做分组键，但注意"排序后的键的字典序"与"组内最小成员的字典序"是两种不同的排序口径（如 bat 组的键 abt 会排在 aet 之前），实现时必须与题面口径一致。


### HashTable-001-003 | ★★★☆☆

**题目：** 只出现一次的数字

给定非空整数数组，除某个元素只出现一次外，其余每个元素都出现两次，找出只出现一次的元素。要求线性时间、常数额外空间。

**输入格式**

第一行 n（1 ≤ n ≤ 2e6，n 为奇数）。
第二行 n 个整数 ai（|ai| ≤ 1e9）。

**输出格式**

一个整数。

**示例输入**

```
5
4 1 2 1 2
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys
from functools import reduce

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = list(map(int, data[1:1+n]))
    print(reduce(lambda x, y: x ^ y, a))

if __name__ == "__main__":
    solve()
```

**解析：**
异或的性质：x^x=0、x^0=x、交换结合律成立。全部异或，成对的元素互相抵消为 0，只剩唯一元素。哈希计数 O(n) 空间是对照组；排序后扫描 O(n log n) 空间 O(1) 但慢；异或是考点本体。


### HashTable-001-004 | ★★★☆☆

**题目：** 存在重复元素

判断数组中是否存在重复元素，存在输出 `true` 否则 `false`。

**输入格式**

第一行 n（1 ≤ n ≤ 1e6）。第二行 n 个整数。

**输出格式**

`true` 或 `false`。

**示例输入**

```
4
1 2 3 1
```

**示例输出**

```
true
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = data[1:1+n]
    print("true" if len(set(a)) < n else "false")

if __name__ == "__main__":
    solve()
```

**解析：**
set 判重：len(set(a)) < n 即有重复；O(n) 时间空间。


### HashTable-001-005 | ★★★☆☆

**题目：** 有效的字母异位词

判断两个字符串是否互为字母异位词（字母相同仅顺序不同，仅小写字母）。

**输入格式**

两行各一个字符串（长度 ≤ 1e5）。

**输出格式**

`true` 或 `false`。

**示例输入**

```
anagram
nagaram
```

**示例输出**

```
true
```

**答案（Python 3）：**

```python
import sys
from collections import Counter

def solve():
    lines = sys.stdin.read().split("\n")
    s = lines[0].strip()
    t = lines[1].strip() if len(lines) > 1 else ""
    print("true" if Counter(s) == Counter(t) else "false")

if __name__ == "__main__":
    solve()
```

**解析：**
26 桶计数：长度先判等，再对 s 加计数、对 t 减计数，任一非零即否。Counter 一步到位。

