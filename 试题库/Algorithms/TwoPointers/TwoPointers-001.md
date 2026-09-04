### TwoPointers-001-001 | ★★★★☆

**题目：** 长度最小的子数组

给定 n 个**正整数**组成的数组和正整数 target，找出和 ≥ target 的长度最小的连续子数组，输出其长度；不存在输出 0。

**输入格式**

第一行 n, target（1 ≤ n ≤ 1e5, 1 ≤ target ≤ 1e9）。
第二行 n 个正整数 ai（1 ≤ ai ≤ 1e5）。

**输出格式**

一个整数。

**示例输入**

```
6 7
2 3 1 2 4 3
```

**示例输出**

```
2
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n, target = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    left = 0
    s = 0
    ans = n + 1
    for right in range(n):
        s += a[right]
        while s >= target:
            ans = min(ans, right - left + 1)
            s -= a[left]
            left += 1
    print(ans if ans <= n else 0)

if __name__ == "__main__":
    solve()
```

**解析：**
滑动窗口：右指针扩窗累加，窗口和 ≥ target 时收缩左指针并更新答案。正确性依赖元素全为正（和单调，收缩有效）；含负数时该解法失效（退化为前缀和+单调队列/二分）。


### TwoPointers-001-002 | ★★★★★

**题目：** 最小覆盖子串

给定字符串 s 和 t，找出 s 中涵盖 t 所有字符（含重复次数）的最短连续子串，输出该子串本身；若不存在输出 `-1`。若有多个最短解，输出最左边的。

**输入格式**

第一行字符串 s（|s| ≤ 1e5）。
第二行字符串 t（|t| ≤ 1e4，仅大小写字母）。

**输出格式**

最短覆盖子串；不存在输出 `-1`。

**示例输入**

```
ADOBECODEBANC
ABC
```

**示例输出**

```
BANC
```

**答案（Python 3）：**

```python
import sys
from collections import Counter

def solve():
    s = sys.stdin.readline().rstrip("\n")
    t = sys.stdin.readline().rstrip("\n")
    need = Counter(t)
    missing = len(t)
    left = 0
    best = (1 << 30, 0, 0)  # (长度, 起, 止)
    for right, ch in enumerate(s):
        if need[ch] > 0:
            missing -= 1
        need[ch] -= 1
        if missing == 0:
            while need[s[left]] < 0:
                need[s[left]] += 1
                left += 1
            if right - left + 1 < best[0]:
                best = (right - left + 1, left, right)
            # 移出左端字符制造"缺口"，继续找更短
            need[s[left]] += 1
            missing += 1
            left += 1
    print("-1" if best[0] == (1 << 30) else s[best[1]:best[2]+1])

if __name__ == "__main__":
    solve()
```

**解析：**
滑窗 + 需求计数：need 记录 t 中每个字符需求量，window 记录当前窗口计数；用变量 formed 统计"已满足需求的字符种类数"。右指针扩张，当 formed == 需求种类数时收缩左指针并更新最优解。输出本身（不是长度）时记录最优起止下标。


### TwoPointers-001-003 | ★★★★☆

**题目：** 水果成篮

给定正整数数组表示水果类型，只能选两种类型且必须连续，求最多能摘的果实数。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。第二行 n 个正整数。

**输出格式**

一个整数。

**示例输入**

```
5
3 3 3 1 2
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys
from collections import defaultdict

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = list(map(int, data[1:1+n]))
    cnt = defaultdict(int)
    left = 0
    best = 0
    for right, x in enumerate(a):
        cnt[x] += 1
        while len(cnt) > 2:
            y = a[left]
            cnt[y] -= 1
            if cnt[y] == 0:
                del cnt[y]
            left += 1
        best = max(best, right - left + 1)
    print(best)

if __name__ == "__main__":
    solve()
```

**解析：**
可变窗口+"种类数≤2"约束：右扩计数，种类超 2 时左缩到只剩 2 种；每步更新答案。


### TwoPointers-001-004 | ★★★☆☆

**题目：** 有序数组的两数之和

给定升序数组（可能含重复元素）和目标值 target，找出和为 target 的两个不同下标（1-based，输出较小在前）。数据保证存在唯一解。

**输入格式**

第一行 n, target（2 ≤ n ≤ 1e5）。
第二行 n 个升序整数 ai。

**输出格式**

一行两个整数 i j（1-based，i < j）。

**示例输入**

```
5 9
1 2 4 7 11
```

**示例输出**

```
2 4
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n, target = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    l, r = 0, n - 1
    while l < r:
        s = a[l] + a[r]
        if s == target:
            print(l + 1, r + 1)
            return
        elif s < target:
            l += 1
        else:
            r -= 1

if __name__ == "__main__":
    solve()
```

**解析：**
有序数组用对撞双指针：左指针指最小、右指针指最大，和偏小移左指针、偏大移右指针，相遇即无解。利用有序性把哈希解法的 O(n) 空间降到 O(1)。


### TwoPointers-001-005 | ★★★★☆

**题目：** 盛最多水的容器

n 条垂线高度 h[i]，选两条与 x 轴构成容器，求最大储水量。

**输入格式**

第一行 n（2 ≤ n ≤ 1e5）。第二行 n 个非负整数。

**输出格式**

一个整数。

**示例输入**

```
9
1 8 6 2 5 4 8 3 7
```

**示例输出**

```
49
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    h = list(map(int, data[1:1+n]))
    l, r = 0, n - 1
    best = 0
    while l < r:
        area = min(h[l], h[r]) * (r - l)
        best = max(best, area)
        if h[l] < h[r]:
            l += 1
        else:
            r -= 1
    print(best)

if __name__ == "__main__":
    solve()
```

**解析：**
对撞双指针从两端开始，面积=min(h[l],h[r])×(r-l)；每次移动较矮的一端——只有移动矮的才可能让面积变大（宽在减，高受矮端限制）。


### TwoPointers-001-006 | ★★★☆☆

**题目：** 移动零

把数组中所有 0 移到末尾且保持非零元素相对顺序，输出结果数组（不要求原地，但解法按快慢指针原地写）。

**输入格式**

第一行 n。第二行 n 个整数。

**输出格式**

一行结果。

**示例输入**

```
5
0 1 0 3 12
```

**示例输出**

```
1 3 12 0 0
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    a = list(map(int, data[1:1+n]))
    slow = 0
    for fast in range(n):
        if a[fast] != 0:
            a[slow], a[fast] = a[fast], a[slow]
            slow += 1
    print(" ".join(map(str, a)))

if __name__ == "__main__":
    solve()
```

**解析：**
快慢指针：slow 指向"下一个非零应放的位置"，fast 扫描，非零则交换到 slow，保持稳定性。

