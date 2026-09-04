### BinarySearch-001-001 | ★★★☆☆

**题目：** 标准二分查找

在严格升序数组中查找 target，输出其下标（1-based）；不存在输出 -1。

**输入格式**

第一行 n, target（1 ≤ n ≤ 1e6）。
第二行 n 个严格升序整数 ai（|ai| ≤ 1e18）。

**输出格式**

一个整数。

**示例输入**

```
6 7
1 3 5 7 9 11
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n, target = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    lo, hi = 0, n - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if a[mid] == target:
            print(mid + 1)
            return
        elif a[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    print(-1)

if __name__ == "__main__":
    solve()
```

**解析：**
闭区间写法 [lo, hi]：mid 判等返回；小于 target 收 lo = mid+1，大于收 hi = mid-1。面试要求闭区间与左闭右开两种写法都不写错。


### BinarySearch-001-002 | ★★★★☆

**题目：** 旋转数组的最小值

把一个严格升序数组在某个未知点旋转（如 [1,2,3,4,5] → [3,4,5,1,2]），找出其中的最小值。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。
第二行 n 个互不相同的整数。

**输出格式**

最小值。

**示例输入**

```
5
3 4 5 1 2
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
    a = list(map(int, data[1:1+n]))
    lo, hi = 0, n - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if a[mid] > a[hi]:
            lo = mid + 1
        else:
            hi = mid
    print(a[lo])

if __name__ == "__main__":
    solve()
```

**解析：**
与右端点比较的二分：mid > hi 说明最小值在 (mid, hi]，lo = mid+1；mid < hi 说明最小值在 [lo, mid]，hi = mid；lo==hi 收敛即答案。区间不丢解的关键是 hi = mid（而非 mid-1）。


### BinarySearch-001-003 | ★★★★☆

**题目：** 排序数组中查找元素的第一个和最后一个位置

给定非降序数组与目标值 target，输出 target 在数组中出现的第一个与最后一个下标（1-based）；不存在输出 `-1`。

**输入格式**

第一行 n, target（1 ≤ n ≤ 1e6）。
第二行 n 个非降序整数 ai（|ai| ≤ 1e9）。

**输出格式**

一行两个整数，空格分隔；不存在输出 -1。

**示例输入**

```
6 8
5 7 7 8 8 10
```

**示例输出**

```
4 5
```

**答案（Python 3）：**

```python
import sys
import bisect

def solve():
    data = sys.stdin.read().split()
    n, target = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    l = bisect.bisect_left(a, target)
    r = bisect.bisect_right(a, target)
    if l == r:
        print(-1)
    else:
        print(l + 1, r)

if __name__ == "__main__":
    solve()
```

**解析：**
两次二分：bisect_left 找第一个 ≥ target 的位置（即第一次出现），bisect_right - 1 找最后一个；校验下标合法且值等于 target。


### BinarySearch-001-004 | ★★★★☆

**题目：** 寻找峰值

给定相邻元素互不相同的数组 nums，满足 nums[i] ≠ nums[i+1]，任选一个峰值下标输出（1-based）。峰值即严格大于左右邻居的元素，边界处只需大于唯一邻居。题目保证 nums[-1]=nums[n]=−∞。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5）。第二行 n 个互不相同整数。

**输出格式**

任一峰值的下标（1-based）。

**示例输入**

```
4
1 2 3 1
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
    l, r = 0, n - 1
    while l < r:
        mid = (l + r) // 2
        if a[mid] < a[mid + 1]:
            l = mid + 1
        else:
            r = mid
    print(l + 1)

if __name__ == "__main__":
    solve()
```

**解析：**
二分：mid 与 mid+1 比较——若 nums[mid] < nums[mid+1] 说明右侧必上坡，峰值在 [mid+1, r]；否则在 [l, mid]。收缩到单点即峰。看似无序，但坡向提供了二分不变量。

