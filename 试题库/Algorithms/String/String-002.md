### String-002-001 | ★★★★☆

字符串相加（大数加法）。给定两个仅由数字组成的非空字符串 num1、num2（不含有前导零，数值可达上千位，不能用 BigInteger/直接转 int），计算它们的和并同样以字符串形式返回。输入：num1 = "456", num2 = "77"；输出："533"。要求双指针从末位开始模拟竖式加法 + 进位。

**答案（Python 3）：**

```python
class Solution:
    # 双指针从两串末位对齐做竖式加法，divmod 拆进位/本位；O(max(m,n))
    def addStrings(self, num1: str, num2: str) -> str:
        i, j, carry = len(num1) - 1, len(num2) - 1, 0
        res = []
        while i >= 0 or j >= 0 or carry:
            d = carry
            if i >= 0:
                d += ord(num1[i]) - ord('0')
                i -= 1
            if j >= 0:
                d += ord(num2[j]) - ord('0')
                j -= 1
            carry, d = divmod(d, 10)
            res.append(str(d))
        return ''.join(reversed(res))
```

**解析：**
双指针从两串末位对齐模拟竖式加法，divmod 拆进位/本位，循环条件带 carry；O(max(m,n))，全程不转 int。


### String-002-002 | ★★★★☆

36 进制加法（字节补充真题）。给定两个 36 进制的字符串数字 a 和 b（字符 0-9 表示 0-9，a-z 表示 10-35），返回它们相加结果的 36 进制字符串表示。示例：a = "1b"（即 10 进制的 47），b = "z"（即 35），和为 82，10 进制 82 = 2*36+10，输出 "2a"。要求：实现任意进制（如 2~36 进制）的两数相加，逐位相加带进位，注意进位可能超过当前进制。

**答案（Python 3）：**

```python
class Solution:
    DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"   # 0-35

    # 通用 base(2~36) 进制加法：逐位相加后 divmod(d, base) 得进位与本位
    def add36Strings(self, a: str, b: str, base: int = 36) -> str:
        i, j, carry = len(a) - 1, len(b) - 1, 0
        res = []
        while i >= 0 or j >= 0 or carry:
            d = carry
            if i >= 0:
                d += self._val(a[i])
                i -= 1
            if j >= 0:
                d += self._val(b[j])
                j -= 1
            carry, d = divmod(d, base)      # 商为进位，余数为本位（进位可再触发进位）
            res.append(self.DIGITS[d])
        return ''.join(reversed(res)) or "0"

    @staticmethod
    def _val(c: str) -> int:
        return int(c, 36)   # '0'-'9' -> 0-9，'a'-'z' -> 10-35
```

**解析：**
通用 2~36 进制加法：字符值用 int(c,36) 还原，逐位相加后 divmod(d, base) 得进位与本位，进位可能超过当前进制由 divmod 自然处理；O(max(m,n))。


### String-002-003 | ★★★★☆

字符串转换整数 (atoi)。实现一个 myAtoi(string s) 函数：丢弃前导空格；检查正负号；读取数字字符直到非数字字符或结尾；数字超出 32 位有符号整数范围 [-2^31, 2^31-1] 时截断为 INT_MIN 或 INT_MAX；返回最终整数。输入：s = " -42"；输出：-42。输入：s = "4193 with words"；输出：4193。要求现场处理好各种边界。

**答案（Python 3）：**

```python
class Solution:
    # 四步：去前导空格 -> 取一次正负号 -> 读连续数字 -> 边累加边对 32 位边界截断
    def myAtoi(self, s: str) -> int:
        INT_MAX, INT_MIN = 2**31 - 1, -2**31
        i, n = 0, len(s)
        while i < n and s[i] == ' ':                 # 1. 丢弃前导空格
            i += 1
        sign = 1
        if i < n and (s[i] == '+' or s[i] == '-'):   # 2. 正负号（只取一个）
            if s[i] == '-':
                sign = -1
            i += 1
        num = 0
        while i < n and '0' <= s[i] <= '9':          # 3. 读连续数字
            num = num * 10 + ord(s[i]) - ord('0')
            if sign * num > INT_MAX:                 # 4. 越界提前截断
                return INT_MAX
            if sign * num < INT_MIN:
                return INT_MIN
            i += 1
        return sign * num
```

**解析：**
按四步模拟：去前导空格、取一次正负号、读连续数字、边累加边与 [-2^31, 2^31-1] 比较提前截断；重点在 '+-12'、'  -0012'、越界等边界。


### String-002-004 | ★★★★☆

最长回文子串。给定字符串 s，返回 s 中最长的回文子串。输入：s = "babad"；输出："bab"（"aba" 同样正确）。要求会中心扩展法 O(n^2)/O(1)，并能口述 Manacher 的思路作为加分项。

**答案（Python 3）：**

```python
class Solution:
    # 中心扩展：枚举 2n-1 个中心（奇/偶）向两边扩，O(n^2)/O(1)
    # Manacher 思路（加分）：插 '#' 统一奇偶长度，利用已算回文半径的镜像性质把中心右推到 O(n)
    def longestPalindrome(self, s: str) -> str:
        start, end = 0, 0

        def expand(l, r):           # 返回从中心扩展出的回文 [l+1, r-1] 边界
            while l >= 0 and r < len(s) and s[l] == s[r]:
                l -= 1
                r += 1
            return l + 1, r - 1

        for i in range(len(s)):
            for l, r in (expand(i, i), expand(i, i + 1)):   # 奇、偶两种中心
                if r - l > end - start:
                    start, end = l, r
        return s[start:end + 1]
```

**解析：**
中心扩展：枚举奇/偶 2n-1 个中心向两边扩，O(n^2)/O(1)；Manacher 加分思路：插 '#' 统一奇偶、利用回文半径镜像性质把中心右推到 O(n)。


### String-002-005 | ★★★★☆

编辑距离。给定两个单词 word1 和 word2，返回将 word1 转换成 word2 所需的最少操作数，允许的操作为插入、删除、替换一个字符。输入：word1 = "horse", word2 = "ros"；输出：3。要求写 O(mn) 的二维 DP 并说清转移方程：dp[i][j] = min(dp[i-1][j]+1, dp[i][j-1]+1, dp[i-1][j-1]+(s1[i]!=s2[j]))。

**答案（Python 3）：**

```python
class Solution:
    # dp[i][j]：word1 前 i 个字符 -> word2 前 j 个字符的最小操作数
    # 相同：dp[i][j]=dp[i-1][j-1]；不同：1 + min(删 dp[i-1][j], 插 dp[i][j-1], 换 dp[i-1][j-1])
    def minDistance(self, word1: str, word2: str) -> int:
        m, n = len(word1), len(word2)
        dp = [[0] * (n + 1) for _ in range(m + 1)]
        for i in range(m + 1):
            dp[i][0] = i            # 全部删除
        for j in range(n + 1):
            dp[0][j] = j            # 全部插入
        for i in range(1, m + 1):
            for j in range(1, n + 1):
                if word1[i - 1] == word2[j - 1]:
                    dp[i][j] = dp[i - 1][j - 1]
                else:
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
        return dp[m][n]
```

**解析：**
二维 DP：字符相同取 dp[i-1][j-1]，否则 1+min(删 dp[i-1][j], 插 dp[i][j-1], 换 dp[i-1][j-1])，边界 dp[i][0]=i、dp[0][j]=j；O(mn)，可滚动数组优化到 O(n) 空间。


### String-002-006 | ★★★★☆

最小覆盖子串。给定字符串 s 和 t，返回 s 中涵盖 t 所有字符（含重复字符）的最小子串，不存在返回空串。输入：s = "ADOBECODEBANC", t = "ABC"；输出："BANC"。要求滑动窗口 + 哈希计数 O(|s|+|t|)，现场写清楚 need/window 两个计数表和收缩条件。

**答案（Python 3）：**

```python
from collections import Counter

class Solution:
    # 滑动窗口 O(|s|+|t|)：need 记 t 的字符需求，window 记窗口计数，
    # missing 记还缺的字符个数；missing==0 时收缩 left 到恰好不覆盖，途中更新最优窗口
    def minWindow(self, s: str, t: str) -> str:
        need = Counter(t)
        window = {}
        missing = len(t)                # 按个数计的缺口
        bestL, bestR = 0, float('inf')  # 最优窗口 [bestL, bestR)
        left = 0
        for right, c in enumerate(s, 1):
            if c in need:
                window[c] = window.get(c, 0) + 1
                if window[c] <= need[c]:
                    missing -= 1
            while missing == 0:         # 已覆盖，尽量收缩
                if right - left < bestR - bestL:
                    bestL, bestR = left, right
                d = s[left]
                if d in need:
                    window[d] -= 1
                    if window[d] < need[d]:
                        missing += 1    # 移出后不再覆盖，停止收缩
                left += 1
        return "" if bestR == float('inf') else s[bestL:bestR]
```

**解析：**
滑动窗口：need/window 两张计数表 + missing（还缺的字符个数），右扩张时只统计 need 中字符，missing==0 时收缩左端并更新最优窗口；O(|s|+|t|)。


### String-002-007 | ★★★★☆

复原 IP 地址（字节 C++ 二面真题原题描述：给你一个字符串例如 "192168101"，划分成合法的 IP 地址，输出所有情况）。给定一个仅由数字组成的字符串 s，向其中插入三个点将其还原为四个合法的 IPv4 段，返回所有可能的 IP 地址；每段 0~255 且不能有前导零（"01" 非法），s 长度不超过 12，用 DFS 回溯枚举所有切分点。输入：s = "25525511135"；输出：["255.255.11.135","255.255.111.35"]。

**答案（Python 3）：**

```python
class Solution:
    # DFS 回溯枚举三个切分点：每段校验 0~255 且无前导零；
    # 剪枝：剩余字符数必须介于 [剩余段数, 剩余段数*3]
    def restoreIpAddresses(self, s: str):
        res = []

        def valid(seg):
            return seg and (seg == "0" or (seg[0] != "0" and int(seg) <= 255))

        def dfs(start, parts):
            if len(parts) == 4:
                if start == len(s):
                    res.append(".".join(parts))
                return
            need = 4 - len(parts)
            if not (need <= len(s) - start <= need * 3):
                return
            for l in range(1, 4):           # 每段长 1~3
                seg = s[start:start + l]
                if valid(seg):
                    parts.append(seg)
                    dfs(start + l, parts)
                    parts.pop()

        dfs(0, [])
        return res
```

**解析：**
DFS 回溯枚举三个切分点，每段校验 0~255 且无前导零（'0' 单独合法、'01' 非法），并用剩余长度剪枝（剩余段数 ≤ 剩余字符数 ≤ 段数*3）；n≤12 状态极小。


### String-002-008 | ★★★★☆

最长有效括号。给定只含 '(' 和 ')' 的字符串 s，找出最长的格式正确且连续的有效括号子串的长度。输入：s = "()(())"；输出：6。输入：s = ")()())"；输出：4。要求至少会一种 O(n) 解法（栈存下标 或 正反两次扫描计数）。

**答案（Python 3）：**

```python
class Solution:
    # 栈存下标 O(n)：栈底始终是“最后一个无法匹配的位置”；
    # 遇 ')' 弹栈后：栈空说明当前 ')' 无法匹配，重置基准；否则 i - 栈顶 即当前有效长度
    def longestValidParentheses(self, s: str) -> int:
        stack = [-1]
        ans = 0
        for i, c in enumerate(s):
            if c == '(':
                stack.append(i)
            else:
                stack.pop()
                if not stack:
                    stack.append(i)         # 无法匹配，更新基准下标
                else:
                    ans = max(ans, i - stack[-1])
        return ans
```

**解析：**
栈存下标，栈底永远存最后一个无法匹配的位置：')' 弹栈后若栈空则重置基准，否则 i-stack[-1] 即以 i 结尾的有效长度；O(n)/O(n)。


### String-002-009 | ★★★★☆

有效的括号。给定一个只包括 '('、')'、'{'、'}'、'['、']' 的字符串 s，判断字符串是否有效：左括号必须用相同类型的右括号闭合，且必须以正确的顺序闭合，返回布尔值，用栈解决。输入：s = "()[]{}"；输出：true。输入：s = "([)]"；输出：false。

**答案（Python 3）：**

```python
class Solution:
    # 栈：遇右括号时栈顶必须是其配对的左括号；结束时栈空即有效。O(n)
    def isValid(self, s: str) -> bool:
        pair = {')': '(', ']': '[', '}': '{'}
        stack = []
        for c in s:
            if c in pair:
                if not stack or stack.pop() != pair[c]:
                    return False
            else:
                stack.append(c)
        return not stack
```

**解析：**
栈：遇右括号时栈顶必须是其配对的左括号，否则非法；结束后栈空即有效；O(n)/O(n)。

