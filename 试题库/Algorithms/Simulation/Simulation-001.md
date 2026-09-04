### Simulation-001-001 | ★★★★☆

**题目：** 螺旋矩阵

给定 n×m 矩阵，按顺时针螺旋顺序输出所有元素。

**输入格式**

第一行 n, m（1 ≤ n, m ≤ 500）。
接下来 n 行每行 m 个整数（|aij| ≤ 1e9）。

**输出格式**

一行，螺旋顺序的元素，空格分隔。

**示例输入**

```
3 3
1 2 3
4 5 6
7 8 9
```

**示例输出**

```
1 2 3 6 9 8 7 4 5
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    idx = 0
    n, m = int(data[idx]), int(data[idx+1]); idx += 2
    g = []
    for i in range(n):
        g.append([int(data[idx + j]) for j in range(m)])
        idx += m
    top, bottom, left, right = 0, n - 1, 0, m - 1
    out = []
    while top <= bottom and left <= right:
        for j in range(left, right + 1):
            out.append(str(g[top][j]))
        top += 1
        for i in range(top, bottom + 1):
            out.append(str(g[i][right]))
        right -= 1
        if top <= bottom:
            for j in range(right, left - 1, -1):
                out.append(str(g[bottom][j]))
            bottom -= 1
        if left <= right:
            for i in range(bottom, top - 1, -1):
                out.append(str(g[i][left]))
            left += 1
    print(" ".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
四边界收缩法：维护 top/bottom/left/right 四个边界，依次"左→右、上→下、右→左、下→上"遍历并收缩对应边界；每段遍历前检查边界是否已交叉（非方阵必需），防止重复输出。


### Simulation-001-002 | ★★★★☆

**题目：** 旋转图像

将 n×n 矩阵顺时针旋转 90°，输出结果。

**输入格式**

第一行 n（1 ≤ n ≤ 500）。接下来 n 行每行 n 个整数。

**输出格式**

旋转后的矩阵，每行一行。

**示例输入**

```
3
1 2 3
4 5 6
7 8 9
```

**示例输出**

```
7 4 1
8 5 2
9 6 3
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    idx = 0
    n = int(data[idx]); idx += 1
    g = []
    for i in range(n):
        g.append([int(data[idx + j]) for j in range(n)])
        idx += n
    rot = [list(row) for row in zip(*g[::-1])]
    out = []
    for row in rot:
        out.append(" ".join(map(str, row)))
    print("\n".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
公式法：旋转后 b[j][n-1-i]=a[i][j]（即 zip(*rows[::-1])）；面试要求掌握"转置+逐行反转"的原地两步法。

