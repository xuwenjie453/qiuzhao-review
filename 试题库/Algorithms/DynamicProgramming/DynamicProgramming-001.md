### DynamicProgramming-001-001 | ★★★☆☆

**题目：** 爬楼梯

你在爬一个 n 阶楼梯，每次可以爬 1 或 2 个台阶，问有多少种不同的爬法。

**输入格式**

一行一个整数 n（1 ≤ n ≤ 1e5）。

**输出格式**

一个整数（结果对 1e9+7 取模）。

**示例输入**

```
5
```

**示例输出**

```
8
```

**答案（Python 3）：**

```python
import sys

def solve():
    n = int(sys.stdin.read().split()[0])
    MOD = 10**9 + 7
    a, b = 1, 1   # f(0)=1, f(1)=1
    for _ in range(2, n + 1):
        a, b = b, (a + b) % MOD
    print(b)

if __name__ == "__main__":
    solve()
```

**解析：**
递推：f(n) = f(n-1) + f(n-2)，即斐波那契；用两个变量滚动即可 O(n) 时间 O(1) 空间。注意取模不改变递推结构。


### DynamicProgramming-001-002 | ★★★☆☆

**题目：** 最大子数组和

给定整数数组（可能含负数），求和最大的连续子数组的和（子数组至少包含一个元素）。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。
第二行 n 个整数 ai（|ai| ≤ 1e4）。

**输出格式**

一个整数。

**示例输入**

```
9
-2 1 -3 4 -1 2 1 -5 4
```

**示例输出**

```
6
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = list(map(int, data[1:1+n]))
    cur = best = a[0]
    for x in a[1:]:
        cur = max(x, cur + x)
        best = max(best, cur)
    print(best)

if __name__ == "__main__":
    solve()
```

**解析：**
Kadane 算法：dp[i] = max(a[i], dp[i-1] + a[i])，表示以 i 结尾的最大子数组和；全局答案取 max(dp)。滚动变量即可。语义直觉：前面累积和为负时"抛弃前面的"。


### DynamicProgramming-001-003 | ★★★★☆

**题目：** 零钱兑换

给定不同面额硬币 coins 和总金额 amount，求凑成总金额所需的最少硬币个数；无法凑出输出 -1（每种硬币数量无限）。

**输入格式**

第一行 amount, n（0 ≤ amount ≤ 1e4, 1 ≤ n ≤ 12）。
第二行 n 个面额 ci（1 ≤ ci ≤ 1e4）。

**输出格式**

一个整数。

**示例输入**

```
11 3
1 2 5
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
    amount, n = int(data[0]), int(data[1])
    coins = list(map(int, data[2:2+n]))
    INF = float("inf")
    dp = [0] + [INF] * amount
    for x in range(1, amount + 1):
        for c in coins:
            if c <= x and dp[x - c] + 1 < dp[x]:
                dp[x] = dp[x - c] + 1
    print(dp[amount] if dp[amount] != INF else -1)

if __name__ == "__main__":
    solve()
```

**解析：**
完全背包求最少件数：dp[x] = 凑出金额 x 的最少硬币数，dp[0]=0，转移 dp[x] = min(dp[x], dp[x-c] + 1) 对每种硬币遍历（外层金额或外层硬币均可，求最少件数时顺序不影响）。不可达标记为无穷。


### DynamicProgramming-001-004 | ★★★★☆

**题目：** 最长递增子序列

给定整数数组，求最长严格递增子序列的**长度**（子序列可不连续）。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。
第二行 n 个整数 ai（|ai| ≤ 1e9）。

**输出格式**

一个整数。

**示例输入**

```
8
10 9 2 5 3 7 101 18
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys
import bisect

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = list(map(int, data[1:1+n]))
    tails = []
    for x in a:
        pos = bisect.bisect_left(tails, x)   # 严格递增用 bisect_left
        if pos == len(tails):
            tails.append(x)
        else:
            tails[pos] = x
    print(len(tails))

if __name__ == "__main__":
    solve()
```

**解析：**
两种解法都要会：①O(n²) DP：dp[i] 为以 i 结尾的 LIS 长度，转移取所有 j<i 且 a[j]<a[i] 的 dp 最大值 +1；②O(n log n) 贪心+二分：tails[k] 维护"长度为 k+1 的 LIS 的最小结尾"，遍历元素二分替换或追加——tails 单调递增，长度即答案。


### DynamicProgramming-001-005 | ★★★★★

**题目：** 编辑距离

给定两个单词 word1、word2，计算把 word1 转换成 word2 所需的最少操作数（可插入、删除、替换一个字符）。

**输入格式**

两行，每行一个单词（长度 0 ≤ |w| ≤ 1000，可能为空行）。

**输出格式**

一个整数。

**示例输入**

```
horse
ros
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys

def solve():
    lines = sys.stdin.read().split("\n")
    w1 = lines[0].strip() if len(lines) > 0 else ""
    w2 = lines[1].strip() if len(lines) > 1 else ""
    m, n = len(w1), len(w2)
    prev = list(range(n + 1))
    for i in range(1, m + 1):
        cur = [i] + [0] * n
        for j in range(1, n + 1):
            if w1[i-1] == w2[j-1]:
                cur[j] = prev[j-1]
            else:
                cur[j] = 1 + min(prev[j-1], prev[j], cur[j-1])
        prev = cur
    print(prev[n])

if __name__ == "__main__":
    solve()
```

**解析：**
经典二维 DP：dp[i][j] 表示 word1 前 i 个字符转成 word2 前 j 个字符的最少操作。转移：字符相等 dp[i][j]=dp[i-1][j-1]；否则 1 + min(替换 dp[i-1][j-1]，删除 dp[i-1][j]，插入 dp[i][j-1])。边界 dp[i][0]=i、dp[0][j]=j。滚动数组可压到 O(min(m,n))。


### DynamicProgramming-001-006 | ★★★★★

**题目：** 最长有效括号

给定只含 `(` 和 `)` 的字符串，求最长**连续有效**（格式正确且连续）括号子串的长度。

**输入格式**

一行字符串 s（|s| ≤ 3e4）。

**输出格式**

一个整数。

**示例输入**

```
)()())
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().strip()
    n = len(s)
    dp = [0] * n
    best = 0
    for i in range(1, n):
        if s[i] == ')':
            if s[i-1] == '(':
                dp[i] = (dp[i-2] if i >= 2 else 0) + 2
            else:
                j = i - 1 - dp[i-1]
                if j >= 0 and s[j] == '(':
                    dp[i] = dp[i-1] + 2 + (dp[j-1] if j >= 1 else 0)
            best = max(best, dp[i])
    print(best)

if __name__ == "__main__":
    solve()
```

**解析：**
动态规划：dp[i] 为以 i 结尾的最长有效括号长度。s[i]==')' 时：若 s[i-1]=='('，dp[i]=dp[i-2]+2；否则看 i-1-dp[i-1] 位置是否为 '('，是则 dp[i]=dp[i-1]+2+dp[i-1-dp[i-1]-1]。栈解法（存下标+底哨兵）亦可，DP 版更能体现状态设计。


### DynamicProgramming-001-007 | ★★★★☆

**题目：** 打家劫舍 II（环形）

一排 n 房屋围成环形，相邻房屋不能同时偷窃。每个房屋有非负金额，求能偷窃到的最高金额（每间房最多偷一次；n=1 时只偷该间）。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。
第二行 n 个非负整数 ai（0 ≤ ai ≤ 1e4）。

**输出格式**

一个整数。

**示例输入**

```
4
1 2 3 1
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys

def rob_linear(vals):
    prev, cur = 0, 0
    for x in vals:
        prev, cur = cur, max(cur, prev + x)
    return cur

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = list(map(int, data[1:1+n]))
    if n == 1:
        print(a[0])
        return
    print(max(rob_linear(a[:-1]), rob_linear(a[1:])))

if __name__ == "__main__":
    solve()
```

**解析：**
环形拆解为两个线性问题：不考虑第一间（偷 1..n-1）与不考虑最后一间（偷 0..n-2），取最大——因为首尾相邻的约束等价于"两者至少有一个不偷"。线性打家劫舍用滚动变量：cur = max(prev + x, cur)。n=1 特判直接取 a[0]。


### DynamicProgramming-001-008 | ★★★★☆

**题目：** 最长公共子序列

给定两个字符串 s1、s2，求最长公共子序列（可不连续但保持相对顺序）的长度。

**输入格式**

两行各一个字符串（长度 1 ≤ |s| ≤ 1000）。

**输出格式**

一个整数。

**示例输入**

```
abcde
ace
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys

def solve():
    lines = sys.stdin.read().split("\n")
    s1 = lines[0].strip() if lines else ""
    s2 = lines[1].strip() if len(lines) > 1 else ""
    m, n = len(s1), len(s2)
    prev = [0] * (n + 1)
    for i in range(1, m + 1):
        cur = [0] * (n + 1)
        ci = s1[i-1]
        for j in range(1, n + 1):
            if ci == s2[j-1]:
                cur[j] = prev[j-1] + 1
            else:
                cur[j] = prev[j] if prev[j] >= cur[j-1] else cur[j-1]
        prev = cur
    print(prev[n])

if __name__ == "__main__":
    solve()
```

**解析：**
二维 DP：dp[i][j] = s1 前 i 个字符与 s2 前 j 个字符的 LCS 长度。末尾字符相等 dp[i][j]=dp[i-1][j-1]+1；否则 max(dp[i-1][j], dp[i][j-1])。滚动数组压空间到 O(min(m,n))。


### DynamicProgramming-001-009 | ★★★★☆

**题目：** 最长回文子序列

求字符串最长回文**子序列**（可不连续）的长度。

**输入格式**

一行字符串（1 ≤ |s| ≤ 1000）。

**输出格式**

一个整数。

**示例输入**

```
bbbab
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().strip()
    n = len(s)
    dp = [[0] * n for _ in range(n)]
    for i in range(n):
        dp[i][i] = 1
    for i in range(n - 2, -1, -1):
        for j in range(i + 1, n):
            if s[i] == s[j]:
                dp[i][j] = dp[i+1][j-1] + 2 if j - i > 1 else 2
            else:
                dp[i][j] = max(dp[i+1][j], dp[i][j-1])
    print(dp[0][n-1])

if __name__ == "__main__":
    solve()
```

**解析：**
区间 DP：dp[i][j]=s[i..j] 最长回文子序列长；s[i]==s[j] 则 dp=dp[i+1][j-1]+2，否则 max(dp[i+1][j], dp[i][j-1])；i 从 n-1 倒序、j 从 i+1 正序。等价视角：LCS(s, reverse(s))。


### DynamicProgramming-001-010 | ★★★★☆

**题目：** 分割等和子集

判断正整数数组能否分割成两个子集使两者元素和相等。

**输入格式**

第一行 n（1 ≤ n ≤ 200）。第二行 n 个正整数（≤100）。

**输出格式**

`true` 或 `false`。

**示例输入**

```
4
1 5 11 5
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
    total = sum(a)
    if total % 2:
        print("false")
        return
    target = total // 2
    dp = [False] * (target + 1)
    dp[0] = True
    for x in a:
        for c in range(target, x - 1, -1):
            if dp[c - x]:
                dp[c] = True
    print("true" if dp[target] else "false")

if __name__ == "__main__":
    solve()
```

**解析：**
转化为"能否选出和为 sum/2 的子集"= 0-1 背包可行性。奇数和直接 false；一维 dp 倒序枚举容量防重复选取。


### DynamicProgramming-001-011 | ★★★★☆

**题目：** 完全平方数

求和为 n 的完全平方数（1,4,9,…）的最少个数。

**输入格式**

一行 n（1 ≤ n ≤ 1e4）。

**输出格式**

一个整数。

**示例输入**

```
12
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys

def solve():
    n = int(sys.stdin.read().split()[0])
    INF = float("inf")
    dp = [0] + [INF] * n
    i = 1
    while i * i <= n:
        sq = i * i
        for j in range(sq, n + 1):
            if dp[j - sq] + 1 < dp[j]:
                dp[j] = dp[j - sq] + 1
        i += 1
    print(dp[n])

if __name__ == "__main__":
    solve()
```

**解析：**
完全背包最少件数：dp[j]=min(dp[j], dp[j-i*i]+1) 对每个平方数 i²，容量正序（可重复使用）。

