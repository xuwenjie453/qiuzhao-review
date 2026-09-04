### DynamicProgramming-002-001 | ★★★★☆

最长递增子序列。给定整数数组 nums，找出其中最长严格递增子序列的长度。要求会 O(n^2) DP（dp[i] 为以 i 结尾的 LIS 长度）和 O(n log n) 贪心+二分（维护 tails 数组）两种写法。输入：nums = [10,9,2,5,3,7,101,18]；输出：4（最长递增子序列为 [2,3,7,101] 或 [2,5,7,101] 等）。

**答案（Python 3）：**

```python
from bisect import bisect_left

class Solution:
    # 解法一：O(n^2) DP，dp[i] = 以 nums[i] 结尾的最长递增子序列长度
    def lengthOfLIS(self, nums):
        n = len(nums)
        dp = [1] * n
        for i in range(n):
            for j in range(i):
                if nums[j] < nums[i]:
                    dp[i] = max(dp[i], dp[j] + 1)
        return max(dp)

    # 解法二：O(n log n) 贪心 + 二分，tails[t] = 长度为 t+1 的 LIS 的最小可能尾元素
    def lengthOfLISBin(self, nums):
        tails = []
        for x in nums:
            pos = bisect_left(tails, x)     # 严格递增用 bisect_left（相等也替换、不延长）
            if pos == len(tails):
                tails.append(x)             # x 比所有尾都大，LIS 长度 +1
            else:
                tails[pos] = x              # 用更小的 x 替换，让后续更容易接上
        return len(tails)

# 验证：[10,9,2,5,3,7,101,18] -> 4（如 [2,5,7,101]）
```

**解析：**
DP 解法 O(n^2)：以每个位置结尾取前面更小值的最优解 +1；贪心+二分 O(n log n)：tails 保持同长度 LIS 的最小尾，bisect_left 保证严格递增。


### DynamicProgramming-002-002 | ★★★★☆

买卖股票的最佳时机。给定数组 prices，prices[i] 是股票第 i 天的价格，只能完成一笔交易（买入和卖出各一次），求最大利润；无法获利返回 0。要求 O(n) 一遍扫描，维护历史最低价。输入：prices = [7,1,5,3,6,4]；输出：5（第 2 天买入第 5 天卖出）。追问扩展到可多次交易（贪心收集所有上涨段）与限制两次交易（前后缀 DP）的写法。

**答案（Python 3）：**

```python
class Solution:
    def maxProfit(self, prices):
        '''一次买卖：一遍扫描维护历史最低价，O(n) 时间 O(1) 空间'''
        min_price = float('inf')
        profit = 0
        for p in prices:
            if p < min_price:
                min_price = p                       # 更新历史最低买入价
            elif p - min_price > profit:
                profit = p - min_price              # 尝试今天卖出
        return profit

# 追问一：可多次交易 -> 贪心收集所有上涨段（等价于每天都可买卖）
def maxProfitMulti(prices):
    return sum(max(0, prices[i] - prices[i - 1]) for i in range(1, len(prices)))

# 追问二：限制两次交易 -> 前后缀 DP：forward[i] 前 i 天一笔交易的最大利润，
# backward[i] 从第 i 天起一笔交易的最大利润，答案 = max(forward[i] + backward[i+1])
def maxProfitTwo(prices):
    n = len(prices)
    forward = [0] * n
    min_p = prices[0]
    for i in range(1, n):
        min_p = min(min_p, prices[i])
        forward[i] = max(forward[i - 1], prices[i] - min_p)
    backward = [0] * (n + 1)
    max_p = prices[-1]
    for i in range(n - 2, -1, -1):
        max_p = max(max_p, prices[i])
        backward[i] = max(backward[i + 1], max_p - prices[i])
    return max(forward[i] + backward[i + 1] for i in range(n))

# 验证：[7,1,5,3,6,4] -> 5；maxProfitTwo 同输入 -> 7（1买5卖 + 3买6卖）
```

**解析：**
主解法一遍扫描维护历史最低价、每天尝试卖出，O(n)/O(1)；多次交易用贪心收集全部正差价，限两次交易用前后缀 DP 在分割点拼接两笔。


### DynamicProgramming-002-003 | ★★★★☆

零钱兑换。给定不同面额硬币数组 coins 和总金额 amount，计算凑成总金额所需的最少硬币个数；无法凑出返回 -1，每种硬币数量无限，要求 O(amount * coins) 的完全背包 DP：dp[i] = min(dp[i-c]+1)。输入：coins = [1,2,5], amount = 11；输出：3（5+5+1）。

**答案（Python 3）：**

```python
class Solution:
    def coinChange(self, coins, amount):
        '''完全背包：dp[i] = 凑出金额 i 的最少硬币数，O(amount * len(coins))'''
        dp = [float('inf')] * (amount + 1)
        dp[0] = 0                           # 金额 0 不需要硬币
        for c in coins:
            for i in range(c, amount + 1):  # 正序遍历：每种硬币可重复使用
                if dp[i - c] + 1 < dp[i]:
                    dp[i] = dp[i - c] + 1   # 转移：dp[i] = min(dp[i-c] + 1)
        return -1 if dp[amount] == float('inf') else dp[amount]

# 验证：coins=[1,2,5], amount=11 -> 3（5+5+1）
```

**解析：**
完全背包一维写法：外层硬币、内层金额正序（正序即允许重复选取），dp[i] 取所有 dp[i-c]+1 的最小；时间 O(amount×硬币种数)、空间 O(amount)。


### DynamicProgramming-002-004 | ★★★★☆

打家劫舍。给定非负整数数组 nums 代表每间房屋的现金，相邻两间不能同时偷，求能偷到的最高金额：dp[i] = max(dp[i-1], dp[i-2]+nums[i])，可用滚动变量 O(1) 空间。输入：nums = [2,7,9,3,1]；输出：12（偷 2、9、1）。

**答案（Python 3）：**

```python
class Solution:
    def rob(self, nums):
        '''打家劫舍：dp[i] = max(dp[i-1], dp[i-2] + nums[i])，滚动变量 O(1) 空间'''
        prev, cur = 0, 0        # prev = dp[i-2]，cur = dp[i-1]
        for x in nums:
            # 不偷 i：维持 dp[i-1]；偷 i：dp[i-2] + x
            prev, cur = cur, max(cur, prev + x)
        return cur

# 验证：[2,7,9,3,1] -> 12（偷 2、9、1）
```

**解析：**
相邻两间不能同偷，状态只依赖前两项，用两个滚动变量迭代即可：cur=max(不偷, 偷当前+前前)；时间 O(n)、空间 O(1)。


### DynamicProgramming-002-005 | ★★★★☆

最小路径和。给定 m x n 网格 grid，每个格子含非负整数，从左上角走到右下角（每步只能向下或向右），使路径上数字总和最小，返回最小路径和，要求会 O(n) 空间滚动数组优化。输入：grid = [[1,3,1],[1,5,1],[4,2,1]]；输出：7（1→3→1→1→1）。

**答案（Python 3）：**

```python
class Solution:
    def minPathSum(self, grid):
        '''最小路径和：dp[i][j] = min(上, 左) + grid[i][j]，滚动数组 O(n) 空间'''
        m, n = len(grid), len(grid[0])
        dp = [0] * n
        dp[0] = grid[0][0]
        for j in range(1, n):               # 初始化第一行：只能从左来
            dp[j] = dp[j - 1] + grid[0][j]
        for i in range(1, m):
            dp[0] += grid[i][0]             # 第一列只能从上来
            for j in range(1, n):
                # 滚动更新：dp[j] 旧值代表上方，dp[j-1] 新值代表左方
                dp[j] = min(dp[j], dp[j - 1]) + grid[i][j]
        return dp[-1]

# 验证：[[1,3,1],[1,5,1],[4,2,1]] -> 7（1→3→1→1→1）
```

**解析：**
每格只能来自上或左，用一维滚动数组逐行覆盖：更新前 dp[j] 是上方、dp[j-1] 已是本行左方；时间 O(mn)、空间 O(n)。


### DynamicProgramming-002-006 | ★★★★☆

最长公共子序列。给定两个字符串 text1 和 text2，返回它们最长公共子序列的长度；不存在返回 0。转移方程：字符相等 dp[i][j] = dp[i-1][j-1]+1，否则取 max(dp[i-1][j], dp[i][j-1])。输入：text1 = "abcde", text2 = "ace"；输出：3（"ace"）。追问：如何还原出这个子序列本身（回溯 DP 表）。

**答案（Python 3）：**

```python
class Solution:
    def longestCommonSubsequence(self, text1, text2):
        '''LCS：dp[i][j] = text1 前 i 个字符与 text2 前 j 个字符的 LCS 长度'''
        m, n = len(text1), len(text2)
        dp = [[0] * (n + 1) for _ in range(m + 1)]
        for i in range(1, m + 1):
            for j in range(1, n + 1):
                if text1[i - 1] == text2[j - 1]:
                    dp[i][j] = dp[i - 1][j - 1] + 1     # 尾字符相等，接上左上角
                else:
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
        return dp[m][n]

# 追问：回溯 DP 表还原子序列本身，时间 O(m+n)
def get_lcs_text(text1, text2):
    m, n = len(text1), len(text2)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if text1[i - 1] == text2[j - 1]:
                dp[i][j] = dp[i - 1][j - 1] + 1
            else:
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
    res = []
    i, j = m, n
    while i > 0 and j > 0:                  # 从右下角往回走
        if text1[i - 1] == text2[j - 1]:
            res.append(text1[i - 1])        # 字符相等处一定是 LCS 的一员
            i -= 1
            j -= 1
        elif dp[i - 1][j] >= dp[i][j - 1]:
            i -= 1                          # 否则朝值更大的子状态回退
        else:
            j -= 1
    return ''.join(reversed(res))

# 验证：'abcde' 与 'ace' -> 3，还原得 'ace'
```

**解析：**
经典二维 DP：字符相等取左上 +1，否则取上/左的较大值，时间 O(mn)；还原时从 dp[m][n] 回溯，相等字符收集、否则向值更大的方向移动，最后反转。


### DynamicProgramming-002-007 | ★★★★☆

单词拆分。给定字符串 s 和单词字典 wordDict（可重复使用），判断 s 是否可以拆分成一个或多个字典中出现的单词：dp[i] 表示前 i 个字符可被拆分，枚举分割点。输入：s = "leetcode", wordDict = ["leet","code"]；输出：true。输入：s = "catsandog", wordDict = ["cats","dog","sand","and","cat"]；输出：false。

**答案（Python 3）：**

```python
class Solution:
    def wordBreak(self, s, wordDict):
        '''单词拆分：dp[i] = 前 i 个字符能否被字典拆分'''
        words = set(wordDict)               # 哈希集合，子串查找 O(1)
        n = len(s)
        dp = [False] * (n + 1)
        dp[0] = True                        # 边界：空串视为可拆分
        for i in range(1, n + 1):
            for j in range(i):              # 枚举分割点：最后一个单词为 s[j:i]
                if dp[j] and s[j:i] in words:
                    dp[i] = True
                    break                   # 找到一种拆法即可
        return dp[n]

# 验证：s='leetcode', dict=['leet','code'] -> True；s='catsandog' -> False
```

**解析：**
dp[i] 表示前 i 个字符可被拆分，枚举分割点 j：dp[j] 为真且 s[j:i] 在字典中则 dp[i]=True；时间 O(n^2)（配合字典单词长度剪枝内层更优）。

