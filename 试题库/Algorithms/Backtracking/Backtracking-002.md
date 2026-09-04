### Backtracking-002-001 | ★★★★☆

全排列。给定不含重复数字的整数数组 nums，返回其所有可能的全排列，按任意顺序返回，要求现场写回溯：用 used 数组标记 + 逐位选择。输入：nums = [1,2,3]；输出：[[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]。追问：数组有重复元素时如何去重（排序后同层剪枝）。

**答案（Python 3）：**

```python
class Solution:
    def permute(self, nums):
        '''全排列：used 数组标记 + 逐位选择的回溯模板'''
        res, path, used = [], [], [False] * len(nums)

        def backtrack():
            if len(path) == len(nums):      # 排列填满，收集答案
                res.append(path[:])
                return
            for i in range(len(nums)):
                if used[i]:
                    continue
                used[i] = True              # 做选择
                path.append(nums[i])
                backtrack()
                path.pop()                  # 撤销选择（回溯）
                used[i] = False

        backtrack()
        return res

# 追问：数组含重复元素时的去重写法：先排序 + 同层剪枝
def permute_unique(nums):
    nums.sort()
    res, path, used = [], [], [False] * len(nums)

    def backtrack():
        if len(path) == len(nums):
            res.append(path[:])
            return
        for i in range(len(nums)):
            if used[i]:
                continue
            # 同层剪枝：与前一个值相同且前一个在本层未被使用，跳过以避免重复排列
            if i > 0 and nums[i] == nums[i - 1] and not used[i - 1]:
                continue
            used[i] = True
            path.append(nums[i])
            backtrack()
            path.pop()
            used[i] = False

    backtrack()
    return res

# 验证：permute([1,2,3]) -> 6 个排列
```

**解析：**
回溯模板：每层扫描未使用元素，选入-递归-撤销，时间 O(n×n!)；重复元素去重靠排序 + 同层剪枝（nums[i]==nums[i-1] 且 used[i-1]==False 时跳过）。


### Backtracking-002-002 | ★★★★☆

组合总和。给定无重复元素的正整数数组 candidates 和目标整数 target，找出所有和为 target 的组合，同一个数字可以无限制重复选取，且组合内部按非递减顺序，答案不能有重复组合。输入：candidates = [2,3,6,7], target = 7；输出：[[7],[2,2,3]]。要求回溯 + 剪枝（先排序，剩余目标小于当前候选数时剪掉）。

**答案（Python 3）：**

```python
class Solution:
    def combinationSum(self, candidates, target):
        '''组合总和：回溯 + 剪枝，排序后剩余目标不足当前候选数即可 break'''
        candidates.sort()
        res, path = [], []

        def backtrack(start, remain):
            if remain == 0:                 # 凑满，收集组合
                res.append(path[:])
                return
            for i in range(start, len(candidates)):
                if candidates[i] > remain:  # 剪枝：后面更大，直接结束本层
                    break
                path.append(candidates[i])
                backtrack(i, remain - candidates[i])   # 传 i 不是 i+1：同一数字可重复选
                path.pop()

        backtrack(0, target)
        return res

# 验证：candidates=[2,3,6,7], target=7 -> [[2,2,3],[7]]
```

**解析：**
start 参数使组合内部按非递减顺序、结果不重复；递归传 i 允许重复选取同一数字；排序后 remain 小于当前候选即 break 剪枝。


### Backtracking-002-003 | ★★★★☆

子集。给定整数数组 nums（元素互不相同），返回该数组所有可能的子集（幂集），解集不能包含重复的子集。输入：nums = [1,2,3]；输出：[[],[1],[1,2],[1,2,3],[1,3],[2],[2,3],[3]]。要求回溯标准模板，并能口述迭代法与位枚举法。

**答案（Python 3）：**

```python
class Solution:
    def subsets(self, nums):
        '''子集（幂集）：回溯标准模板，回溯树上的每个节点都是一个子集'''
        res, path = [], []

        def backtrack(start):
            res.append(path[:])             # 进入递归先收集当前子集
            for i in range(start, len(nums)):
                path.append(nums[i])        # start 保证只往后选，避免重复子集
                backtrack(i + 1)
                path.pop()

        backtrack(0)
        return res

# 口述版一（迭代法）：res=[[]]，每来一个元素 x，把 res 中现有子集都拼上 x 后加入 res
#   for x in nums: res += [sub + [x] for sub in res]
# 口述版二（位枚举法）：枚举 mask 属于 [0, 2^n)，第 j 位为 1 就选 nums[j]，共 2^n 个子集

# 验证：[1,2,3] -> 8 个子集
```

**解析：**
回溯树每个节点即一个子集，start 控制下标递增避免重复，共 2^n 个子集、时间 O(2^n×n)；迭代法逐元素扩张解集，位枚举法用 mask 直接映射子集。

