### Backtracking-001-001 | ★★★★☆

**题目：** 全排列

给定 n 个互不相同的整数，输出它们的所有全排列，按字典序从小到大，每行一个排列，数字用空格分隔。

**输入格式**

第一行 n（1 ≤ n ≤ 8）。
第二行 n 个互不相同的整数 ai（|ai| ≤ 100）。

**输出格式**

n! 行排列。

**示例输入**

```
3
3 1 2
```

**示例输出**

```
1 2 3
1 3 2
2 1 3
2 3 1
3 1 2
3 2 1
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    nums = sorted(map(int, data[1:1+n]))
    used = [False] * n
    path = []
    out = []

    def dfs(depth):
        if depth == n:
            out.append(" ".join(map(str, path)))
            return
        for i in range(n):
            if not used[i]:
                used[i] = True
                path.append(nums[i])
                dfs(depth + 1)
                path.pop()
                used[i] = False

    dfs(0)
    sys.stdout.write("\n".join(out) + "\n")

if __name__ == "__main__":
    solve()
```

**解析：**
回溯模板：先对元素排序保证字典序；每层从未使用的元素中按升序尝试选择，递归后撤销选择（恢复现场）。剪枝/去重版本（含重复元素）需排序后跳过同层重复分支。


### Backtracking-001-002 | ★★★★☆

**题目：** 括号生成

给定 n 对括号，输出所有由 n 对 `(` 和 `)` 组成的合法括号序列，按字典序从小到大排列，每行一个。

**输入格式**

一行一个整数 n（1 ≤ n ≤ 8）。

**输出格式**

所有合法括号序列，每行一个，按字典序升序。

**示例输入**

```
2
```

**示例输出**

```
(())
()()
```

**答案（Python 3）：**

```python
import sys

def solve():
    n = int(sys.stdin.read().split()[0])
    out = []
    path = []

    def dfs(l, r):
        if l == n and r == n:
            out.append("".join(path))
            return
        if l < n:
            path.append("(")
            dfs(l + 1, r)
            path.pop()
        if r < l:
            path.append(")")
            dfs(l, r + 1)
            path.pop()

    dfs(0, 0)
    print("\n".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
回溯：维护已用左括号数 l、右括号数 r。每层先尝试加 `(`（条件 l < n），再尝试加 `)`（条件 r < l）——按"先左后右"的尝试顺序天然得到字典序输出；长度达到 2n 时输出。


### Backtracking-001-003 | ★★★★☆

**题目：** 子集

给定 n 个互不相同整数，输出所有子集（含空集），按"每个子集升序、子集间按字典序"输出，每行一个子集（空集输出空行）。

**输入格式**

第一行 n（1 ≤ n ≤ 10）。第二行 n 个整数。

**输出格式**

2^n 行子集（元素按升序排列后输出，子集间按字典序）。

**示例输入**

```
3
1 2 3
```

**示例输出**

```

1
1 2
1 2 3
1 3
2
2 3
3
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    nums = sorted(map(int, data[1:1+n]))
    out = []

    def dfs(start, path):
        out.append(path[:])
        for i in range(start, n):
            path.append(nums[i])
            dfs(i + 1, path)
            path.pop()

    dfs(0, [])
    print("\n".join(" ".join(map(str, p)) for p in out))

if __name__ == "__main__":
    solve()
```

**解析：**
回溯子集树：每层"选/不选"当前元素，起点 start 递增去重序；先排序保证字典序输出（含空行开头）。


### Backtracking-001-004 | ★★★★☆

**题目：** 全排列 II

给定可能含重复整数的序列，输出所有不重复的全排列，按字典序，每行一个。

**输入格式**

第一行 n（1 ≤ n ≤ 8）。第二行 n 个整数。

**输出格式**

若干行排列。

**示例输入**

```
3
1 1 2
```

**示例输出**

```
1 1 2
1 2 1
2 1 1
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    nums = sorted(map(int, data[1:1+n]))
    used = [False] * n
    path = []
    out = []

    def dfs():
        if len(path) == n:
            out.append(path[:])
            return
        for i in range(n):
            if used[i]:
                continue
            if i > 0 and nums[i] == nums[i-1] and not used[i-1]:
                continue
            used[i] = True
            path.append(nums[i])
            dfs()
            path.pop()
            used[i] = False

    dfs()
    print("\n".join(" ".join(map(str, p)) for p in out))

if __name__ == "__main__":
    solve()
```

**解析：**
排序 + 回溯 + 同层去重：`if i>0 and nums[i]==nums[i-1] and not used[i-1]: continue`——同一层跳过重复值；used 数组标记已选。

