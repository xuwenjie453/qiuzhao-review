### Greedy-001-001 | ★★★★☆

**题目：** 跳跃游戏

数组每个元素代表在该位置可跳跃的最大长度，初始在第一个位置，判断能否到达最后一个位置。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。
第二行 n 个非负整数 ai（0 ≤ ai ≤ 1e5）。

**输出格式**

能到达输出 `true`，否则 `false`。

**示例输入**

```
5
2 3 1 1 4
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
    a = list(map(int, data[1:1+n]))
    far = 0
    for i in range(n):
        if i > far:
            print("false")
            return
        far = max(far, i + a[i])
        if far >= n - 1:
            break
    print("true")

if __name__ == "__main__":
    solve()
```

**解析：**
贪心维护"当前能到达的最远下标 farthest"：从左到右扫描，i > farthest 说明被卡死返回 false，否则 farthest = max(farthest, i + a[i])，farthest ≥ n-1 即可达。


### Greedy-001-002 | ★★★★☆

**题目：** 合并区间

给定 n 个区间 [l, r]（端点相等视为相交，可合并），合并所有重叠区间，输出合并后的区间集合（按左端点升序）。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。
接下来 n 行，每行两个整数 l, r（-1e9 ≤ l ≤ r ≤ 1e9）。

**输出格式**

每行一个合并后的区间 "l r"。

**示例输入**

```
4
1 3
2 6
8 10
15 18
```

**示例输出**

```
1 6
8 10
15 18
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    iv = []
    idx = 1
    for _ in range(n):
        l, r = int(data[idx]), int(data[idx+1])
        idx += 2
        iv.append((l, r))
    iv.sort()
    res = []
    for l, r in iv:
        if res and l <= res[-1][1]:
            res[-1][1] = max(res[-1][1], r)
        else:
            res.append([l, r])
    out = []
    for l, r in res:
        out.append(f"{l} {r}")
    print("\n".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
按左端点排序后线性扫描：当前区间与结果末区间有交集（l ≤ 末区间右端点）则延伸右端点（取 max），否则开新区间。排序 O(n log n) 后合并 O(n)。


### Greedy-001-003 | ★★★☆☆

**题目：** 买卖股票的最佳时机

给定每天股价，只允许一次买入一次卖出（先买后卖），求最大利润；不能盈利输出 0。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。第二行 n 个正整数。

**输出格式**

一个整数。

**示例输入**

```
6
7 1 5 3 6 4
```

**示例输出**

```
5
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    p = list(map(int, data[1:1+n]))
    minp = p[0]
    best = 0
    for x in p[1:]:
        best = max(best, x - minp)
        minp = min(minp, x)
    print(best)

if __name__ == "__main__":
    solve()
```

**解析：**
一遍扫描维护历史最低价 minP，当前价减 minP 更新答案；O(n) O(1)。


### Greedy-001-004 | ★★★★☆

**题目：** 无重叠区间

给定若干区间，求最少移除多少个区间使剩余区间互不重叠（端点相触不算重叠）。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。接下来 n 行每行 l, r。

**输出格式**

一个整数（最少移除数）。

**示例输入**

```
4
1 2
2 3
3 4
1 3
```

**示例输出**

```
1
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    iv = []
    idx = 1
    for _ in range(n):
        l, r = int(data[idx]), int(data[idx+1]); idx += 2
        iv.append((l, r))
    iv.sort(key=lambda t: t[1])
    keep = 0
    last_end = float("-inf")
    for l, r in iv:
        if l >= last_end:
            keep += 1
            last_end = r
    print(n - keep)

if __name__ == "__main__":
    solve()
```

**解析：**
按右端点升序排序，贪心保留结束早的：遍历中若当前区间左端 ≥ 上一个保留区间的右端则保留，否则移除。移除数 = n - 保留数。

