### Graph-001-001 | ★★★★☆

**题目：** 岛屿数量

给定 n×m 的 0/1 矩阵，1 表示陆地、0 表示水，上下左右相连的陆地组成一个岛屿，求岛屿数量。

**输入格式**

第一行 n, m（1 ≤ n, m ≤ 1000）。
接下来 n 行，每行一个长度为 m 的 01 字符串。

**输出格式**

一个整数。

**示例输入**

```
4 5
11000
11000
00100
00011
```

**示例输出**

```
3
```

**答案（Python 3）：**

```python
import sys
from collections import deque

def solve():
    data = sys.stdin.buffer.read().split()
    n, m = int(data[0]), int(data[1])
    grid = [data[2 + i].decode() for i in range(n)]
    visited = [[False] * m for _ in range(n)]
    cnt = 0
    for i in range(n):
        for j in range(m):
            if grid[i][j] == '1' and not visited[i][j]:
                cnt += 1
                q = deque([(i, j)])
                visited[i][j] = True
                while q:
                    x, y = q.popleft()
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < n and 0 <= ny < m and grid[nx][ny] == '1' and not visited[nx][ny]:
                            visited[nx][ny] = True
                            q.append((nx, ny))
    print(cnt)

if __name__ == "__main__":
    solve()
```

**解析：**
遍历每个格子，遇到未访问的 '1' 计数 +1，并用 BFS/DFS 把整个连通块标记为已访问。为避免递归爆栈（n·m 大时），用显式队列 BFS 或栈迭代 DFS。


### Graph-001-002 | ★★★★☆

**题目：** 腐烂的橘子

n×m 网格：0 空、1 新鲜橘子、2 腐烂橘子。每分钟腐烂会向上下左右蔓延。求所有橘子都腐烂所需的最少分钟数；若有橘子永远无法腐烂输出 -1；没有新鲜橘子输出 0。

**输入格式**

第一行 n, m（1 ≤ n, m ≤ 1000）。
接下来 n 行每行 m 个用空格分隔的整数（0/1/2）。

**输出格式**

一个整数。

**示例输入**

```
3 3
2 1 1
1 1 0
0 1 1
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys
from collections import deque

def solve():
    data = sys.stdin.buffer.read().split()
    idx = 0
    n, m = int(data[idx]), int(data[idx+1]); idx += 2
    grid = []
    fresh = 0
    q = deque()
    for i in range(n):
        row = [int(data[idx + j]) for j in range(m)]
        idx += m
        grid.append(row)
        for j in range(m):
            if row[j] == 1:
                fresh += 1
            elif row[j] == 2:
                q.append((i, j))
    if fresh == 0:
        print(0)
        return
    minutes = 0
    while q and fresh > 0:
        minutes += 1
        for _ in range(len(q)):
            x, y = q.popleft()
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < n and 0 <= ny < m and grid[nx][ny] == 1:
                    grid[nx][ny] = 2
                    fresh -= 1
                    q.append((nx, ny))
    print(minutes if fresh == 0 else -1)

if __name__ == "__main__":
    solve()
```

**解析：**
多源 BFS：所有初始腐烂橘子同时入队（第 0 层），逐层扩散，层数即分钟数；结束检查是否还有新鲜橘子。多源 BFS 等价于"虚拟超级源点"的最短路，是 BFS 求最短时间问题的标准形态。


### Graph-001-003 | ★★★★☆

**题目：** 课程表 II（字典序最小的修课顺序）

共 n 门课（编号 1..n），m 条依赖关系 (a, b) 表示修 a 前必须先修 b。若能完成全部课程，输出一个修课顺序，要求**在所有可行顺序中字典序最小**；存在循环依赖输出 -1。

**输入格式**

第一行 n, m（1 ≤ n ≤ 1e5, 0 ≤ m ≤ 2e5）。
接下来 m 行每行 a, b（1 ≤ a, b ≤ n，a ≠ b）。可能有重复边。

**输出格式**

一行 n 个编号空格分隔；无解输出 -1。

**示例输入**

```
4 4
1 2
2 3
4 3
1 4
```

**示例输出**

```
3 2 4 1
```

**答案（Python 3）：**

```python
import sys
import heapq

def solve():
    data = sys.stdin.buffer.read().split()
    idx = 0
    n, m = int(data[idx]), int(data[idx+1]); idx += 2
    adj = [[] for _ in range(n + 1)]
    indeg = [0] * (n + 1)
    seen = set()
    for _ in range(m):
        a, b = int(data[idx]), int(data[idx+1]); idx += 2
        if (a, b) in seen:
            continue
        seen.add((a, b))
        adj[b].append(a)
        indeg[a] += 1
    heap = [c for c in range(1, n + 1) if indeg[c] == 0]
    heapq.heapify(heap)
    order = []
    while heap:
        c = heapq.heappop(heap)
        order.append(c)
        for nxt in adj[c]:
            indeg[nxt] -= 1
            if indeg[nxt] == 0:
                heapq.heappush(heap, nxt)
    if len(order) < n:
        print(-1)
    else:
        print(" ".join(map(str, order)))

if __name__ == "__main__":
    solve()
```

**解析：**
Kahn 算法 + 小顶堆：入度为 0 的课程入堆，每次取编号最小的出队，并将其后继入度减一、减到零入堆。字典序最小的拓扑序必须贪心选当前可用编号最小的（与普通 BFS 队列版本的区别）。示例中 3 是唯一入度为 0 的起点，随后在 {2,4} 中贪心选 2，故序为 3 2 4 1。计数出队数量 < n 即有环。


### Graph-001-004 | ★★★★☆

**题目：** 省份数量

n 个城市，给定 n×n 邻接矩阵 isConnected，isConnected[i][j]=1 表示 i、j 直接相连。省份是间接相连的城市集合（可达即同省），求省份数量。

**输入格式**

第一行 n（1 ≤ n ≤ 1000）。
接下来 n 行，每行 n 个整数（0/1）。

**输出格式**

一个整数。

**示例输入**

```
3
1 1 0
1 1 0
0 0 1
```

**示例输出**

```
2
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.buffer.read().split()
    idx = 0
    n = int(data[idx]); idx += 1
    parent = list(range(n))
    size = [1] * n

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]   # 路径减半压缩
            x = parent[x]
        return x

    cnt = n
    for i in range(n):
        for j in range(n):
            v = int(data[idx]); idx += 1
            if v == 1 and i < j:
                ri, rj = find(i), find(j)
                if ri != rj:
                    if size[ri] < size[rj]:
                        ri, rj = rj, ri
                    parent[rj] = ri
                    size[ri] += size[rj]
                    cnt -= 1
    print(cnt)

if __name__ == "__main__":
    solve()
```

**解析：**
并查集：初始化 n 个集合，遍历矩阵上三角，相连即 union；答案为最终不同根的个数（或初始 n 减去成功合并次数）。路径压缩 + 按大小合并后近乎 O(1)。


### Graph-001-005 | ★★★★☆

**题目：** 冗余连接

n 个节点构成一棵树（无环连通）额外加了一条边，共 n 条边。删除多余的一条边使图成树；若多解输出输入中最后出现的那条。

**输入格式**

第一行 n（2 ≤ n ≤ 1e4）。接下来 n 行每行 u, v。

**输出格式**

一行两个整数（被删除的边）。

**示例输入**

```
3
1 2
1 3
2 3
```

**示例输出**

```
2 3
```

**答案（Python 3）：**

```python
import sys

def solve():
    data = sys.stdin.read().split()
    n = int(data[0])
    parent = list(range(n + 1))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    idx = 1
    for _ in range(n):
        u, v = int(data[idx]), int(data[idx+1]); idx += 2
        ru, rv = find(u), find(v)
        if ru == rv:
            print(u, v)
            return
        parent[ru] = rv

if __name__ == "__main__":
    solve()
```

**解析：**
并查集按输入顺序加边：第一条使两点本已连通的边即环上多余边——"第一次 union 失败"的边就是答案（天然满足"最后出现"要求）。

