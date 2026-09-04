### Concurrency-001-001 | ★★★★☆

手写单例模式（双重检查锁 DCL 版）。用线程安全的方式手写懒汉式单例：私有构造器 + 静态实例，double-check 写法（第一次判空免锁、加锁后二次判空、实例字段用 volatile 防止指令重排导致的半初始化对象逸出），并能口述为什么两次判空都不能省、volatile 在其中的作用；补充静态内部类/枚举两种天然线程安全的写法。

**答案（Python 3）：**

```python
import threading

class Singleton:
    '''懒汉式单例：双重检查锁（DCL）线程安全版（Python 实现 + Java 版对照）'''
    _instance = None
    _lock = threading.Lock()

    def __init__(self):
        # 私有化构造：外部必须走 get_instance()
        raise RuntimeError('use Singleton.get_instance()')

    @classmethod
    def get_instance(cls):
        # 第一次判空：实例已存在时免锁直接返回，避免每次请求都抢锁（性能）
        if cls._instance is None:
            with cls._lock:
                # 第二次判空：防止两个线程同时通过第一次判空后排队，
                # 第一个拿到锁的线程创建完实例，第二个拿锁的线程不再重复创建
                if cls._instance is None:
                    cls._instance = object.__new__(cls)
                    # Java 中实例字段需 volatile：new 分「分配内存 -> 初始化 -> 引用赋值」
                    # 三步，重排后其他线程可能拿到未初始化完成的半成品对象（逸出）
        return cls._instance

# Java 版对照：
# class Singleton {
#     private static volatile Singleton instance;      // volatile 防指令重排 + 保证可见性
#     private Singleton() {}                           // 私有构造器
#     public static Singleton getInstance() {
#         if (instance == null) {                      // 第一次判空（免锁）
#             synchronized (Singleton.class) {
#                 if (instance == null) {              // 第二次判空（防重复创建）
#                     instance = new Singleton();
#                 }
#             }
#         }
#         return instance;
#     }
# }
# 补充两种天然线程安全写法：
# 1) 静态内部类：private static class Holder { static final Singleton I = new Singleton(); }
#    利用类加载机制实现懒加载 + 线程安全；
# 2) 枚举：enum Singleton { INSTANCE; }，JVM 保证单例，且防反射/反序列化破坏。
```

**解析：**
两次判空缺一不可：第一次免锁提升性能、第二次防止并发等待中重复创建；volatile 保证 new 的三步不重排、实例对其他线程立即可见；静态内部类与枚举是 Java 中免锁的替代实现。


### Concurrency-001-002 | ★★★★☆

多线程交替打印 ABC（C++/Java 技术面高频手撕题）。编写程序创建 3 个线程，线程 A 打印 "A"、线程 B 打印 "B"、线程 C 打印 "C"，要求三者交替循环打印 ABC ABC ABC 各 10 轮。要求：用互斥锁 + 条件变量（Java 为 synchronized + wait/notifyAll 或 ReentrantLock + Condition），每个线程按 (轮次 % 3) 判断是否轮到自己，不是则等待；能在现场说清虚假唤醒需用 while 判断条件。

**答案（Python 3）：**

```python
import threading

N_ROUNDS = 10
cond = threading.Condition()     # 互斥锁 + 条件变量
turn = 0                         # 0 -> 打 A，1 -> 打 B，2 -> 打 C

def printer(name, idx):
    global turn
    for _ in range(N_ROUNDS):
        with cond:
            # 必须用 while 判断：防止虚假唤醒，以及被唤醒时还没轮到自己
            while turn % 3 != idx:
                cond.wait()
            print(name, end='', flush=True)
            turn += 1
            cond.notify_all()    # 唤醒其他等待线程重新竞争

threads = [threading.Thread(target=printer, args=(n, i)) for i, n in enumerate('ABC')]
for t in threads:
    t.start()
for t in threads:
    t.join()
print()   # 输出 ABCABCABC... 共 10 轮
```

**解析：**
三线程共享 turn 计数与条件变量，按 turn % 3 判断是否轮到自己，不是则 wait；用 while 而非 if 复查条件防虚假唤醒，打印后 notify_all 推进轮次。


### Concurrency-001-003 | ★★★★☆

两个线程交替打印 1~100（牛客面经高频手撕题：两个线程交替打印 1-100 的奇偶数，线程 1 只打奇数、线程 2 只打偶数，按 1,2,3,...,100 的顺序输出）。要求：共享一个计数器与同一把锁，线程在轮到自己（count % 2 == 自己编号）时打印并 notify 唤醒对方、否则 wait；需在 while 中判断条件防止虚假唤醒；追问：用 ReentrantLock + Condition、Semaphore 或 LockSupport.park/unpark 怎么改写。

**答案（Python 3）：**

```python
import threading

count = 0
cond = threading.Condition()

def printer(want_odd):
    global count
    while True:
        with cond:
            # 轮到自己：即将打印的 count+1 的奇偶与自己的目标一致；while 防虚假唤醒
            while count < 100 and (((count + 1) % 2 == 1) != want_odd):
                cond.wait()
            if count >= 100:         # 打印完毕，唤醒对方一起退出
                cond.notify_all()
                return
            count += 1               # 先加一再打印：count=0 时奇数线程打出 1
            print(count, flush=True)
            cond.notify_all()        # 唤醒对方打印下一个数

t1 = threading.Thread(target=printer, args=(True,))    # 线程 1 只打奇数
t2 = threading.Thread(target=printer, args=(False,))   # 线程 2 只打偶数
t1.start(); t2.start(); t1.join(); t2.join()
# 按 1, 2, 3, ..., 100 的顺序输出
# 追问改写：Semaphore(0/1) 交替 acquire/release；ReentrantLock + Condition（Java）；
# LockSupport.park/unpark（Java），本质都是「条件等待 + 精确唤醒」
```

**解析：**
共享计数器 + 一把锁一个条件变量，线程按 (count+1) 的奇偶判断是否轮到自己，打印后 notify 唤醒对方、否则 wait；while 复查防虚假唤醒，结束时 notify_all 保证双方都能退出。


### Concurrency-001-004 | ★★★★☆

手写生产者-消费者模型（技术面高频手撕题：用锁 + 条件变量实现一个有界缓冲区）。实现一个容量为 N 的阻塞缓冲区 BlockingBuffer：put(item) 在缓冲区满时阻塞；take() 在缓冲区空时阻塞。要求：Java 用 synchronized + wait/notifyAll（或 ReentrantLock + 两个 Condition notFull/notEmpty）实现，C++ 用 mutex + condition_variable；生产者、消费者各启动多个线程验证不丢失、不重复、不越界；追问：为什么判断条件要用 while 而不是 if，以及直接用 ArrayBlockingQueue/LinkedBlockingQueue 的等价写法。

**答案（Python 3）：**

```python
import threading
from collections import deque

class BlockingBuffer:
    '''容量 N 的有界阻塞缓冲区：一把互斥锁 + notFull/notEmpty 两个条件变量'''
    def __init__(self, capacity):
        self.buf = deque()
        self.cap = capacity
        self.lock = threading.Lock()
        self.not_full = threading.Condition(self.lock)    # 生产者等它
        self.not_empty = threading.Condition(self.lock)   # 消费者等它

    def put(self, item):
        with self.not_full:
            # 必须 while 而非 if：被唤醒后条件可能又被其他线程抢占改变（含虚假唤醒）
            while len(self.buf) == self.cap:
                self.not_full.wait()
            self.buf.append(item)
            self.not_empty.notify()    # 通知消费者

    def take(self):
        with self.not_empty:
            while not self.buf:
                self.not_empty.wait()
            item = self.buf.popleft()
            self.not_full.notify()     # 通知生产者
            return item

# 多生产者多消费者验证：不丢失、不重复、不越界
if __name__ == '__main__':
    buf = BlockingBuffer(5)
    produced, consumed = [], []
    plock, clock = threading.Lock(), threading.Lock()

    def producer(pid):
        for i in range(100):
            item = (pid, i)
            buf.put(item)
            with plock:
                produced.append(item)

    def consumer():
        for _ in range(100):
            item = buf.take()
            with clock:
                consumed.append(item)

    threads = [threading.Thread(target=producer, args=(p,)) for p in range(2)] + [threading.Thread(target=consumer) for _ in range(2)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert sorted(produced) == sorted(consumed)    # 校验：200 条全部对上
    print('ok')

# 等价写法：from queue import Queue; q = Queue(5)，q.put/q.get 自带阻塞语义
```

**解析：**
有界缓冲区 = 互斥锁 + notFull/notEmpty 双条件变量，满则 put 阻塞、空则 take 阻塞；判断必须用 while 循环复查（防虚假唤醒与条件被抢占），Python 可直接用 queue.Queue 等价替换。


### Concurrency-001-005 | ★★★★★

手写线程池。实现一个固定大小的工作线程池 ThreadPool(workers)：内部维护任务阻塞队列与 workers 个工作线程；submit(task) 提交任务入队（队满可阻塞或拒绝）；工作线程循环从队列取任务执行；提供 shutdown() 停止接收新任务并让线程处理完队列后退出（用取消标志 + 唤醒所有等待线程）。要求现场写出任务队列的互斥与条件等待逻辑，并口述与 java.util.concurrent.ThreadPoolExecutor 的核心参数（corePoolSize、maximumPoolSize、keepAliveTime、workQueue、拒绝策略）的对应关系。

**答案（Python 3）：**

```python
import threading

class BlockingQueue:
    '''手写阻塞任务队列：互斥锁 + 两个条件变量'''
    def __init__(self, maxsize=0):
        self._items = []
        self._maxsize = maxsize
        self._lock = threading.Lock()
        self._not_empty = threading.Condition(self._lock)   # 消费者等
        self._not_full = threading.Condition(self._lock)    # 生产者等

    def put(self, item, block=True):
        with self._not_full:
            while self._maxsize and len(self._items) >= self._maxsize:
                if not block:
                    raise RuntimeError('queue full, reject')    # 队满拒绝
                self._not_full.wait()                           # 队满阻塞
            self._items.append(item)
            self._not_empty.notify()

    def get(self):
        with self._not_empty:
            while not self._items:          # while 防虚假唤醒
                self._not_empty.wait()
            item = self._items.pop(0)
            self._not_full.notify()
            return item

class ThreadPool:
    '''固定大小线程池：workers 个工作线程循环从队列取任务执行'''
    def __init__(self, workers, queue_size=0):
        self.task_queue = BlockingQueue(queue_size)
        self.workers = []
        self._shutdown = False
        self._lock = threading.Lock()
        for _ in range(workers):
            t = threading.Thread(target=self._worker, daemon=True)
            t.start()
            self.workers.append(t)

    def _worker(self):
        while True:
            task = self.task_queue.get()    # 阻塞取任务
            if task is None:                # 停止哨兵：处理完队列后退出
                break
            try:
                task()
            except Exception as e:
                print('task error:', e)

    def submit(self, task):
        with self._lock:
            if self._shutdown:
                raise RuntimeError('pool shutdown, reject')   # 停止后拒绝新任务
        self.task_queue.put(task)         # 队满时阻塞（也可改为非阻塞拒绝策略）

    def shutdown(self):
        with self._lock:
            if self._shutdown:
                return
            self._shutdown = True         # 取消标志：停止接收新任务
        for _ in self.workers:            # 每个工作线程投递一个哨兵，唤醒它们排空队列后退出
            self.task_queue.put(None)
        for t in self.workers:
            t.join()

if __name__ == '__main__':
    pool = ThreadPool(workers=3)
    for i in range(10):
        pool.submit(lambda i=i: print('run task', i))
    pool.shutdown()
    print('pool drained')

# 与 Java ThreadPoolExecutor 参数对应：workers = corePoolSize = maximumPoolSize（固定池）、
# queue_size = workQueue 容量、shutdown = shutdown() + 拒绝策略、固定池不涉及 keepAliveTime
```

**解析：**
手写阻塞队列展示任务队列的互斥与条件等待，工作线程循环 get/执行；shutdown 用取消标志 + 每线程投递 None 哨兵唤醒并排空队列后退出，对应 Java ThreadPoolExecutor 的核心/最大线程数、工作队列与拒绝策略。


### Concurrency-001-006 | ★★★★★

实现一个令牌桶限流器 TokenBucket（牛客面经手撕题原题要求：支持初始化桶的容量（最大令牌数）和令牌生成速率（每秒生成多少个令牌），线程安全）。实现 acquire()/tryAcquire()：请求到来时若桶中有令牌则取走一个并放行，否则拒绝/阻塞；令牌按速率匀速产生、桶满则丢弃多余令牌。要求：不启动定时线程，采用惰性补充——每次调用时按 (当前时间 - 上次时间) * 速率 补充令牌并 min(容量, 当前+增量) 封顶，多线程下加锁或用 CAS 保证原子性。示例：TokenBucket(10, 5) 表示桶容量 10、每秒 5 个令牌；突发 20 个请求时前 10 个立即放行，之后按 5 个/秒放行。

**答案（Python 3）：**

```python
import time
import threading

class TokenBucket:
    '''令牌桶限流器：桶容量 capacity、速率 rate 个/秒，惰性补充 + 加锁，线程安全'''
    def __init__(self, capacity, rate):
        self.capacity = capacity
        self.rate = rate
        self.tokens = float(capacity)        # 初始满桶
        self.last_time = time.monotonic()    # 上次补充时间
        self.lock = threading.Lock()

    def _refill(self):
        '''不启动定时线程：每次调用时按流逝时间惰性补充令牌，封顶为桶容量'''
        now = time.monotonic()
        self.tokens = min(self.capacity, self.tokens + (now - self.last_time) * self.rate)
        self.last_time = now

    def try_acquire(self):
        '''非阻塞：桶中有令牌则取走一个返回 True，否则拒绝返回 False'''
        with self.lock:
            self._refill()
            if self.tokens >= 1:
                self.tokens -= 1
                return True
            return False

    def acquire(self):
        '''阻塞版：等待令牌足够再放行'''
        while True:
            with self.lock:
                self._refill()
                if self.tokens >= 1:
                    self.tokens -= 1
                    return True
            time.sleep(1.0 / self.rate)      # 无令牌，睡一个生成周期再试

# 示例：TokenBucket(10, 5)：容量 10、每秒 5 个令牌
# 突发 20 个请求 => 前 10 个立即放行（存量令牌），之后按 5 个/秒匀速放行
```

**解析：**
惰性补充：tokens += (now-last)*rate 并 min 封顶，不依赖定时线程；try_acquire 非阻塞、acquire 阻塞等待，全程持锁保证多线程原子性（高并发可用 CAS 优化）。


### Concurrency-001-007 | ★★★★★

实现一个滑动窗口限流器（美团/快手实习面经手撕场景题：限制任意 1 秒内最多通过 N 个请求，写出代码）。实现 SlidingWindowRateLimiter(maxRequests, windowMillis)：allowRequest(timestamp) 返回当前请求是否放行。要求：用队列保存窗口内每次放行的时间戳，请求到来时先弹出所有早于 timestamp - windowMillis 的记录，若队列长度 < maxRequests 则放行并记录，否则拒绝；说明与固定窗口计数器相比没有"窗口边界突刺"问题，多线程场景需加锁或换成分段统计；追问：分布式下用 Redis ZSet 怎么实现同一逻辑。

**答案（Python 3）：**

```python
import threading
from collections import deque

class SlidingWindowRateLimiter:
    '''滑动窗口限流：任意 windowMillis 毫秒内最多放行 maxRequests 个请求'''
    def __init__(self, max_requests, window_millis):
        self.max_requests = max_requests
        self.window = window_millis / 1000.0      # 统一成秒
        self.records = deque()                    # 窗口内每次放行的时间戳
        self.lock = threading.Lock()

    def allow_request(self, timestamp):
        '''timestamp 单位为秒；返回当前请求是否放行'''
        with self.lock:
            # 1) 弹出所有早于 timestamp - window 的过期记录
            while self.records and self.records[0] <= timestamp - self.window:
                self.records.popleft()
            # 2) 窗口内放行次数未满则放行并记录
            if len(self.records) < self.max_requests:
                self.records.append(timestamp)
                return True
            return False

# 与固定窗口计数器相比：滑动窗口按真实时间滚动统计，任意 1 秒内都严格 <= N，
# 没有窗口边界突刺问题（固定窗口在两个窗口交界处可能瞬间放过 2N 个请求）。
# 分布式版（追问）：Redis ZSet，member=请求唯一 id、score=时间戳：
#   ZREMRANGEBYSCORE key 0 (ts - window) -> ZCARD key < N 则 ZADD key ts id 放行，EXPIRE 兜底
```

**解析：**
队列保存窗口内每次放行的时间戳，请求先淘汰过期记录再判断队列长度，均摊高效；多线程加锁保护，分布式下用 Redis ZSet（score=时间戳）实现同一逻辑。


### Concurrency-001-008 | ★★★★☆

两个线程访问同一个共享变量（宇视嵌软线下手撕原题：两个线程访问同一个消息任务/计数器，应该怎么做？手撕对应的代码）。编写程序：启动两个线程各自对同一个全局计数器 message_task 自增 10000 次，不加锁时结果小于 20000（存在竞态），要求手写加互斥锁的正确版本：临界区前 lock、临界区后 unlock（Java 用 synchronized 块或 AtomicInteger.incrementAndGet + CAS 对比），并解释可见性与原子性问题。

**答案（Python 3）：**

```python
import threading

message_task = 0              # 两个线程共享的全局计数器
lock = threading.Lock()
N = 10000

def unsafe_add():
    global message_task
    for _ in range(N):
        message_task += 1     # 非原子：读-改-写三步可能交错，导致丢失更新，结果 < 20000

def safe_add():
    global message_task
    for _ in range(N):
        with lock:            # 互斥锁：临界区前 lock、临界区后 unlock，保证原子性与可见性
            message_task += 1

if __name__ == '__main__':
    # 版本一：不加锁，存在竞态，结果通常小于 20000
    t1 = threading.Thread(target=unsafe_add)
    t2 = threading.Thread(target=unsafe_add)
    t1.start(); t2.start(); t1.join(); t2.join()
    print('unsafe:', message_task)
    # 版本二：加互斥锁的正确版本，结果恒为 20000
    message_task = 0
    t1 = threading.Thread(target=safe_add)
    t2 = threading.Thread(target=safe_add)
    t1.start(); t2.start(); t1.join(); t2.join()
    print('safe:', message_task)
```

**解析：**
自增是读-改-写三步非原子操作，两线程交错会互相覆盖导致丢失更新（结果 < 20000）；临界区加互斥锁（Java 亦可用 AtomicInteger.incrementAndGet 的 CAS 无锁方案）同时解决原子性与可见性。


### Concurrency-001-009 | ★★★★☆

线程安全的 HashMap（C++/Java 技术面手撕题）。手写一个线程安全的哈希表 ThreadSafeHashMap<K, V>：支持 put(key, value)、get(key)、remove(key)。要求：对桶数组 + 链表（或红黑树）的基本结构手写实现；并发控制可选整表互斥锁（读写锁分离更佳），并能口述与 ConcurrentHashMap 的分段锁 / CAS + synchronized 桶头结点方案的差异；追问：扩容 rehash 在并发下要注意什么。

**答案（Python 3）：**

```python
import threading

class Node:
    __slots__ = ('key', 'val', 'next')

    def __init__(self, key, val):
        self.key = key
        self.val = val
        self.next = None

class ThreadSafeHashMap:
    '''线程安全哈希表：桶数组 + 链表（拉链法），整表互斥锁（读写锁分离更佳）'''
    def __init__(self, capacity=16, load_factor=0.75):
        self.cap = capacity
        self.load_factor = load_factor
        self.buckets = [None] * capacity
        self.size = 0
        self.lock = threading.RLock()

    def _index(self, key, cap=None):
        return hash(key) % (cap or self.cap)

    def put(self, key, value):
        with self.lock:                     # 临界区：写操作互斥
            idx = self._index(key)
            node = self.buckets[idx]
            while node:                     # 链表上存在同名 key 则更新
                if node.key == key:
                    node.val = value
                    return
                node = node.next
            new_node = Node(key, value)     # 头插法插入新节点
            new_node.next = self.buckets[idx]
            self.buckets[idx] = new_node
            self.size += 1
            if self.size / self.cap > self.load_factor:
                self._resize()              # 负载因子超限，扩容 rehash

    def get(self, key, default=None):
        with self.lock:
            node = self.buckets[self._index(key)]
            while node:
                if node.key == key:
                    return node.val
                node = node.next
            return default

    def remove(self, key):
        with self.lock:
            idx = self._index(key)
            node, prev = self.buckets[idx], None
            while node:
                if node.key == key:
                    if prev is None:
                        self.buckets[idx] = node.next
                    else:
                        prev.next = node.next
                    self.size -= 1
                    return True
                prev, node = node, node.next
            return False

    def _resize(self):
        # 扩容：并发下必须在锁内一次性完成 rehash，
        # 否则其他线程可能看到迁移到一半的桶结构而读到错误数据
        new_cap = self.cap * 2
        new_buckets = [None] * new_cap
        for head in self.buckets:
            node = head
            while node:
                nxt = node.next
                idx = self._index(node.key, new_cap)
                node.next = new_buckets[idx]
                new_buckets[idx] = node
                node = nxt
        self.buckets = new_buckets
        self.cap = new_cap

if __name__ == '__main__':
    m = ThreadSafeHashMap()
    def writer(base):
        for i in range(1000):
            m.put(base + i, i)
    ts = [threading.Thread(target=writer, args=(b,)) for b in (0, 1000, 2000)]
    for t in ts: t.start()
    for t in ts: t.join()
    assert m.size == 3000 and m.get(1500) == 500
    print('ok')
```

**解析：**
桶数组+链表手写基本结构，整表 RLock 保证 put/get/remove 原子（可升级为读写锁分离）；与 ConcurrentHashMap 的分段锁（JDK7）/ CAS+synchronized 桶头（JDK8）相比锁粒度更粗、吞吐更低；扩容 rehash 必须锁内一次完成或渐进式迁移，防止并发读写撕裂结构。

