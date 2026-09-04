### String-001-001 | ★★★☆☆

**题目：** 验证回文串

给定一个字符串，忽略大小写差异，只考虑字母和数字字符，判断它是否是回文串。

**输入格式**

一行一个字符串 s（长度 1 ≤ |s| ≤ 1e6，可能包含空格、标点、大小写字母、数字）。

**输出格式**

是回文输出 `true`，否则输出 `false`。

**示例输入**

```
A man, a plan, a canal: Panama
```

**示例输出**

```
true
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().rstrip("\n")
    t = [ch.lower() for ch in s if ch.isalnum()]
    print("true" if t == t[::-1] else "false")

if __name__ == "__main__":
    solve()
```

**解析：**
先过滤出字母数字并统一小写，再双指针从两端向中间比较。或先清洗成新串再与反转比较（`t == t[::-1]`），Python 实现简洁。注意全为符号的串清洗后为空，视为回文。


### String-001-002 | ★★★★☆

**题目：** 无重复字符的最长子串

给定字符串 s，求不含重复字符的最长子串的长度。

**输入格式**

一行一个字符串 s（|s| ≤ 1e5，可含任意可见 ASCII 字符）。

**输出格式**

一个整数。

**示例输入**

```
abcabcbb
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
    s = sys.stdin.readline().rstrip("\n")
    cnt = defaultdict(int)
    left = 0
    ans = 0
    for right, ch in enumerate(s):
        cnt[ch] += 1
        while cnt[ch] > 1:
            cnt[s[left]] -= 1
            if cnt[s[left]] == 0:
                del cnt[s[left]]
            left += 1
        ans = max(ans, right - left + 1)
    print(ans)

if __name__ == "__main__":
    solve()
```

**解析：**
滑动窗口模板：右指针扩张，用哈希表记录窗口内字符计数，出现重复时收缩左指针直到无重复；每步用窗口长度更新答案。保证每个字符进出窗口各一次，O(n)。


### String-001-003 | ★★★★☆

**题目：** 大数加法

给定两个可能非常大的非负整数（以字符串形式，长度可达 1e5 位），求它们的和。不允许直接转成内置整数类型处理（考察手写进位逻辑）。

**输入格式**

两行，每行一个非负整数字符串 a, b（无前导零，可为 "0"）。

**输出格式**

一行，两数之和。

**示例输入**

```
999999999999999999999
1
```

**示例输出**

```
1000000000000000000000
```

**答案（Python 3）：**

```python
import sys

def solve():
    a = sys.stdin.readline().strip()
    b = sys.stdin.readline().strip()
    i, j = len(a) - 1, len(b) - 1
    carry = 0
    res = []
    while i >= 0 or j >= 0 or carry:
        da = int(a[i]) if i >= 0 else 0
        db = int(b[j]) if j >= 0 else 0
        cur = da + db + carry
        res.append(str(cur % 10))
        carry = cur // 10
        i -= 1
        j -= 1
    print("".join(reversed(res)))

if __name__ == "__main__":
    solve()
```

**解析：**
从末位对齐逐位相加，维护进位；双指针从后往前，循环条件是两串未走完或进位非零。逐位 append 后最终反转。


### String-001-004 | ★★★★☆

**题目：** 最长回文子串

给定字符串 s，求其中最长回文子串的**长度**（仅由原串连续字符构成）。若存在多个等长解，长度相同无需区分。

**输入格式**

一行一个字符串 s（|s| ≤ 2000）。

**输出格式**

一个整数。

**示例输入**

```
babad
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().rstrip("\n")
    n = len(s)
    best = 0
    for c in range(n):
        for l, r in ((c, c), (c, c + 1)):
            while l >= 0 and r < n and s[l] == s[r]:
                l -= 1
                r += 1
            best = max(best, r - l - 1)
    print(best)

if __name__ == "__main__":
    solve()
```

**解析：**
中心扩展法：回文中心有 2n-1 个（每个字符 + 每对相邻字符间隙），从每个中心向两侧扩展直到不匹配，记录最大长度，O(n²)。n=2000 可过。n 更大时用 Manacher O(n)，面试常作追问。


### String-001-005 | ★★★☆☆

**题目：** 最后一个单词的长度

给定只含字母与空格的字符串 s（末尾可能有若干空格），输出最后一个单词的长度；无单词输出 0。

**输入格式**

一行字符串（1 ≤ |s| ≤ 1e4，可能含前导/末尾空格）。

**输出格式**

一个整数。

**示例输入**

```
hello world   
```

**示例输出**

```
5
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().rstrip("\n")
    i = len(s) - 1
    while i >= 0 and s[i] == ' ':
        i -= 1
    cnt = 0
    while i >= 0 and s[i] != ' ':
        cnt += 1
        i -= 1
    print(cnt)

if __name__ == "__main__":
    solve()
```

**解析：**
从尾部向前跳过空格，再数非空格字符；O(len) 一遍扫描无需 split。


### String-001-006 | ★★★★☆

**题目：** 字符串解码（栈）

编码规则 `k[encoded]` 表示括号内内容重复 k 次（k 为正整数、无前导零、保证输入合法且嵌套深度 ≤ 30），输出解码结果。

**输入格式**

一行编码字符串（长度 ≤ 1000，仅数字/字母/[]）。

**输出格式**

解码后的字符串。

**示例输入**

```
3[a2[c]]
```

**示例输出**

```
accaccacc
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().strip()
    num_stack = []
    str_stack = []
    cur = ""
    num = 0
    for ch in s:
        if ch.isdigit():
            num = num * 10 + int(ch)
        elif ch == '[':
            num_stack.append(num)
            str_stack.append(cur)
            num = 0
            cur = ""
        elif ch == ']':
            k = num_stack.pop()
            prev = str_stack.pop()
            cur = prev + cur * k
        else:
            cur += ch
    print(cur)

if __name__ == "__main__":
    solve()
```

**解析：**
双栈：遇数字累积倍数、遇 `[` 压入（当前串, 倍数）并重置、遇 `]` 弹出拼接（弹出的串 + cur×倍数）、普通字符追加 cur。

