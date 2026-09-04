### BinarySearch-002-001 | ★★★★☆

搜索旋转排序数组。整数数组 nums 按升序排列后在某个未知下标处旋转（如 [0,1,2,4,5,6,7] 旋转后变为 [4,5,6,7,0,1,2]），给定目标值 target，若在数组中返回其下标否则返回 -1，要求 O(log n)：判断哪一半是有序的再决定二分方向，数组元素互异。输入：nums = [4,5,6,7,0,1,2], target = 0；输出：4。

**答案（Python 3）：**

```python
class Solution:
    # O(log n)：每次判断哪一半有序，再看 target 是否落在有序半段的值域内决定收缩方向
    # 元素互异保证 nums[l]<=nums[m] 能可靠判断左半有序
    def search(self, nums, target):
        l, r = 0, len(nums) - 1
        while l <= r:
            m = (l + r) // 2
            if nums[m] == target:
                return m
            if nums[l] <= nums[m]:                  # 左半 [l, m] 有序
                if nums[l] <= target < nums[m]:
                    r = m - 1
                else:
                    l = m + 1
            else:                                   # 右半 [m, r] 有序
                if nums[m] < target <= nums[r]:
                    l = m + 1
                else:
                    r = m - 1
        return -1
```

**解析：**
二分中先判断哪半有序（nums[l]<=nums[m] 则左半有序），再看 target 是否落在有序半段值域内决定方向；元素互异保证判断可靠。O(log n)。


### BinarySearch-002-002 | ★★★★☆

x 的平方根。给定非负整数 x，计算并返回 x 的算术平方根的整数部分（结果只保留整数部分，舍去小数），不允许使用内置指数函数 pow(x, 0.5)。要求用二分查找实现并说清楚上界与循环条件；追问牛顿迭代法怎么写。输入：x = 8；输出：2。

**答案（Python 3）：**

```python
class Solution:
    # 二分：上界 x//2（x>=2 时 sqrt(x) <= x/2），条件 m <= x//m 记录答案并向右探
    # Python 无溢出；C++ 中 m*m 会溢出，应写 m <= x / m
    def mySqrt(self, x: int) -> int:
        if x < 2:
            return x
        l, r, ans = 1, x // 2, 0
        while l <= r:
            m = (l + r) // 2
            if m <= x // m:
                ans = m         # m 是可行解，继续找更大的
                l = m + 1
            else:
                r = m - 1
        return ans

# 追问：牛顿迭代求整数平方根，二次收敛：r = (r + x//r) // 2 直到 r*r <= x
def mySqrtNewton(x: int) -> int:
    r = x
    while r * r > x:
        r = (r + x // r) // 2
    return r
```

**解析：**
二分 [1, x//2]：m<=x//m 时记录答案并向右探（C++ 用除法写 m<=x/m 防 m*m 溢出）；牛顿迭代 r=(r+x//r)//2 直到 r*r<=x，二次收敛。


### BinarySearch-002-003 | ★★★★☆

二分查找。给定 n 个元素有序（升序）整型数组 nums 和目标值 target，写一个函数搜索 nums 中的 target，存在返回下标否则返回 -1，要求 O(log n)，现场正确处理 left <= right / 左闭右开等边界写法。输入：nums = [-1,0,3,5,9,12], target = 9；输出：4。

**答案（Python 3）：**

```python
class Solution:
    # 闭区间 [l, r] 标准二分：l <= r 循环、命中返回、否则收缩边界。O(log n)
    def search(self, nums, target):
        l, r = 0, len(nums) - 1
        while l <= r:
            m = (l + r) // 2
            if nums[m] == target:
                return m
            elif nums[m] < target:
                l = m + 1
            else:
                r = m - 1
        return -1
```

**解析：**
闭区间 [l,r] 标准二分：l<=r 循环、命中返回、小则 l=m+1、大则 r=m-1，区间定义与边界自洽不漏不重；O(log n)。


### BinarySearch-002-004 | ★★★★☆

寻找两个正序数组的中位数。给定两个大小分别为 m 和 n 的正序（从小到大）数组 nums1 和 nums2，找出并返回这两个正序数组的中位数，要求算法时间复杂度为 O(log(m+n))（二分较短数组的分割线）。输入：nums1 = [1,3], nums2 = [2]；输出：2.0。输入：nums1 = [1,2], nums2 = [3,4]；输出：2.5。

**答案（Python 3）：**

```python
class Solution:
    # 二分较短数组的分割线 i（j = half - i 自动确定另一数组取的个数）
    # 合法条件 L1<=R2 且 L2<=R1：奇数总长取左半最大，偶数取 (左半最大+右半最小)/2
    # 时间 O(log(min(m, n)))
    def findMedianSortedArrays(self, nums1, nums2):
        if len(nums1) > len(nums2):
            nums1, nums2 = nums2, nums1     # 保证二分较短的那个
        m, n = len(nums1), len(nums2)
        total = m + n
        half = (total + 1) // 2             # 中位分割线左侧应放的元素个数
        lo, hi = 0, m
        while lo <= hi:
            i = (lo + hi) // 2              # nums1 贡献左侧 i 个
            j = half - i                    # nums2 贡献左侧 j 个
            L1 = nums1[i - 1] if i > 0 else float('-inf')
            R1 = nums1[i] if i < m else float('inf')
            L2 = nums2[j - 1] if j > 0 else float('-inf')
            R2 = nums2[j] if j < n else float('inf')
            if L1 <= R2 and L2 <= R1:       # 分割线合法
                if total % 2:
                    return float(max(L1, L2))
                return (max(L1, L2) + min(R1, R2)) / 2
            elif L1 > R2:
                hi = i - 1                  # nums1 取多了
            else:
                lo = i + 1                  # nums1 取少了
        raise ValueError("输入不合法")
```

**解析：**
二分较短数组的分割线 i，j=half-i 自动确定，合法条件 L1<=R2 且 L2<=R1；奇数总长取左半 max，偶数取 (左max+右min)/2。O(log(min(m,n)))。


### BinarySearch-002-005 | ★★★★☆

Pow(x, n)。实现快速幂函数 pow(x, n)，计算 x 的 n 次方（即 x^n），n 可以为负数，要求 O(log n)：快速幂（递归或迭代），注意 n = INT_MIN 取负溢出的边界处理。输入：x = 2.00000, n = 10；输出：1024.00000。输入：x = 2.00000, n = -2；输出：0.25000。

**答案（Python 3）：**

```python
class Solution:
    # 迭代快速幂 O(log n)：按 n 的二进制位累乘，x 逐位自乘
    def myPow(self, x: float, n: int) -> float:
        if n < 0:
            x = 1 / x
            n = -n          # Python 整数无溢出；C++ 需先把 n 放进 long long 再取负（防 INT_MIN 溢出）
        ans = 1.0
        while n:
            if n & 1:       # 当前二进制位为 1 则乘入结果
                ans *= x
            x *= x
            n >>= 1
        return ans
```

**解析：**
迭代快速幂按 n 的二进制位累乘、x 逐位自乘，O(log n)；负指数先取倒数再转正，C++ 中需先把 n 存入 long long 防 INT_MIN 取负溢出。

