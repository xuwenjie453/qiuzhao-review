### Array-002-001 | ★★★★☆

三数之和。给定整数数组 nums，判断是否存在三元组 [nums[i], nums[j], nums[k]] 满足 i != j != k 且 nums[i]+nums[j]+nums[k] == 0，返回所有不重复的三元组，答案中不能包含重复的三元组。输入：nums = [-1,0,1,2,-1,-4]；输出：[[-1,-1,2],[-1,0,1]]。约束：3 <= n <= 3000，要求排序 + 双指针 O(n^2) 解法，并说清楚去重逻辑。

**答案（Python 3）：**

```python
class Solution:
    # 排序 + 双指针，O(n^2)
    def threeSum(self, nums):
        nums.sort()
        res = []
        n = len(nums)
        for i in range(n - 2):
            if nums[i] > 0:                              # 最小数大于 0，不可能凑出 0
                break
            if i > 0 and nums[i] == nums[i - 1]:         # 去重1：固定数跳过重复值
                continue
            l, r = i + 1, n - 1
            while l < r:
                s = nums[i] + nums[l] + nums[r]
                if s < 0:
                    l += 1
                elif s > 0:
                    r -= 1
                else:
                    res.append([nums[i], nums[l], nums[r]])
                    l += 1
                    r -= 1
                    while l < r and nums[l] == nums[l - 1]:  # 去重2：左指针跳过重复
                        l += 1
                    while l < r and nums[r] == nums[r + 1]:  # 去重3：右指针跳过重复
                        r -= 1
        return res
```

**解析：**
排序后固定 i、双指针 l/r 收缩找 -nums[i]；去重三处：i 跳过重复值，命中后 l、r 各自跳过重复值。O(n^2)。


### Array-002-002 | ★★★★☆

两数之和。给定整数数组 nums 和目标值 target，找出和为目标值的两个整数的下标，每个输入恰好有一个解，同一元素不能使用两次，按任意顺序返回答案。输入：nums = [2,7,11,15], target = 9；输出：[0,1]。要求哈希表 O(n) 一遍扫描写法。

**答案（Python 3）：**

```python
class Solution:
    # 哈希表一遍扫描：先查 complement 是否出现过，再登记当前值，O(n)/O(n)
    def twoSum(self, nums, target):
        seen = {}                       # 值 -> 下标
        for i, x in enumerate(nums):
            if target - x in seen:
                return [seen[target - x], i]
            seen[x] = i
        return []
```

**解析：**
哈希表存 值->下标 一遍扫描：先查 target-x 是否出现过，再登记当前数，保证同一元素不用两次；O(n)。


### Array-002-003 | ★★★★☆

合并两个有序数组。给定两个按非递减排列的整数数组 nums1（长度 m+n，末尾预留了 n 个 0）和 nums2（长度 n），将 nums2 合并到 nums1 中使 nums1 成为非递减数组，要求原地操作、从后往前双指针填充。输入：nums1 = [1,2,3,0,0,0], m = 3, nums2 = [2,5,6], n = 3；输出：nums1 = [1,2,2,3,5,6]。

**答案（Python 3）：**

```python
class Solution:
    # 从后往前三指针：p 指向 nums1 的待填位置，取两数组较大者放入，避免覆盖未处理元素
    def merge(self, nums1, m, nums2, n):
        i, j, p = m - 1, n - 1, m + n - 1
        while j >= 0:                   # nums2 用完即结束（nums1 前缀已就位）
            if i >= 0 and nums1[i] > nums2[j]:
                nums1[p] = nums1[i]
                i -= 1
            else:
                nums1[p] = nums2[j]
                j -= 1
            p -= 1
```

**解析：**
三指针从后往前原地填充，p 指向 nums1 末尾，取两数组较大者放入，避免从前往后覆盖未处理的 nums1 元素；O(m+n)/O(1)。


### Array-002-004 | ★★★★☆

合并区间。给定区间集合 intervals，其中 intervals[i] = [start_i, end_i]，合并所有重叠的区间，返回不重叠的区间数组（按左端点排序后线性扫描）。输入：intervals = [[1,3],[2,6],[8,10],[15,18]]；输出：[[1,6],[8,10],[15,18]]。

**答案（Python 3）：**

```python
class Solution:
    # 按左端点排序后线性扫描：与上一合并区间重叠则延伸终点，否则新起一段
    def merge(self, intervals):
        intervals.sort(key=lambda x: x[0])
        res = []
        for start, end in intervals:
            if res and start <= res[-1][1]:      # 重叠：终点取较大值
                res[-1][1] = max(res[-1][1], end)
            else:
                res.append([start, end])
        return res
```

**解析：**
按左端点排序后线性扫描：当前起点 <= 上一合并区间的终点则合并（终点取 max），否则新起一段；O(n log n) 排序主导。


### Array-002-005 | ★★★★☆

接雨水。给定 n 个非负整数表示柱子高度图 [1,0,2,1,0,1,3,2,1,2,1]，计算按此顺序排列的柱子在下雨之后能接多少雨水。输入：height = [0,1,0,2,1,0,1,3,2,1,2,1]；输出：6。要求会双指针 O(n)/O(1) 与前后缀最大值两种解法。

**答案（Python 3）：**

```python
class Solution:
    # 解法一：双指针 O(n)/O(1)
    # 每格水位 = min(左边最大, 右边最大) - h；哪侧较矮，哪侧最大值就是瓶颈，结算哪侧
    def trap(self, height):
        l, r = 0, len(height) - 1
        lmax = rmax = 0
        ans = 0
        while l < r:
            if height[l] < height[r]:
                lmax = max(lmax, height[l])
                ans += lmax - height[l]
                l += 1
            else:
                rmax = max(rmax, height[r])
                ans += rmax - height[r]
                r -= 1
        return ans

    # 解法二：前后缀最大值 O(n)/O(n)，更好讲清原理
    def trap2(self, height):
        n = len(height)
        if n == 0:
            return 0
        pre = [0] * n
        suf = [0] * n
        pre[0] = height[0]
        suf[-1] = height[-1]
        for i in range(1, n):
            pre[i] = max(pre[i - 1], height[i])
        for i in range(n - 2, -1, -1):
            suf[i] = max(suf[i + 1], height[i])
        return sum(min(pre[i], suf[i]) - height[i] for i in range(n))
```

**解析：**
双指针 O(n)/O(1)：水位由较矮一侧的最大值决定，哪边矮结算哪边；前后缀解法：预计算 pre[i]、suf[i]，累加 min(pre,suf)-height[i]。


### Array-002-006 | ★★★★☆

盛最多水的容器。给定整数数组 height，第 i 条垂线位于 (i, 0) 到 (i, height[i])，与 x 轴共同构成容器，选两条线使容器容纳最多的水，返回最大水量。输入：height = [1,8,6,2,5,4,8,3,7]；输出：49。要求双指针收敛解法并证明正确性（移动较短的那一侧）。

**答案（Python 3）：**

```python
class Solution:
    # 双指针收敛 O(n)：面积 = 宽 * 短板高度
    # 正确性：固定短板一侧时，宽度变小、高度不会超过短板，不可能更优，
    # 所以每次移动较短的一侧不会漏掉最优解
    def maxArea(self, height):
        l, r, ans = 0, len(height) - 1, 0
        while l < r:
            ans = max(ans, (r - l) * min(height[l], height[r]))
            if height[l] < height[r]:
                l += 1
            else:
                r -= 1
        return ans
```

**解析：**
双指针从两端向内收敛，每次移动较短一侧：固定短板时宽度变小不可能更优，故不漏最优解；O(n)/O(1)。


### Array-002-007 | ★★★★☆

最大子数组和。给定整数数组 nums，找出具有最大和的连续子数组（至少包含一个元素），返回其最大和，并说出动态规划转移方程（dp[i] = max(nums[i], dp[i-1]+nums[i])）。输入：nums = [-2,1,-3,4,-1,2,1,-5,4]；输出：6（子数组 [4,-1,2,1] 的和）。追问：如果要求返回子数组本身怎么改。

**答案（Python 3）：**

```python
class Solution:
    # Kadane DP：dp[i] = max(nums[i], dp[i-1] + nums[i])，滚动成一维变量
    def maxSubArray(self, nums):
        ans = cur = nums[0]
        for x in nums[1:]:
            cur = max(x, cur + x)   # 前缀和为负则丢弃，从 x 重新开始
            ans = max(ans, cur)
        return ans

# 追问：返回子数组本身 —— cur < 0 时重置起点 start = i，更新答案时记录区间 [start, i]
def maxSubArrayWithIndices(nums):
    ans = cur = nums[0]
    start = bestL = bestR = 0
    for i in range(1, len(nums)):
        if cur < 0:
            cur, start = nums[i], i     # 重新开一段
        else:
            cur += nums[i]
        if cur > ans:
            ans, bestL, bestR = cur, start, i
    return ans, nums[bestL:bestR + 1]
```

**解析：**
Kadane：dp[i]=max(nums[i], dp[i-1]+nums[i])，滚动变量实现 O(n)/O(1)；返回子数组本身见注释——cur<0 时重置起点并记录最优区间端点。


### Array-002-008 | ★★★★☆

最长连续序列。给定未排序整数数组 nums，找出数字连续的最长序列的长度（序列元素在原数组中可以乱序），要求 O(n) 时间：用哈希集合，只从每个连续段起点（num-1 不在集合中）向后数。输入：nums = [100,4,200,1,3,2]；输出：4（[1,2,3,4]）。

**答案（Python 3）：**

```python
class Solution:
    # 哈希集合 O(n)：只从连续段起点（x-1 不在集合中）向后数段长，
    # 每个元素最多被内层再访问一次，总体 O(n)
    def longestConsecutive(self, nums):
        numSet = set(nums)
        ans = 0
        for x in numSet:
            if x - 1 not in numSet:     # x 是某连续段的起点
                y = x
                while y + 1 in numSet:
                    y += 1
                ans = max(ans, y - x + 1)
        return ans
```

**解析：**
哈希集合去重，只从连续段起点（x-1 不在集合）向后数长度，每个元素至多被访问两次；O(n)/O(n)。


### Array-002-009 | ★★★★☆

缺失的第一个正数。给定未排序整数数组 nums，找出其中没有出现的最小正整数，要求时间 O(n)、空间 O(1)：把每个值 v 放到下标 v-1 的位置（原地哈希/置换），再扫描第一个 nums[i] != i+1 的位置。输入：nums = [3,4,-1,1]；输出：2。

**答案（Python 3）：**

```python
class Solution:
    # 原地哈希：把值 v(1<=v<=n) 交换到下标 v-1，每个值最多被换到位一次，均摊 O(n)/O(1)
    def firstMissingPositive(self, nums):
        n = len(nums)
        for i in range(n):
            # 当前位置的值应放到 nums[i]-1 处；目标位置已放对则停止交换
            while 1 <= nums[i] <= n and nums[nums[i] - 1] != nums[i]:
                j = nums[i] - 1
                nums[i], nums[j] = nums[j], nums[i]
        for i in range(n):
            if nums[i] != i + 1:
                return i + 1
        return n + 1        # 1..n 全在，答案是 n+1
```

**解析：**
原地哈希：把落在 [1,n] 的值 v 交换到下标 v-1（目标位已正确则停），再扫第一个 nums[i]!=i+1 的位置；均摊 O(n)/O(1)。


### Array-002-010 | ★★★★☆

下一个排列。给定整数数组 nums，将它们重新排列成字典序的下一个排列；不存在更大排列时重排为最小排列（升序）。要求原地修改、只使用常数额外空间：从右找第一个升序对，再找其后最小的大数交换，最后反转后缀。输入：nums = [1,2,3]；输出：[1,3,2]。输入：nums = [3,2,1]；输出：[1,2,3]。

**答案（Python 3）：**

```python
class Solution:
    # 三步：1) 从右找第一个升序对 (i, i+1)；2) 其后从右找最后一个大于 nums[i] 的数交换；
    # 3) 反转原降序后缀使其变最小升序。无升序对说明整体降序，直接反转成最小排列。O(n)
    def nextPermutation(self, nums):
        n = len(nums)
        i = n - 2
        while i >= 0 and nums[i] >= nums[i + 1]:
            i -= 1
        if i >= 0:
            j = n - 1
            while nums[j] <= nums[i]:   # 从右往左第一个大于 nums[i] 的即最小的大数
                j -= 1
            nums[i], nums[j] = nums[j], nums[i]
        l, r = i + 1, n - 1             # 后缀此时必为降序，反转即最小化
        while l < r:
            nums[l], nums[r] = nums[r], nums[l]
            l += 1
            r -= 1
```

**解析：**
从右找第一个升序对 (i,i+1)，在其后从右找最后一个大于 nums[i] 的数交换，再反转原降序后缀；无升序对则整体反转成最小排列。原地 O(n)。


### Array-002-011 | ★★★★☆

螺旋矩阵。给定 m x n 矩阵 matrix，按顺时针螺旋顺序返回所有元素。输入：matrix = [[1,2,3],[4,5,6],[7,8,9]]；输出：[1,2,3,6,9,8,7,4,5]。要求用上下左右四个边界收缩的写法，注意处理单行/单列的边界重复问题。

**答案（Python 3）：**

```python
class Solution:
    # 四边界收缩：每圈走 上行 -> 右列 -> 下行 -> 左列；
    # 走下行/左列前判断 top<bottom、left<right，防止单行单列时重复收集。O(mn)
    def spiralOrder(self, matrix):
        top, bottom = 0, len(matrix) - 1
        left, right = 0, len(matrix[0]) - 1
        res = []
        while top <= bottom and left <= right:
            for j in range(left, right + 1):        # 上行：左->右
                res.append(matrix[top][j])
            for i in range(top + 1, bottom + 1):    # 右列：上->下
                res.append(matrix[i][right])
            if top < bottom:                        # 不止一行才走下行
                for j in range(right - 1, left - 1, -1):
                    res.append(matrix[bottom][j])
            if left < right:                        # 不止一列才走左列
                for i in range(bottom - 1, top, -1):
                    res.append(matrix[i][left])
            top += 1
            bottom -= 1
            left += 1
            right -= 1
        return res
```

**解析：**
top/bottom/left/right 四边界收缩，每圈按上行→右列→下行→左列收集；下行、左列前分别判断 top<bottom、left<right 防单行/单列重复。O(mn)。


### Array-002-012 | ★★★★☆

和为 K 的子数组。给定整数数组 nums 和整数 k，统计并返回该数组中和恰好为 k 的连续子数组的个数（前缀和 + 哈希表记录前缀和出现次数）。输入：nums = [1,1,1], k = 2；输出：2。约束：1 <= n <= 2*10^4，元素可为负数（所以不能用滑动窗口）。

**答案（Python 3）：**

```python
from collections import defaultdict

class Solution:
    # 前缀和 + 哈希：以 i 结尾、和为 k 的子数组个数 = 前缀和等于 pre-k 的出现次数
    # 元素可为负（前缀和不单调），不能用滑动窗口。O(n)
    def subarraySum(self, nums, k):
        cnt = defaultdict(int)
        cnt[0] = 1                  # 空前缀，覆盖从头开始的子数组
        pre = ans = 0
        for x in nums:
            pre += x
            ans += cnt[pre - k]     # 先统计再登记，避免 [.., i] 自身被计入
            cnt[pre] += 1
        return ans
```

**解析：**
前缀和 + 哈希计数：cnt[pre-k] 就是以当前元素结尾且和为 k 的子数组数，先统计后登记且 cnt[0]=1；元素可为负不能用滑动窗口。O(n)。


### Array-002-013 | ★★★★☆

移动零。给定数组 nums，编写函数将所有 0 移动到数组末尾，同时保持非零元素的相对顺序，要求原地操作、尽量减少操作次数（快慢指针原地交换）。输入：[0,1,0,3,12]；输出：[1,3,12,0,0]。

**答案（Python 3）：**

```python
class Solution:
    # 快慢指针：slow 左侧始终是保持原序的非零前缀，遇非零即交换，0 自然沉到后部
    def moveZeroes(self, nums):
        slow = 0
        for fast in range(len(nums)):
            if nums[fast] != 0:
                nums[slow], nums[fast] = nums[fast], nums[slow]
                slow += 1
```

**解析：**
快慢指针：slow 左侧恒为保持原序的非零前缀，遇非零即与 slow 交换，0 自然被换到后部；原地 O(n)，交换次数即非零元素个数。


### Array-002-014 | ★★★★☆

手撕快速排序。给定整数数组 nums，请将其按升序排序（手写快速排序，不得直接调用语言内置排序）。要求：随机选取 pivot 防止退化、会写 partition（挖坑法或交换法），说明平均 O(n log n)、最坏 O(n^2) 的复杂度，并能口述如何优化（三路划分/随机化/递归深度过大转堆排）。输入：nums = [5,2,3,1]；输出：[1,2,3,5]。

**答案（Python 3）：**

```python
import random

class Solution:
    # 手撕快排：平均 O(n log n)，最坏 O(n^2)（随机化后概率极低）
    # 优化：随机 pivot / 三路划分（大量重复元素）/ 递归过深转堆排序
    def sortArray(self, nums):
        self._quickSort(nums, 0, len(nums) - 1)
        return nums

    def _quickSort(self, nums, l, r):
        if l >= r:
            return
        p = self._partition(nums, l, r)
        self._quickSort(nums, l, p - 1)
        self._quickSort(nums, p + 1, r)

    # 挖坑法 partition：返回 pivot 最终位置（左侧都 <= pivot，右侧都 >= pivot）
    def _partition(self, nums, l, r):
        k = random.randint(l, r)                    # 随机选 pivot 防有序输入退化
        nums[l], nums[k] = nums[k], nums[l]
        pivot = nums[l]                             # 首位挖坑
        while l < r:
            while l < r and nums[r] >= pivot:       # 从右找小的填左坑
                r -= 1
            nums[l] = nums[r]
            while l < r and nums[l] <= pivot:       # 从左找大的填右坑
                l += 1
            nums[r] = nums[l]
        nums[l] = pivot                             # pivot 归位
        return l
```

**解析：**
挖坑法 partition + 随机 pivot（与首位交换）防有序输入退化；平均 O(n log n)、最坏 O(n^2)，可继续说三路划分、递归过深转堆排。


### Array-002-015 | ★★★★☆

手撕归并排序。给定整数数组 nums，请用归并排序将其按升序排序（不得调用内置排序）。要求写出递归二分 + merge 合并两个有序子数组的过程，说明时间 O(n log n)、空间 O(n)，并能解释为什么归并排序是稳定排序，以及链表排序为什么优先用归并。

**答案（Python 3）：**

```python
class Solution:
    # 归并排序：递归二分 + merge，时间 O(n log n)，空间 O(n) 辅助数组 + O(log n) 栈
    # 稳定性：merge 相等元素先取左侧（<=），相对顺序不变；
    # 链表排序优先归并：无需随机访问、可 O(1) 断链找中点、合并只改指针不需额外空间
    def sortArray(self, nums):
        tmp = [0] * len(nums)
        self._mergeSort(nums, 0, len(nums) - 1, tmp)
        return nums

    def _mergeSort(self, nums, l, r, tmp):
        if l >= r:
            return
        m = (l + r) // 2
        self._mergeSort(nums, l, m, tmp)
        self._mergeSort(nums, m + 1, r, tmp)
        # merge 两个有序段 [l,m] 与 [m+1,r]
        i, j, k = l, m + 1, l
        while i <= m and j <= r:
            if nums[i] <= nums[j]:      # 取等号 -> 稳定排序
                tmp[k] = nums[i]
                i += 1
            else:
                tmp[k] = nums[j]
                j += 1
            k += 1
        while i <= m:
            tmp[k] = nums[i]
            i += 1
            k += 1
        while j <= r:
            tmp[k] = nums[j]
            j += 1
            k += 1
        nums[l:r + 1] = tmp[l:r + 1]
```

**解析：**
递归二分 + merge，辅助数组一次申请复用，O(n log n)/O(n)；merge 相等先取左保证稳定，链表无需随机访问且合并只改指针，故链表排序优先归并。

