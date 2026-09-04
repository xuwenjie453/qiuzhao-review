### StackQueue-001-001 | ★★★★☆

**题目：** 滑动窗口最大值

给定数组和窗口大小 k，窗口从左向右每次滑动一位，输出每个窗口位置的最大值（共 n-k+1 个）。

**输入格式**

第一行 n, k（1 ≤ k ≤ n ≤ 1e6）。
第二行 n 个整数 ai（|ai| ≤ 1e9）。

**输出格式**

一行 n-k+1 个整数，空格分隔。

**示例输入**

```
8 3
1 3 -1 -3 5 3 6 7
```

**示例输出**

```
3 3 5 5 6 7
```

**答案（Python 3）：**

```python
import sys
from collections import deque

def solve():
    data = sys.stdin.read().split()
    n, k = int(data[0]), int(data[1])
    a = list(map(int, data[2:2+n]))
    dq = deque()  # 存下标，值递减
    out = []
    for i in range(n):
        while dq and a[dq[-1]] <= a[i]:
            dq.pop()
        dq.append(i)
        if dq[0] <= i - k:
            dq.popleft()
        if i >= k - 1:
            out.append(str(a[dq[0]]))
    print(" ".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
单调递减队列（存下标）：入队前弹出队尾所有 ≤ 当前值的元素；队首下标滑出窗口时弹出；每步窗口最大值即队首。每个元素最多进出队一次，O(n)。堆解法 O(n log n) 为对照。


### StackQueue-001-002 | ★★★☆☆

**题目：** 用栈实现队列

仅使用两个栈实现一个先进先出队列，支持 `push x`、`pop`（弹出队首并输出该值）、`peek`（输出队首值，不弹出）。保证 pop/peek 操作时队列非空。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5，指令条数）。
接下来 n 行指令：`push x`（|x| ≤ 1e9）或 `pop` / `peek`。

**输出格式**

对每条 `pop` 与 `peek` 指令，各输出一行结果。

**示例输入**

```
6
push 1
push 2
peek
pop
peek
pop
```

**示例输出**

```
1
1
2
2
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split("\n")
    n = int(data[0].strip())
    in_st, out_st = [], []
    out = []
    for i in range(1, n + 1):
        parts = data[i].split()
        if parts[0] == "push":
            in_st.append(int(parts[1]))
        else:
            if not out_st:
                while in_st:
                    out_st.append(in_st.pop())
            if parts[0] == "peek":
                out.append(str(out_st[-1]))
            else:
                out.append(str(out_st.pop()))
    print("\n".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
入栈栈 in + 出栈栈 out：push 压入 in；pop/peek 时若 out 为空，把 in 全部倒灌进 out（逆序一次），再从 out 弹出/查看。每个元素最多进出每个栈一次，均摊 O(1)。


### StackQueue-001-003 | ★★★☆☆

**题目：** 有效括号

给定一个只包含 `(` `)` `[` `]` `{` `}` 的字符串 s，判断 s 是否为有效的括号序列：左括号必须以正确顺序被同类型右括号闭合。

**输入格式**

一行字符串 s（1 ≤ |s| ≤ 1e5）。

**输出格式**

有效输出 `true`，否则 `false`。

**示例输入**

```
([{}])
```

**示例输出**

```
true
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().strip()
    pairs = {')': '(', ']': '[', '}': '{'}
    st = []
    for ch in s:
        if ch in "([{":
            st.append(ch)
        else:
            if not st or st[-1] != pairs[ch]:
                print("false")
                return
            st.pop()
    print("true" if not st else "false")

if __name__ == "__main__":
    solve()
```

**解析：**
栈模板：左括号入栈；右括号弹栈匹配类型，不匹配或栈空即无效；结束时栈为空才有效。


### StackQueue-001-004 | ★★★★☆

**题目：** 每日温度

给定每日温度列表，对每一天，输出要等几天才有更高温度；之后也没有则输出 0。

**输入格式**

第一行 n（1 ≤ n ≤ 1e6）。
第二行 n 个整数 ti（0 ≤ ti ≤ 1e9）。

**输出格式**

一行 n 个整数，空格分隔。

**示例输入**

```
8
73 74 75 71 69 72 76 73
```

**示例输出**

```
1 1 4 2 1 1 0 0
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    t = list(map(int, data[1:1+n]))
    st = []
    ans = [0] * n
    for i in range(n):
        while st and t[i] > t[st[-1]]:
            j = st.pop()
            ans[j] = i - j
        st.append(i)
    print(" ".join(map(str, ans)))

if __name__ == "__main__":
    solve()
```

**解析：**
单调递减栈（存下标）：新温度高于栈顶温度时，栈顶元素的答案即当前下标差，弹出并填写；遍历后栈中剩余为 0。每个下标至多进出栈一次。


### StackQueue-001-005 | ★★★★☆

**题目：** 最小栈

设计一个支持 push、pop、top 以及**常数时间** getMin 的栈。按指令序列模拟：`push x` 入栈；`pop` 弹出栈顶（保证操作时栈非空）；`top` 输出栈顶元素；`getmin` 输出栈内最小元素。

**输入格式**

第一行 n（1 ≤ n ≤ 1e5，指令条数）。
接下来 n 行，每行一条指令：`push x`（|x| ≤ 1e9）或 `pop` / `top` / `getmin`。

**输出格式**

对每条 `top` 与 `getmin` 指令，各输出一行结果。

**示例输入**

```
7
push 3
push 1
push 5
top
getmin
pop
getmin
```

**示例输出**

```
5
1
1
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split("\n")
    n = int(data[0].strip())
    st, mn = [], []
    out = []
    for i in range(1, n + 1):
        parts = data[i].split()
        op = parts[0]
        if op == "push":
            x = int(parts[1])
            st.append(x)
            if not mn or x <= mn[-1]:
                mn.append(x)
        elif op == "pop":
            v = st.pop()
            if mn and mn[-1] == v:
                mn.pop()
        elif op == "top":
            out.append(str(st[-1]))
        else:  # getmin
            out.append(str(mn[-1]))
    print("\n".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
辅助最小栈：主栈正常进出；辅助栈栈顶维护"当前状态下的最小值"——push 时若 x ≤ 辅助栈顶则同步压入，pop 时若弹出值等于辅助栈顶则同步弹出。所有操作 O(1)。


### StackQueue-001-006 | ★★★☆☆

**题目：** 删除字符串中的所有相邻重复项

反复删除字符串中相邻且相同的字符对（每次删除后新相邻的相同对继续删），输出最终结果。

**输入格式**

一行小写字符串（1 ≤ |s| ≤ 1e5）。

**输出格式**

最终字符串（可能为空行）。

**示例输入**

```
abbaca
```

**示例输出**

```
ca
```

**答案（Python 3）：**

```python
import sys

def solve():
    s = sys.stdin.readline().strip()
    st = []
    for ch in s:
        if st and st[-1] == ch:
            st.pop()
        else:
            st.append(ch)
    print("".join(st))

if __name__ == "__main__":
    solve()
```

**解析：**
栈消消乐：当前字符与栈顶相同则弹栈，否则入栈；一遍即得最终态。

