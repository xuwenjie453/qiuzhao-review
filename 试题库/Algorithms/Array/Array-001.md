### Array-001-001 | ★★★☆☆

**题目：** 区间和查询

给定一个长度为 n 的整数数组，回答 q 次询问：第 l 个元素到第 r 个元素（下标从 1 开始，含两端）的和是多少？

**输入格式**

第一行两个整数 n, q（1 ≤ n ≤ 1e5, 1 ≤ q ≤ 1e5）。
第二行 n 个整数 a1..an（|ai| ≤ 1e9）。
接下来 q 行，每行两个整数 l, r（1 ≤ l ≤ r ≤ n）。

**输出格式**

对每个询问输出一行，一个整数表示区间和。

**示例输入**

```
5 2
1 -2 3 4 5
1 3
2 5
```

**示例输出**

```
2
10
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    idx = 0
    n, q = int(data[idx]), int(data[idx+1]); idx += 2
    a = [int(data[idx+i]) for i in range(n)]; idx += n
    prefix = [0] * (n + 1)
    for i in range(1, n + 1):
        prefix[i] = prefix[i-1] + a[i-1]
    out = []
    for _ in range(q):
        l, r = int(data[idx]), int(data[idx+1]); idx += 2
        out.append(str(prefix[r] - prefix[l-1]))
    print("\n".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
前缀和模板：prefix[i] = a1+...+ai，区间 [l,r] 的和 = prefix[r] - prefix[l-1]。预处理 O(n)，每次询问 O(1)，总共 O(n+q)。直接每次遍历区间是 O(n*q)，会超时——这是本题的考点。


### Array-001-002 | ★★★☆☆

**题目：** 最大连续 1 的个数

给定 0/1 数组，输出最长连续 1 的长度。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。第二行 n 个整数（0 或 1）。

**输出格式**

一个整数。

**示例输入**

```
6
1 1 0 1 1 1
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = list(map(int, data[1:1+n]))
    cur = best = 0
    for x in a:
        cur = cur + 1 if x == 1 else 0
        best = max(best, cur)
    print(best)

if __name__ == "__main__":
    solve()
```

**解析：**
一次遍历维护当前连续长度 cur 与最大值 best：遇 1 则 cur+1 更新 best，遇 0 归零。


### Array-001-003 | ★★★★☆

**题目：** 轮转数组

将长度为 n 的数组向右轮转 k 次，输出结果。

**输入格式**

第一行 n, k（1 ≤ n ≤ 1e5, 0 ≤ k ≤ 1e9）。第二行 n 个整数。

**输出格式**

一行结果，空格分隔。

**示例输入**

```
7 3
1 2 3 4 5 6 7
```

**示例输出**

```
5 6 7 1 2 3 4
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n, k = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    k %= n
    a.reverse()
    a[:k] = reversed(a[:k])
    a[k:] = reversed(a[k:])
    print(" ".join(map(str, a)))

if __name__ == "__main__":
    solve()
```

**解析：**
k %= n；三步翻转法：整体翻转→前 k 个翻转→后 n-k 个翻转，原地 O(1) 额外空间。


### Array-001-004 | ★★★★☆

**题目：** 和为 K 的子数组

给定整数数组和整数 k，统计该数组中和恰好等于 k 的**连续子数组**的个数。

**输入格式**

第一行两个整数 n, k（1 ≤ n ≤ 2e5, -1e9 ≤ k ≤ 1e9）。
第二行 n 个整数 ai（|ai| ≤ 1e9）。

**输出格式**

一个整数，表示和为 k 的连续子数组个数。

**示例输入**

```
5 3
1 2 3 -1 3
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys
from collections import defaultdict

def solve():
    data = sys.stdin.read().split()
    n, k = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    cnt = defaultdict(int)
    cnt[0] = 1
    s = 0
    ans = 0
    for x in a:
        s += x
        ans += cnt[s - k]
        cnt[s] += 1
    print(ans)

if __name__ == "__main__":
    solve()
```

**解析：**
前缀和 + 哈希计数：设 prefix[i] 为前 i 个数的和，子数组 (j+1..i) 和为 k 等价于 prefix[j] = prefix[i] - k。从左到右扫描，用哈希表记录每个前缀和出现的次数，答案累加 `cnt[prefix[i] - k]`。注意初始 cnt[0] = 1（从头开始的子数组）。示例中三组解为 [1,2]、[3]、[末位的3]。数组含负数，不能滑动窗口——这是本题相对"正数数组滑窗"的区分点。


### Array-001-005 | ★★★★☆

**题目：** 差分：区间批量加减

长度为 n 的数组初始全为 0。进行 m 次操作，每次把区间 [l, r]（1-based）内所有元素加上 v。求 m 次操作后的最终数组。

**输入格式**

第一行 n, m（1 ≤ n ≤ 1e5, 1 ≤ m ≤ 1e5）。
接下来 m 行，每行三个整数 l, r, v（1 ≤ l ≤ r ≤ n，|v| ≤ 1e4）。

**输出格式**

一行 n 个整数，表示最终数组，用空格分隔。

**示例输入**

```
5 2
1 3 2
2 5 -1
```

**示例输出**

```
2 1 1 -1 -1
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    idx = 0
    n, m = int(data[idx]), int(data[idx+1]); idx += 2
    diff = [0] * (n + 2)
    for _ in range(m):
        l, r, v = int(data[idx]), int(data[idx+1]), int(data[idx+2]); idx += 3
        diff[l] += v
        diff[r+1] -= v
    out = []
    cur = 0
    for i in range(1, n + 1):
        cur += diff[i]
        out.append(str(cur))
    print(" ".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
差分模板：diff[l] += v，diff[r+1] -= v；最后对 diff 求前缀和即得到原数组。m 次操作 O(1) 完成，最后 O(n) 还原。


### Array-001-006 | ★★★★☆

**题目：** 和可被 K 整除的子数组

求数组中和可被 K 整除的**非空连续子数组**个数。

**输入格式**

第一行 n, K（1 ≤ n ≤ 3e4, 2 ≤ K ≤ 1e4）。第二行 n 个整数。

**输出格式**

一个整数。

**示例输入**

```
6 5
4 5 0 -2 -3 1
```

**示例输出**

```
7
```

**答案（Python 3）：**

```python
import sys
from collections import defaultdict

def solve():
    data = sys.stdin.read().split()
    n, K = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    cnt = defaultdict(int)
    cnt[0] = 1
    s = 0
    ans = 0
    for x in a:
        s = ((s + x) % K + K) % K
        ans += cnt[s]
        cnt[s] += 1
    print(ans)

if __name__ == "__main__":
    solve()
```

**解析：**
同余定理：子段 (j, i] 和被 K 整除 ⇔ 前缀和 pre[i] ≡ pre[j] (mod K)。哈希计余数出现次数，答案累加"同余前缀和的累计数"；**负数取模要 ((x % K) + K) % K** 归一化。初始 cnt[0]=1。

