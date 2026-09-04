### Tree-002-001 | ★★★★☆

二叉树的层序遍历。给定二叉树根节点 root，返回其节点值按层序（自上而下、自左向右逐层）遍历的结果，用队列实现，一层一层输出到二维数组。输入：root = [3,9,20,null,null,15,7]；输出：[[3],[9,20],[15,7]]。追问：如何按层统计每层节点数（记录队列当前 size）。

**答案（Python 3）：**

```python
from collections import deque

class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # BFS：每层先记 size=len(q)，再弹出 size 个，实现逐层分组。O(n)
    def levelOrder(self, root):
        if not root:
            return []
        res, q = [], deque([root])
        while q:
            size = len(q)       # 当前层节点数（追问：按层统计就是记录这个 size）
            level = []
            for _ in range(size):
                node = q.popleft()
                level.append(node.val)
                if node.left:
                    q.append(node.left)
                if node.right:
                    q.append(node.right)
            res.append(level)
        return res
```

**解析：**
BFS 队列：每层先记 size=len(q) 再弹出 size 个实现逐层分组，这正是追问的按层统计写法；O(n)。


### Tree-002-002 | ★★★★☆

二叉树的锯齿形层序遍历。给定二叉树根节点 root，返回其节点值的锯齿形层序遍历结果：先从左往右、再从右往左交替进行逐层遍历（用队列 + 每层方向标记，或双端队列）。输入：root = [3,9,20,null,null,15,7]；输出：[[3],[20,9],[15,7]]。

**答案（Python 3）：**

```python
from collections import deque

class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # 层序骨架 + 方向标记：正向 append 队尾、反向 appendleft，双端队列免反转
    def zigzagLevelOrder(self, root):
        if not root:
            return []
        res, q = [], deque([root])
        left2right = True
        while q:
            level = deque()
            for _ in range(len(q)):
                node = q.popleft()
                if left2right:
                    level.append(node.val)
                else:
                    level.appendleft(node.val)
                if node.left:
                    q.append(node.left)
                if node.right:
                    q.append(node.right)
            res.append(list(level))
            left2right = not left2right
        return res
```

**解析：**
层序骨架 + 方向标记：正向 append 队尾、反向 appendleft，用双端队列免反转；也可每层收集成 list 后对偶数层 reverse。


### Tree-002-003 | ★★★★☆

二叉树的右视图。给定二叉树根节点 root，返回从右侧看该树能看到的节点值（每层最右节点），按自顶向下顺序输出。要求会层序每层取最后一个 和 DFS 右优先带深度 两种写法。输入：root = [1,2,3,null,5,null,4]；输出：[1,3,4]。

**答案（Python 3）：**

```python
from collections import deque

class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # 写法一：BFS，处理每层前先取队尾（当前层最右节点）加入答案
    def rightSideView(self, root):
        if not root:
            return []
        res, q = [], deque([root])
        while q:
            res.append(q[-1].val)       # 本层最后一个即右视图节点
            for _ in range(len(q)):
                node = q.popleft()
                if node.left:
                    q.append(node.left)
                if node.right:
                    q.append(node.right)
        return res

    # 写法二：DFS 右优先，depth == len(res) 时说明是该层第一个被访问的（即最右）
    def rightSideViewDFS(self, root):
        res = []

        def dfs(node, depth):
            if not node:
                return
            if depth == len(res):
                res.append(node.val)
            dfs(node.right, depth + 1)  # 先右后左
            dfs(node.left, depth + 1)

        dfs(root, 0)
        return res
```

**解析：**
BFS 每层取队尾即最右节点；DFS 右优先遍历，depth==len(res) 的第一个访问节点就是该层最右。O(n)。


### Tree-002-004 | ★★★★☆

二叉树的最近公共祖先。给定二叉树根节点 root 和树中两个节点 p、q，找到它们的最近公共祖先节点并返回（一个节点可以是自己的祖先）。输入：root = [3,5,1,6,2,0,8,null,null,7,4], p = 5, q = 1；输出：3。要求写递归后序解法：左右子树分别查找，两边都命中则当前节点为答案。

**答案（Python 3）：**

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # 后序递归 O(n)：空/命中 p 或 q 直接返回；
    # 左右子树各返回一个命中 -> 当前节点即 LCA；只命中一侧则答案在该侧
    def lowestCommonAncestor(self, root, p, q):
        if not root or root is p or root is q:
            return root
        left = self.lowestCommonAncestor(root.left, p, q)
        right = self.lowestCommonAncestor(root.right, p, q)
        if left and right:
            return root
        return left if left else right
```

**解析：**
后序递归：空或命中 p/q 返回自身，左右子树都命中说明 p、q 分居两侧、当前节点即 LCA，否则返回非空一侧；O(n)。


### Tree-002-005 | ★★★★☆

二叉树中的最大路径和。路径定义为从树中任意节点出发、沿父节点-子节点连接、到达任意节点的序列（不重复经过），路径和为节点值之和，返回最大路径和，节点值可为负。递归返回"单侧最大贡献"，用全局变量更新"经过当前节点的最大路径和"。输入：root = [-10,9,20,null,null,15,7]；输出：42（15→20→7）。

**答案（Python 3）：**

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # O(n)：递归返回“以 node 为端点向上延伸的单侧最大贡献”（负贡献截断为 0），
    # 每个节点处用 node.val + 左贡献 + 右贡献 更新全局答案（即拐弯经过该节点的最大路径）
    def maxPathSum(self, root) -> int:
        self.ans = float('-inf')

        def gain(node):
            if not node:
                return 0
            lg = max(gain(node.left), 0)    # 子树贡献为负则不选
            rg = max(gain(node.right), 0)
            self.ans = max(self.ans, node.val + lg + rg)
            return node.val + max(lg, rg)   # 向父级只能延伸一侧

        gain(root)
        return self.ans
```

**解析：**
递归返回单侧最大贡献（负贡献截为 0），每节点用 val+左+右 更新全局答案（经过该节点的最大路径），向父级只延伸一侧；O(n)，节点值可全负时答案为最大单节点。


### Tree-002-006 | ★★★★☆

从前序与中序遍历序列构造二叉树。给定两个整数数组 preorder 和 inorder（无重复值），preorder 是二叉树的前序遍历、inorder 是中序遍历，请构造二叉树并返回其根节点。输入：preorder = [3,9,20,15,7], inorder = [9,3,15,20,7]；输出：[3,9,20,null,null,15,7]。要求用哈希表记录中序值到下标的映射，O(n) 递归构建。

**答案（Python 3）：**

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # 哈希表存中序 值->下标，O(1) 定位根分割左右子树；前序指针依次给出各子树根。
    # 注意必须先递归建左子树再建右子树（与前序消耗顺序一致）。O(n)
    def buildTree(self, preorder, inorder):
        idx = {v: i for i, v in enumerate(inorder)}
        self.pre = 0                        # 当前使用的先序下标

        def build(l, r):                    # 处理中序区间 [l, r]
            if l > r:
                return None
            root = TreeNode(preorder[self.pre])
            self.pre += 1
            m = idx[root.val]
            root.left = build(l, m - 1)
            root.right = build(m + 1, r)
            return root

        return build(0, len(inorder) - 1)
```

**解析：**
哈希表存中序值->下标 O(1) 定分割点；前序指针依次取根，先递归建左子树再建右子树（与前序消耗顺序一致）。O(n)。


### Tree-002-007 | ★★★★☆

验证二叉搜索树。给定二叉树根节点 root，判断其是否为有效的二叉搜索树：左子树所有节点值严格小于根，右子树所有节点值严格大于根，左右子树也分别为 BST。要求会"传递上下界"与"中序遍历递增"两种解法，注意不能用 INT_MIN/INT_MAX 作初始界（节点值可取到边界），需用 None/Long。输入：root = [5,1,4,null,null,3,6]；输出：false。

**答案（Python 3）：**

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # 解法一：传递上下界。边界用 None 表示正负无穷，
    # 避免用 INT_MIN/INT_MAX 初始化时节点值恰好取到边界而误判
    def isValidBST(self, root) -> bool:
        def valid(node, lo, hi):
            if not node:
                return True
            if (lo is not None and node.val <= lo) or (hi is not None and node.val >= hi):
                return False
            return valid(node.left, lo, node.val) and valid(node.right, node.val, hi)

        return valid(root, None, None)

    # 解法二：中序遍历必须严格递增（保存前驱值比较）
    def isValidBSTInorder(self, root) -> bool:
        self.prev = None

        def inorder(node):
            if not node:
                return True
            if not inorder(node.left):
                return False
            if self.prev is not None and node.val <= self.prev:
                return False
            self.prev = node.val
            return inorder(node.right)

        return inorder(root)
```

**解析：**
解法一传上下界递归（用 None 表示无穷界，避免节点值恰为 INT_MIN/MAX 时误判）；解法二中序遍历必须严格递增、比较前驱值；均 O(n)。


### Tree-002-008 | ★★★★☆

二叉搜索树的第 k 大节点。给定一棵二叉搜索树的根节点 root 和整数 k，返回树中第 k 大的节点值，要求不暴力全排序：反向中序遍历（右-根-左）计数，数到第 k 个即答案，可提前剪枝终止。输入：root = [5,3,7,2,4,6,8], k = 3（表示 5,3,7,2,4,6,8 构成的 BST）；输出：6。

**答案（Python 3）：**

```python
# 二叉搜索树的第 k 大节点：反向中序遍历（右 -> 根 -> 左）得到递减序列，数到第 k 个即答案
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    def kthLargest(self, root: TreeNode, k: int) -> int:
        self.k = k
        self.ans = None

        def dfs(node):
            if not node or self.ans is not None:   # 已找到则剪枝提前终止
                return
            dfs(node.right)                        # 先遍历右子树（较大的部分）
            self.k -= 1
            if self.k == 0:                        # 数到第 k 个
                self.ans = node.val
                return
            dfs(node.left)

        dfs(root)
        return self.ans
```

**解析：**
反向中序遍历（右-根-左）即按降序访问节点，计数到 k 立即剪枝终止；时间 O(H+k)（H 为树高），空间 O(H) 递归栈。


### Tree-002-009 | ★★★★☆

翻转二叉树。给定二叉树根节点 root，将它的左右子树镜像翻转后返回根节点（每个节点的左右孩子互换）。输入：root = [4,2,7,1,3,6,9]；输出：[4,7,2,9,6,3,1]。要求递归与迭代（队列）两种写法都能写。

**答案（Python 3）：**

```python
from collections import deque

class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    # 写法一：递归 —— 交换每个节点的左右子树
    def invertTree(self, root: TreeNode) -> TreeNode:
        if not root:
            return None
        root.left, root.right = self.invertTree(root.right), self.invertTree(root.left)
        return root

    # 写法二：迭代（队列 / BFS）—— 出队一个节点就交换其左右孩子，再把孩子入队
    def invertTreeIter(self, root: TreeNode) -> TreeNode:
        if not root:
            return None
        q = deque([root])
        while q:
            node = q.popleft()
            node.left, node.right = node.right, node.left
            if node.left:
                q.append(node.left)
            if node.right:
                q.append(node.right)
        return root
```

**解析：**
递归与 BFS 迭代本质相同：对每个节点交换左右孩子；时间 O(n)、空间 O(n)（最坏队列长度/递归深度）。


### Tree-002-010 | ★★★★☆

二叉树的直径。给定二叉树根节点 root，返回任意两节点之间最长路径的边数（路径可能不经过根节点），做法：递归求每个节点左右子树深度，用左右深度之和更新全局最大值。输入：root = [1,2,3,4,5]；输出：3（路径 4→2→1→3）。

**答案（Python 3）：**

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class Solution:
    def diameterOfBinaryTree(self, root: TreeNode) -> int:
        self.ans = 0

        def depth(node):
            if not node:
                return 0
            l = depth(node.left)                # 左子树深度
            r = depth(node.right)               # 右子树深度
            self.ans = max(self.ans, l + r)     # 经过该节点的最长路径边数 = 左深 + 右深
            return max(l, r) + 1                # 返回给父节点的高度

        depth(root)
        return self.ans
```

**解析：**
后序递归求每个节点的左右子树深度，用 l+r 更新全局最大直径（路径可不经过根）；每节点访问一次，时间 O(n)、空间 O(H)。


### Tree-002-011 | ★★★★☆

数组中的第 K 个最大元素（字节一面现场手撕原题：给定整数数组 nums 和整数 k，返回数组中第 k 大的元素；是排序后第 k 个、不是第 k 个不同的元素；要求在不完全排序整个数组的前提下找到答案）。输入：nums = [3,2,1,5,6,4], k = 2；输出：5。要求快速选择（基于 partition 只递归一侧）平均 O(n)，并能写小顶堆 O(n log k) 解法。

**答案（Python 3）：**

```python
import random
import heapq

class Solution:
    # 解法一：快速选择（partition 后只递归目标一侧），平均 O(n)
    def findKthLargest(self, nums, k):
        def partition(lo, hi):
            p = random.randint(lo, hi)          # 随机 pivot，防止有序输入退化为 O(n^2)
            nums[p], nums[hi] = nums[hi], nums[p]
            pivot, i = nums[hi], lo
            for j in range(lo, hi):
                if nums[j] > pivot:             # 降序划分：比 pivot 大的都换到左边
                    nums[i], nums[j] = nums[j], nums[i]
                    i += 1
            nums[i], nums[hi] = nums[hi], nums[i]
            return i                            # pivot 的最终位置

        target, lo, hi = k - 1, 0, len(nums) - 1   # 第 k 大在降序数组中的下标是 k-1
        while True:
            p = partition(lo, hi)
            if p == target:
                return nums[p]
            elif p < target:                    # 只递归目标所在的一侧
                lo = p + 1
            else:
                hi = p - 1

    # 解法二：小顶堆 O(n log k)，适合数据流 / 不允许修改数组
    def findKthLargestHeap(self, nums, k):
        heap = []
        for x in nums:
            heapq.heappush(heap, x)
            if len(heap) > k:
                heapq.heappop(heap)             # 弹出最小的，堆中始终保留最大的 k 个数
        return heap[0]                          # 堆顶即第 k 大

# 验证：nums=[3,2,1,5,6,4], k=2 -> 5
```

**解析：**
快速选择每次 partition 后只进一侧，平均 O(n)、最坏 O(n^2)（随机 pivot 规避）；小顶堆维护最大的 k 个数，稳定 O(n log k)、空间 O(k)。


### Tree-002-012 | ★★★★☆

滑动窗口最大值。给定整数数组 nums 和窗口大小 k，窗口每次向右移动一位，返回每个窗口位置上的最大值组成的数组，要求 O(n)：单调递减队列（存下标），队头即当前窗口最大值。输入：nums = [1,3,-1,-3,5,3,6,7], k = 3；输出：[3,3,5,5,6,7]。

**答案（Python 3）：**

```python
from collections import deque

class Solution:
    def maxSlidingWindow(self, nums, k):
        dq = deque()    # 存下标，对应值从队头到队尾单调递减
        res = []
        for i, x in enumerate(nums):
            while dq and nums[dq[-1]] <= x:     # 队尾比当前值小的都不可能再成为最大值
                dq.pop()
            dq.append(i)
            if dq[0] <= i - k:                  # 队头下标滑出窗口则弹出
                dq.popleft()
            if i >= k - 1:
                res.append(nums[dq[0]])         # 队头即当前窗口最大值
        return res

# 验证：nums=[1,3,-1,-3,5,3,6,7], k=3 -> [3,3,5,5,6,7]
```

**解析：**
单调递减队列存下标：新元素从队尾入、过期下标从队头出，每个下标最多进出各一次，时间 O(n)、空间 O(k)。


### Tree-002-013 | ★★★★☆

最小的 k 个数。给定整数数组 arr 和整数 k，返回数组中最小的 k 个数，输出顺序任意（快排 partition 的快速选择写法，或维护大小为 k 的大顶堆），并分析两种方法复杂度。输入：arr = [3,2,1], k = 2；输出：[1,2] 或 [2,1]。

**答案（Python 3）：**

```python
import heapq

class Solution:
    # 解法一：快速选择（基于 partition 只递归一侧），平均 O(n)，会原地打乱数组
    def getLeastNumbers(self, arr, k):
        if k <= 0:
            return []
        if k >= len(arr):
            return list(arr)

        def partition(lo, hi):
            pivot = arr[lo]                     # 挖坑法：pivot 取首元素
            while lo < hi:
                while lo < hi and arr[hi] >= pivot:
                    hi -= 1
                arr[lo] = arr[hi]
                while lo < hi and arr[lo] <= pivot:
                    lo += 1
                arr[hi] = arr[lo]
            arr[lo] = pivot
            return lo

        target, lo, hi = k, 0, len(arr) - 1
        while True:
            p = partition(lo, hi)
            if p == target:                     # 下标 [0, k) 的就是最小的 k 个数
                return arr[:k]
            elif p < target:
                lo = p + 1
            else:
                hi = p - 1

    # 解法二：大小为 k 的大顶堆 O(n log k)，不修改数组、适合海量数据
    def getLeastNumbersHeap(self, arr, k):
        if k <= 0:
            return []
        heap = [-x for x in arr[:k]]            # 取负模拟大顶堆
        heapq.heapify(heap)
        for x in arr[k:]:
            if x < -heap[0]:                    # 比堆顶（当前第 k 小）还小才替换
                heapq.heapreplace(heap, -x)
        return [-x for x in heap]

# 验证：arr=[3,2,1], k=2 -> [1,2] 或 [2,1]
```

**解析：**
快速选择平均 O(n)、最坏 O(n^2)，原地修改数组且前 k 个无序；大顶堆 O(n log k)、空间 O(k)，不修改数组，适合数据流/海量数据。


### Tree-002-014 | ★★★★☆

手撕堆排序。给定整数数组 nums，请用堆排序将其按升序排序（不得调用内置排序）：先原地建大顶堆（从最后一个非叶子节点下沉），再每次将堆顶与末尾交换、堆大小减一后下沉调整，要求写出 sift-down（下沉）过程，说明建堆 O(n)、整体 O(n log n)、空间 O(1)。

**答案（Python 3）：**

```python
def heap_sort(nums):
    '''堆排序（升序）：原地建大顶堆 + 依次取堆顶，时间 O(n log n)、空间 O(1)'''
    n = len(nums)

    def sift_down(start, end):
        # 在 [0, end) 范围内把 nums[start] 下沉到正确位置，维护大顶堆
        i = start
        while 2 * i + 1 < end:
            child = 2 * i + 1                               # 左孩子
            if child + 1 < end and nums[child + 1] > nums[child]:
                child += 1                                  # 选两个孩子中较大的
            if nums[i] >= nums[child]:
                break                                       # 父节点已不小于孩子，结束
            nums[i], nums[child] = nums[child], nums[i]     # 交换后继续下沉
            i = child

    # 1) 原地建大顶堆：从最后一个非叶子节点 n//2 - 1 开始依次下沉
    for i in range(n // 2 - 1, -1, -1):
        sift_down(i, n)
    # 2) 排序：堆顶（最大值）与末尾交换，堆大小减一，堆顶下沉调整
    for end in range(n - 1, 0, -1):
        nums[0], nums[end] = nums[end], nums[0]
        sift_down(0, end)
    return nums

if __name__ == '__main__':
    print(heap_sort([5, 3, 8, 1, 9, 2]))    # [1, 2, 3, 5, 8, 9]
```

**解析：**
自底向上建堆（从 n//2-1 逐个下沉）为 O(n)；之后 n-1 次取堆顶各下沉 O(log n)，整体 O(n log n)、原地空间 O(1)。


### Tree-002-015 | ★★★★☆

场景题手撕：100G 数据找 Top10（字节电商后端面经原题：100G 的数据（如海量字符串/URL），内存只有 1G，怎么找出出现次数最多的 Top10，并把核心代码写出来）。要求：哈希分片把相同 key 切到同一小文件 → 每个小文件用 HashMap 统计频次并用大小为 10 的小顶堆保留局部 Top10 → 合并所有小文件的 Top10 再用小顶堆选出全局 Top10。

**答案（Python 3）：**

```python
import os
import hashlib
import heapq
from collections import Counter

def top10_of_big_file(big_file, k=10, split_num=1000, tmp_dir='./split'):
    '''100G 数据、1G 内存找出现次数 Top10：哈希分片 -> 局部统计 + 小顶堆 -> 归并'''
    os.makedirs(tmp_dir, exist_ok=True)

    # 1) 哈希分片：hash(key) % split_num，相同字符串必进同一小文件，每片约 100M 可载入内存
    files = [open(os.path.join(tmp_dir, 'part_%d' % i), 'w', encoding='utf-8')
             for i in range(split_num)]
    with open(big_file, 'r', encoding='utf-8') as f:
        for line in f:
            key = line.strip()
            idx = int(hashlib.md5(key.encode('utf-8')).hexdigest(), 16) % split_num
            files[idx].write(key + '\n')
    for fp in files:
        fp.close()

    # 2) 逐个小文件用 HashMap 统计频次，用大小为 k 的小顶堆保留局部 Top k
    global_heap = []    # (次数, 字符串) 的小顶堆，堆顶为当前第 k 大
    for i in range(split_num):
        cnt = Counter()
        with open(os.path.join(tmp_dir, 'part_%d' % i), 'r', encoding='utf-8') as fp:
            for line in fp:
                cnt[line.strip()] += 1
        local_heap = []
        for s, c in cnt.items():
            if len(local_heap) < k:
                heapq.heappush(local_heap, (c, s))
            elif c > local_heap[0][0]:
                heapq.heapreplace(local_heap, (c, s))
        # 3) 归并：各小文件的局部 Top k 再过一遍全局小顶堆，得全局 Top k
        for c, s in local_heap:
            if len(global_heap) < k:
                heapq.heappush(global_heap, (c, s))
            elif c > global_heap[0][0]:
                heapq.heapreplace(global_heap, (c, s))
    return sorted(global_heap, key=lambda x: -x[0])
```

**解析：**
核心三步：hash(key)%1000 分片保证同一 key 落在同一小文件（单文件可入内存）→ 每片 HashMap 计数 + 大小为 10 的小顶堆取局部 Top10 → 所有局部 Top10 归并再过一次小顶堆；全程顺序 IO，内存只需 O(分片数×10)。

