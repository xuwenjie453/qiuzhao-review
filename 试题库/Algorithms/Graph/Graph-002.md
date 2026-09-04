### Graph-002-001 | ★★★★☆

岛屿数量。给定 '1'（陆地）和 '0'（水）组成的二维网格 grid，计算网格中岛屿的数量（岛屿被水包围，由水平或垂直相邻的陆地连接形成），要求不修改原数组时用 visited 数组，DFS/BFS 沉岛两种写法都要会。输入：grid = [["1","1","0","0","0"],["1","1","0","0","0"],["0","0","1","0","0"],["0","0","0","1","1"]]；输出：3。

**答案（Python 3）：**

```python
from collections import deque

class Solution:
    def numIslands(self, grid):
        '''写法一：DFS 沉岛（直接修改原数组，把访问过的陆地改成水）'''
        if not grid:
            return 0
        m, n = len(grid), len(grid[0])

        def sink(i, j):
            if i < 0 or i >= m or j < 0 or j >= n or grid[i][j] != '1':
                return
            grid[i][j] = '0'                # 沉岛：标记已访问
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sink(i + dx, j + dy)

        count = 0
        for i in range(m):
            for j in range(n):
                if grid[i][j] == '1':       # 每遇到一个新岛屿：计数 +1 并整体沉掉
                    count += 1
                    sink(i, j)
        return count

    def numIslandsBFS(self, grid):
        '''写法二：BFS + visited 数组（不修改原数组）'''
        if not grid:
            return 0
        m, n = len(grid), len(grid[0])
        visited = [[False] * n for _ in range(m)]
        count = 0
        for i in range(m):
            for j in range(n):
                if grid[i][j] == '1' and not visited[i][j]:
                    count += 1
                    q = deque([(i, j)])
                    visited[i][j] = True
                    while q:                # BFS 把整个连通块标记掉
                        x, y = q.popleft()
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < m and 0 <= ny < n and grid[nx][ny] == '1' and not visited[nx][ny]:
                                visited[nx][ny] = True
                                q.append((nx, ny))
        return count
```

**解析：**
外层双重循环遇到 '1' 计数 +1，DFS 直接把整个连通块沉成 '0'（改原数组）；不改原数组则用 visited 数组 + BFS 标记连通块；两种写法时间 O(mn)、空间 O(mn)。


### Graph-002-002 | ★★★★☆

岛屿的最大面积。给定 '1'（陆地）和 '0'（水）组成的二维网格，计算最大岛屿的面积（岛屿中陆地格子数，水平/垂直相邻），遍历每个格子做 DFS/BFS 统计并取最大值。输入：grid = [[0,0,1,0,0,0,0,1,0,0,0,0,0],[0,0,0,0,0,0,0,1,1,1,0,0,0],[0,1,1,0,1,0,0,0,0,0,0,0,0],[0,1,0,0,1,1,0,0,1,0,1,0,0],[0,1,0,0,1,1,0,0,1,1,1,0,0],[0,0,0,0,0,0,0,0,0,0,1,0,0],[0,0,0,0,0,0,0,1,1,1,0,0,0],[0,0,0,0,0,0,0,1,1,0,0,0,0]]；输出：6。

**答案（Python 3）：**

```python
class Solution:
    def maxAreaOfIsland(self, grid):
        '''岛屿最大面积：遍历每个格子做 DFS 统计连通块大小，取最大值'''
        m, n = len(grid), len(grid[0])

        def dfs(i, j):
            if i < 0 or i >= m or j < 0 or j >= n or grid[i][j] != 1:
                return 0
            grid[i][j] = 0                  # 沉岛，防止重复计数
            return 1 + dfs(i + 1, j) + dfs(i - 1, j) + dfs(i, j + 1) + dfs(i, j - 1)

        ans = 0
        for i in range(m):
            for j in range(n):
                if grid[i][j] == 1:
                    ans = max(ans, dfs(i, j))
        return ans
```

**解析：**
与岛屿数量同理：DFS 返回连通块格子数并把访问过的格子置 0 防重复，外层遍历取最大；时间 O(mn)、空间 O(mn) 递归栈。

