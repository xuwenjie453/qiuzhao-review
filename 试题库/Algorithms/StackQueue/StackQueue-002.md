### StackQueue-002-001 | ★★★★☆

最小栈。设计一个支持 push、pop、top 操作，并能在常数时间内检索到最小元素的栈 MinStack：push(x) 入栈；pop() 删除栈顶；top() 获取栈顶；getMin() 获取栈中最小元素，每个函数时间复杂度都是 O(1)（辅助栈同步维护当前最小值，追问能否只用一个栈）。输入：["MinStack","push","push","push","getMin","pop","top","getMin"] 操作序列 push(-2)、push(0)、push(-3) 后 getMin() 输出 -3，pop 后 top() 输出 0，getMin() 输出 -2。

**答案（Python 3）：**

```python
class MinStack:
    '''最小栈：辅助栈与主栈同步压入当前最小值，每个操作 O(1)'''
    def __init__(self):
        self.stack = []
        self.min_stack = []

    def push(self, x):
        self.stack.append(x)
        cur_min = x if not self.min_stack else min(x, self.min_stack[-1])
        self.min_stack.append(cur_min)      # 同步记录 push 后栈内的最小值

    def pop(self):
        self.stack.pop()
        self.min_stack.pop()

    def top(self):
        return self.stack[-1]

    def getMin(self):
        return self.min_stack[-1]

# 追问：只用一个栈 -> 每层元素改存 (x, 当前最小值) 二元组即可
#   self.stack.append((x, min(x, self.stack[-1][1]) if self.stack else x))
#   top: self.stack[-1][0]   getMin: self.stack[-1][1]

# 验证：push(-2), push(0), push(-3) 后 getMin()=-3；pop 后 top()=0，getMin()=-2
```

**解析：**
辅助栈与主栈同步进退，栈顶永远保存当前栈内最小值，各操作 O(1)、空间 O(n)；单栈变体把每层元素改存 (值, 当前最小) 对，原理相同。


### StackQueue-002-002 | ★★★★☆

用栈实现队列。仅使用两个栈实现先入先出队列：支持 push（将元素放到队尾）、pop（从队首移除并返回元素）、peek（返回队首元素）、empty（判断是否为空），要求每个元素最多进出栈常数次、均摊 O(1)：入栈栈 + 出栈栈，出栈栈为空时把入栈栈全部倒入。输入：["MyQueue","push","push","peek","pop","empty"] 操作 push(1)、push(2) 后 peek() 输出 1，pop() 输出 1，empty() 输出 false。

**答案（Python 3）：**

```python
class MyQueue:
    '''两个栈实现队列：入栈栈 + 出栈栈，每个元素最多搬运一次，均摊 O(1)'''
    def __init__(self):
        self.in_stack = []
        self.out_stack = []

    def push(self, x):
        self.in_stack.append(x)

    def _shift(self):
        # 出栈栈为空时才把入栈栈整体倒入（保证 FIFO 顺序，且每个元素一生只倒一次）
        if not self.out_stack:
            while self.in_stack:
                self.out_stack.append(self.in_stack.pop())

    def pop(self):
        self._shift()
        return self.out_stack.pop()

    def peek(self):
        self._shift()
        return self.out_stack[-1]

    def empty(self):
        return not self.in_stack and not self.out_stack

# 验证：push(1), push(2) 后 peek()=1，pop()=1，empty()=False
```

**解析：**
关键规则：只在出栈栈为空时才把入栈栈一次性倒入，保证每个元素最多进出每个栈常数次，pop/peek 均摊 O(1)。


### StackQueue-002-003 | ★★★★☆

循环队列的入队操作（宇视嵌软线下手撕原题：一个线性队列要增加元素，应该怎么操作，现场写出对应的代码）。给定用数组实现的循环队列（front 队头指针、rear 队尾指针、MAX_SIZE 容量），手写 enqueue(value)：若队列已满返回 false 并提示；否则 rear = (rear + 1) % MAX_SIZE，arr[rear] = value，count 加一，返回 true。同时能口述判断队满的两种方式（牺牲一个空位 front == (rear+1)%MAX_SIZE，或用 count 计数）。

**答案（Python 3）：**

```python
class CircularQueue:
    '''数组实现的循环队列：front 指向队头，rear 指向队尾，count 记录元素个数'''
    def __init__(self, max_size):
        self.arr = [None] * max_size
        self.MAX_SIZE = max_size
        self.front = 0
        self.rear = 0
        self.count = 0

    def is_empty(self):
        return self.count == 0

    def is_full(self):
        # 判队满两种方式：1) count 计数；2) 牺牲一个空位：front == (rear + 1) % MAX_SIZE
        return self.count == self.MAX_SIZE

    def enqueue(self, value):
        '''入队：队满返回 False 并提示；否则 rear 循环后移一位再存值'''
        if self.is_full():
            print('queue is full')                        # 队满提示
            return False
        self.rear = (self.rear + 1) % self.MAX_SIZE       # 指针取模循环后移
        self.arr[self.rear] = value
        self.count += 1
        return True

    def dequeue(self):
        '''出队：front 循环后移一位并返回该元素'''
        if self.is_empty():
            return None
        self.front = (self.front + 1) % self.MAX_SIZE
        val = self.arr[self.front]
        self.count -= 1
        return val
```

**解析：**
入队先判满（count 计数法，或牺牲一格的 front==(rear+1)%MAX_SIZE 法），再 rear=(rear+1)%MAX_SIZE 后存值、count+1；取模运算让指针在数组内循环复用空间。

