### LinkedList-002-001 | ★★★★☆

反转链表。给定单链表的头节点 head，将链表反转并返回新的头节点。要求：遍历反转（迭代）和递归两种写法都要会，空间复杂度 O(1)（迭代）。输入：head = [1,2,3,4,5]；输出：[5,4,3,2,1]。进阶追问：每 2 个一组翻转、区间 [left,right] 内翻转。

**答案（Python 3）：**

```python
# 单链表节点定义
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 写法一：迭代反转，时间 O(n)，空间 O(1)
    def reverseList(self, head: ListNode) -> ListNode:
        prev, cur = None, head
        while cur:
            nxt = cur.next      # 暂存后继
            cur.next = prev     # 反转当前指针
            prev, cur = cur, nxt
        return prev             # prev 即新头

    # 写法二：递归反转，时间 O(n)，空间 O(n) 递归栈
    def reverseListRec(self, head: ListNode) -> ListNode:
        if not head or not head.next:
            return head
        newHead = self.reverseListRec(head.next)  # 先反转后面部分
        head.next.next = head                     # 后继节点指回自己
        head.next = None                          # 断开原方向，防成环
        return newHead

# 进阶变体1：每 2 个一组翻转（两两交换）
def swapPairs(head: ListNode) -> ListNode:
    dummy = ListNode(0, head)
    prev = dummy
    while prev.next and prev.next.next:
        a, b = prev.next, prev.next.next
        prev.next, a.next, b.next = b, b.next, a  # 交换 a、b
        prev = a                                   # a 变为下一组前驱
    return dummy.next

# 进阶变体2：区间 [left, right] 翻转 —— 见 LinkedList-R2-003（哑节点 + 头插法）
```

**解析：**
迭代：prev/cur/nxt 三指针逐个改向，O(n) 时间 O(1) 空间；递归：先把 head.next 之后的部分反转好，再令 head.next.next=head 且 head.next=None。变体：每 2 个一组翻转见 swapPairs，区间翻转见 LinkedList-R2-003 的头插法。


### LinkedList-002-002 | ★★★★☆

K 个一组翻转链表。给定单链表头节点 head 和正整数 k，每 k 个节点一组进行翻转，返回修改后的链表。如果节点总数不是 k 的整数倍，最后剩余的节点保持原有顺序。不能只用 O(1) 额外空间修改节点值，必须真正交换节点。输入：head = [1,2,3,4,5], k = 2；输出：[2,1,4,3,5]。k=3 时输出 [3,2,1,4,5]。约束：链表长度 n 满足 1 <= n <= 5000，1 <= k <= n。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    def reverseKGroup(self, head: ListNode, k: int) -> ListNode:
        # 迭代实现：n=5000、k 较小时 n/k 层递归会超出 Python 默认递归栈，改为迭代
        dummy = ListNode(0, head)
        prev = dummy                     # 上一组翻转后的尾节点（也是本组的前驱）
        while True:
            # 1. 检查本组是否够 k 个节点，不够则保持原序直接返回
            node = prev
            for _ in range(k):
                node = node.next
                if not node:
                    return dummy.next
            # 2. 头插式翻转本组 k 个节点：逐个摘下插到 prev 后面
            tail = prev.next             # 本组原头节点，翻转后成为组尾
            cur = tail.next
            for _ in range(k - 1):
                nxt = cur.next           # 暂存后继
                cur.next = prev.next     # 头插到本组头部
                prev.next = cur
                cur = nxt
            tail.next = cur              # 原头节点接回下一组的开头（或 None），防成环
            # 3. prev 移到本组新尾（原头节点），继续处理下一组
            prev = tail
```

**解析：**
先检查本组是否够 k 个（不够保持原序返回），递归处理后续部分得到 prev，再把本组 k 个节点头插式接到 prev 前。时间 O(n)，真正交换节点而非改值。


### LinkedList-002-003 | ★★★★☆

反转链表 II。给定单链表头节点 head 以及整数 left、right（1 <= left <= right <= 链表长度），将链表中从第 left 个节点到第 right 个节点这一段反转，返回反转后的链表。要求一趟扫描完成。输入：head = [1,2,3,4,5], left = 2, right = 4；输出：[1,4,3,2,5]。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 一趟扫描：哑节点定位 left 的前驱 prev，头插法把段内节点逐个搬到 prev 后面
    def reverseBetween(self, head: ListNode, left: int, right: int) -> ListNode:
        dummy = ListNode(0, head)
        prev = dummy
        for _ in range(left - 1):       # prev 走到第 left 个节点的前驱
            prev = prev.next
        cur = prev.next                 # 段内第一个节点，翻转后成为段尾
        for _ in range(right - left):   # 只需搬 right-left 个节点
            moved = cur.next            # 摘下 cur 的后继
            cur.next = moved.next       # cur 越过 moved
            moved.next = prev.next      # moved 头插到 prev 之后
            prev.next = moved
        return dummy.next
```

**解析：**
哑节点定位 left 前驱 prev，用头插法把 cur 的后继逐个搬到 prev 之后，共 right-left 次，一趟扫描、O(1) 空间。


### LinkedList-002-004 | ★★★★☆

环形链表。给定一个链表的头节点 head，判断链表中是否存在环：如果链表中某个节点可以通过连续跟踪 next 指针再次到达它，则存在环。存在返回 true，否则返回 false。要求用 O(1) 空间（快慢指针）解决。输入：head = [3,2,0,-4], pos = 1（尾节点连接到下标 1 的节点）；输出：true。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 快慢指针：slow 一次 1 步、fast 一次 2 步，有环必相遇，无环 fast 到 None
    def hasCycle(self, head: ListNode) -> bool:
        slow = fast = head
        while fast and fast.next:
            slow = slow.next
            fast = fast.next.next
            if slow is fast:    # 同一节点对象即相遇
                return True
        return False
```

**解析：**
快慢指针：slow 每走 1 步 fast 走 2 步，有环二者必在环内相遇，无环 fast 先到 None；O(n)/O(1)。


### LinkedList-002-005 | ★★★★☆

环形链表 II。给定链表头节点 head，若链表中有环，返回入环的第一个节点；无环返回 null。要求不修改链表且空间复杂度 O(1)：先快慢指针判断相遇，再让一个指针从头部出发与相遇点同步前进，再次相遇点即入环点。输入：head = [3,2,0,-4], pos = 1；输出：返回下标为 1 的节点。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 相遇后一指针放回头部，两指针同速前进，再相遇处即入环点
    # 数学：头到入环 a、入环到相遇 b、环剩余 c，由 2(a+b)=a+b+n(b+c) 推出 a=c
    def detectCycle(self, head: ListNode) -> ListNode:
        slow = fast = head
        while fast and fast.next:
            slow = slow.next
            fast = fast.next.next
            if slow is fast:
                p = head
                while p is not slow:
                    p = p.next
                    slow = slow.next
                return p
        return None
```

**解析：**
注释"由 2(a+b)=a+b+n(b+c) 推出 a=c"不够严谨：严格为 a = c + (n-1)(b+c)，即 a 比 c 多整若干圈；两指针同速前进时整圈部分自动抵消，入环点结论不变。

### LinkedList-002-006 | ★★★★☆

相交链表。给定两个单链表头节点 headA、headB，找出并返回两链表相交的起始节点；若不相交返回 null。整个链表结构中不存在环，函数返回后不得破坏原链表结构，要求时间 O(m+n)、空间 O(1)（双指针互相切换遍历）。输入：intersectVal = 8, listA = [4,1,8,4,5], listB = [5,0,1,8,4,5]（相交节点为 8）；输出：返回值为 8 的节点。阿里面经追问版本：在空间复杂度必须为 O(1) 的前提下两个链表怎么找交点。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # O(1) 空间双指针：a 走完 A 接着走 B，b 走完 B 接着走 A，
    # 两者总路程相等（a+b），长度差被抵消；相交则在交点相遇，不相交则同时为 None
    def getIntersectionNode(self, headA: ListNode, headB: ListNode) -> ListNode:
        a, b = headA, headB
        while a is not b:
            a = a.next if a else headB
            b = b.next if b else headA
        return a
```
**解析：**
双指针走完自己的链表就切换到另一条头部，总路程相等抵消长度差，相交处相遇、不相交则同时为 None 退出；O(m+n)/O(1)，不破坏链表结构。


### LinkedList-002-007 | ★★★★☆

合并两个有序链表。将两个升序链表 head1、head2 合并为一个新的升序链表并返回，新链表由拼接给定链表的全部节点组成。输入：l1 = [1,2,4], l2 = [1,3,4]；输出：[1,1,2,3,4,4]。要求会迭代与递归两种写法。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 写法一：迭代，哑节点 + tail 依次摘取较小节点，O(m+n)/O(1)
    def mergeTwoLists(self, head1: ListNode, head2: ListNode) -> ListNode:
        dummy = ListNode()
        tail = dummy
        while head1 and head2:
            if head1.val <= head2.val:
                tail.next, head1 = head1, head1.next
            else:
                tail.next, head2 = head2, head2.next
            tail = tail.next
        tail.next = head1 if head1 else head2   # 直接拼接剩余部分
        return dummy.next

    # 写法二：递归，较小头做新头，其 next 指向剩余部分的合并结果，O(m+n)/O(m+n)
    def mergeTwoListsRec(self, head1: ListNode, head2: ListNode) -> ListNode:
        if not head1:
            return head2
        if not head2:
            return head1
        if head1.val <= head2.val:
            head1.next = self.mergeTwoListsRec(head1.next, head2)
            return head1
        head2.next = self.mergeTwoListsRec(head1, head2.next)
        return head2
```

**解析：**
迭代：哑节点 + tail 依次摘取较小节点，O(m+n)/O(1)；递归：较小头作新头，其 next 指向剩余部分的合并结果。


### LinkedList-002-008 | ★★★★☆

合并 K 个升序链表（字节后端二面现场手撕题）。给定一个链表数组 lists，其中每个链表已按升序排列，将所有链表合并为一个升序链表并返回。输入：lists = [[1,4,5],[1,3,4],[2,6]]；输出：[1,1,2,3,4,4,5,6]。约束：k == lists.length，0 <= k <= 10^4，要求讨论时间复杂度（小顶堆 O(N log k) 或分治两两合并）。

**答案（Python 3）：**

```python
import heapq

class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 写法一：小顶堆，时间 O(N log k)，N 为总节点数、k 为链表条数
    def mergeKLists(self, lists) -> ListNode:
        dummy = ListNode()
        tail = dummy
        # (节点值, 链表编号, 节点)：编号用于值相等时比较，避免比较 ListNode 对象
        heap = [(node.val, i, node) for i, node in enumerate(lists) if node]
        heapq.heapify(heap)
        while heap:
            _, i, node = heapq.heappop(heap)
            tail.next = node
            tail = tail.next
            if node.next:
                heapq.heappush(heap, (node.next.val, i, node.next))
        return dummy.next

    # 写法二：分治两两合并，同样 O(N log k)，递归/迭代深度 O(log k)
    def mergeKListsDC(self, lists):
        if not lists:
            return None
        n, interval = len(lists), 1
        while interval < n:
            for i in range(0, n - interval, interval * 2):
                lists[i] = self._merge(lists[i], lists[i + interval])
            interval *= 2
        return lists[0]

    def _merge(self, a, b):
        dummy = tail = ListNode()
        while a and b:
            if a.val <= b.val:
                tail.next, a = a, a.next
            else:
                tail.next, b = b, b.next
            tail = tail.next
        tail.next = a if a else b
        return dummy.next
```

**解析：**
小顶堆 O(N log k)：堆元素为 (节点值, 链表编号, 节点)，编号避免值相等时比较节点对象；等价写法为分治两两合并，同为 O(N log k)，优于顺序两两合并的 O(Nk)。


### LinkedList-002-009 | ★★★★☆

重排链表。给定单链表 L：L0→L1→…→Ln-1→Ln，重新排列为 L0→Ln→L1→Ln-1→L1 的交替形式（即 L0→Ln→L1→Ln-1→…），不能只是修改节点值，必须实际交换节点。输入：head = [1,2,3,4,5]；输出：[1,5,2,4,3]。标准解法：找中点 + 反转后半段 + 交替合并。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    def reorderList(self, head: ListNode) -> None:
        """原地重排为 L0->Ln->L1->Ln-1->...，O(n)/O(1)，真实交换节点"""
        if not head or not head.next:
            return
        # 1. 快慢指针找中点，slow 停在前半段末尾
        slow = fast = head
        while fast.next and fast.next.next:
            slow, fast = slow.next, fast.next.next
        # 2. 反转后半段并与前半段断开
        second, slow.next, prev = slow.next, None, None
        while second:
            second.next, prev, second = prev, second, second.next
        # 3. 前半段 first 与反转后的后半段 second 交替拼接
        first, second = head, prev
        while second:
            tmp1, tmp2 = first.next, second.next
            first.next = second
            second.next = tmp1
            first, second = tmp1, tmp2
```

**解析：**
三步走：快慢指针找中点、反转后半段、前后两段交替拼接；O(n) 时间 O(1) 空间，真实改指针而非改值。


### LinkedList-002-010 | ★★★★☆

排序奇升偶降链表（字节补充高频题）。给定一个单链表，第 1、3、5… 个节点构成升序子序列，第 2、4、6… 个节点构成降序子序列，即链表形如 1→8→3→6→5→4（奇数位升序、偶数位降序）。请将其还原成一个整体有序的链表并返回头节点。输入：1→8→3→6→5→4；输出：1→3→4→5→6→8。要求：按奇偶位拆分成两条链表，反转降序链表后归并合并，O(n) 时间。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    def sortOddEvenList(self, head: ListNode) -> ListNode:
        # 1. 按位置奇偶拆成两条链表（奇数位原升序，偶数位原降序）
        odd = oddHead = ListNode(0)
        even = evenHead = ListNode(0)
        cur, idx = head, 1
        while cur:
            if idx % 2:
                odd.next, odd = cur, cur
            else:
                even.next, even = cur, cur
            cur, idx = cur.next, idx + 1
        odd.next = even.next = None
        # 2. 反转偶数位链表：降序变升序
        prev = None
        cur = evenHead.next
        while cur:
            cur.next, prev, cur = prev, cur, cur.next
        # 3. 归并合并两条升序链表
        l1, l2 = oddHead.next, prev
        dummy = tail = ListNode(0)
        while l1 and l2:
            if l1.val <= l2.val:
                tail.next, l1 = l1, l1.next
            else:
                tail.next, l2 = l2, l2.next
            tail = tail.next
        tail.next = l1 if l1 else l2
        return dummy.next
```

**解析：**
按位置奇偶拆成两条链表，反转偶数位（原降序）链得到升序，再标准归并合并；O(n) 时间 O(1) 额外空间。


### LinkedList-002-011 | ★★★★☆

回文链表。给定单链表头节点 head，判断该链表是否为回文链表，返回布尔值。进阶要求：时间 O(n)、空间 O(1)——快慢指针找中点，反转后半段后逐一比对。输入：head = [1,2,2,1]；输出：true。输入：head = [1,2]；输出：false。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # O(n)/O(1)：快慢指针找中点 -> 反转后半段 -> 逐一比对
    def isPalindrome(self, head: ListNode) -> bool:
        slow = fast = head
        while fast and fast.next:
            slow, fast = slow.next, fast.next.next
        # 反转 slow 及之后的节点（后半段）
        prev = None
        while slow:
            slow.next, prev, slow = prev, slow, slow.next
        # prev 为后半段反转后的头，与前半段逐值比对
        while prev:
            if head.val != prev.val:
                return False
            head, prev = head.next, prev.next
        return True
```

**解析：**
快慢指针找中点后反转后半段，与前半段逐值比对，达到 O(n)/O(1)；比对会改坏后半段指向，面试可补一句：再反转一次接回即可恢复原链表。


### LinkedList-002-012 | ★★★★☆

删除链表的倒数第 N 个结点。给定链表头节点 head 和整数 n，删除链表倒数第 n 个节点并返回头节点，要求一趟扫描实现（快慢指针，快指针先走 n+1 步）。输入：head = [1,2,3,4,5], n = 2；输出：[1,2,3,5]。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 一趟扫描：哑节点 + 快指针先走 n+1 步，slow 停在倒数第 n 个节点的前驱
    def removeNthFromEnd(self, head: ListNode, n: int) -> ListNode:
        dummy = ListNode(0, head)
        fast = slow = dummy
        for _ in range(n + 1):
            fast = fast.next
        while fast:
            fast, slow = fast.next, slow.next
        slow.next = slow.next.next
        return dummy.next
```

**解析：**
哑节点 + 快指针先走 n+1 步，使 slow 停在待删节点的前驱，一趟扫描完成删除；哑节点统一处理删头的情况。


### LinkedList-002-013 | ★★★★☆

排序链表（要求手撕归并排序应用于链表）。给定链表头节点 head，将其按升序排列并返回排序后的链表。要求时间复杂度 O(n log n)，空间 O(log n)（递归栈）：快慢指针找中点断开，递归排序两段，再合并两个有序链表。输入：head = [4,2,1,3]；输出：[1,2,3,4]。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 链表归并排序：时间 O(n log n)，递归栈 O(log n)
    def sortList(self, head: ListNode) -> ListNode:
        if not head or not head.next:
            return head
        # 1. 快慢指针找中点并断开（fast 先走一步，保证偶数长度时中点偏左）
        slow, fast = head, head.next
        while fast and fast.next:
            slow, fast = slow.next, fast.next.next
        mid = slow.next
        slow.next = None
        # 2. 递归排序两段，3. 合并两个有序链表
        return self._merge(self.sortList(head), self.sortList(mid))

    def _merge(self, a, b):
        dummy = tail = ListNode()
        while a and b:
            if a.val <= b.val:
                tail.next, a = a, a.next
            else:
                tail.next, b = b, b.next
            tail = tail.next
        tail.next = a if a else b
        return dummy.next
```

**解析：**
归并排序：快慢指针找中点断开（fast 先走一步保证偶数长度中点偏左），递归排序两段再合并；O(n log n) 时间，递归栈 O(log n)。


### LinkedList-002-014 | ★★★★☆

两数相加。给定两个非空链表表示两个非负整数，每位数字按逆序存储（个位在链表头），将两数相加并返回同样逆序存储的和链表。输入：l1 = [2,4,3], l2 = [5,6,4]（表示 342 + 465）；输出：[7,0,8]（表示 807）。追问变体：若数字是正序存储怎么做（可先反转或用栈）。

**答案（Python 3）：**

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

class Solution:
    # 模拟竖式加法：对应位 + 进位，divmod 拆进位/本位；循环条件带 carry 覆盖最高位进位
    def addTwoNumbers(self, l1: ListNode, l2: ListNode) -> ListNode:
        dummy = tail = ListNode()
        carry = 0
        while l1 or l2 or carry:
            s = (l1.val if l1 else 0) + (l2.val if l2 else 0) + carry
            carry, digit = divmod(s, 10)
            tail.next = ListNode(digit)
            tail = tail.next
            l1 = l1.next if l1 else None
            l2 = l2.next if l2 else None
        return dummy.next

# 追问变体（数字正序存储，高位在头）：
#   方法一：先反转两条链表 -> 按本题逻辑相加 -> 再反转结果链表；
#   方法二（不改链表）：两链表值分别压入两个栈，从栈顶（低位）弹出相加，头插法建结果链表。
```

**解析：**
竖式加法模拟：对应位与 carry 相加后 divmod 拆进位/本位，循环条件带上 carry 覆盖最高位进位；正序存储变体：先反转两条链表再算、最后反转结果，或不改链表用双栈。

