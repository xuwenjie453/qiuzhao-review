### Java-001-001 | ★★★★★

HashMap 的底层数据结构是什么？JDK 7 和 JDK 8 有什么区别？

**答案：**
JDK 8 的 HashMap 是数组+链表+红黑树：数组是主体，hash 冲突的元素挂成链表；链表长度达到 8 且数组长度至少 64 时，链表转红黑树，把最坏查找从 O(n) 降到 O(log n)，节点删除或缩容后少于 6 个退化回链表。JDK 7 是数组+链表，采用头插法，扩容多线程下可能成环导致死循环；JDK 8 改成尾插法修掉了这个问题，但 HashMap 仍然不是线程安全的。默认容量 16、负载因子 0.75，元素数超过 容量×0.75 就扩容翻倍。

**解析：**
数组定位：`table[(n-1) & hash]`，容量恒为 2 的幂，使取模可以退化为位运算。hash 函数做了扰动：`h ^ (h >>> 16)`，把高位信息混入低位，让低位相同的 key 也能散开——因为按位与只用到低位。

JDK 7→8 的三点核心变化：①引入红黑树（TreeNode），防哈希碰撞攻击下的性能退化；②插入从头插改尾插（头插在并发扩容时会反转链表形成环）；③扩容优化：JDK 8 不再逐个重算 hash，利用"容量是 2 的幂"特性，元素新位置要么在原下标 j，要么在 j+oldCap，取决于 hash 在新增高位 bit 上是 0 还是 1，一次遍历拆成高低两条链。

为什么阈值是 8 和 6：泊松分布下负载因子 0.75 时单桶链长达到 8 的概率约千万分之一，8 是"几乎只在中毒场景触发"的防御值；退化阈值 6 留出缓冲避免在 7~8 之间来回树化/退化抖动。


### Java-001-002 | ★★★★★

讲一下 HashMap 的 put 流程。

**答案：**
JDK 8 的 put 流程：先对 key 的 hashCode 做高低位异或扰动；若数组未初始化先初始化（懒加载，首次 put 时分配）；用 (n-1)&hash 定位桶，桶为空直接新建节点放入；桶不空则比较首节点，key 相同就覆盖 value；首节点是 TreeNode 就走红黑树插入；否则沿链表尾插遍历，遇到相同 key 覆盖，遍历到尾则新建节点，插入后链长到 8 且数组够大就树化；最后 modCount 加一，size 超过阈值就扩容。putVal 整个方法没有锁，所以并发下会出现更新丢失。

**解析：**
细节要点：①判断"相同 key"的顺序是先比 hash、再 ==、再 equals——hash 不同直接短路，省去 equals 开销；②onlyIfAbsent 默认 false，即覆盖语义；③afterNodeAccess/afterNodeInsertion 是给 LinkedHashMap 留的钩子，实现 LRU 的访问序维护就在这里；④扩容触发点在插入之后检查 `++size > threshold`，因此容量 16 时放第 13 个元素会触发扩容。

扩容做什么：newTab 容量翻倍；旧表遍历拆成 lo/hi 两条链（保留相对顺序），`hash & oldCap == 0` 留原位，否则放 `原位+oldCap`；树节点同样拆，拆后节点数 <6 退化回链表。


### Java-001-003 | ★★★★☆

HashMap 扩容机制是怎样的？为什么扩容是 2 倍？

**答案：**
HashMap 在 size 超过 threshold（容量×0.75）时扩容：新建一个两倍容量的数组，把旧元素迁移过去。JDK 8 的迁移很巧：因为容量是 2 的幂，扩容后 mask 多出一个高位 bit，元素新位置只可能是原下标或"原下标+旧容量"，看 `hash & oldCap` 那一位是 0 还是 1 即可，不用重新计算 hash；一次遍历把每个桶拆成 lo、hi 两条链。两倍扩容保证容量始终是 2 的幂，维持位运算取模的高效和迁移的简单。

**解析：**
扩容成本：分配新数组 + 全量迁移，n 个元素一次扩容 O(n)。若能预估容量，构造时传入即可避免多次扩容；阿里规约建议 `initialCapacity = (需要存放元素个数 / 负载因子) + 1`。

树节点的扩容：红黑树同样按高低位拆成两棵树（split 时保留链表 next 便于退化），拆后某侧节点数 ≤ UNTREEIFY_THRESHOLD(6) 则转回链表。

JDK 7 对比：迁移时逐节点重算 `hash & (newCap-1)` 并头插进新桶，并发下有成环风险（详见 K-COL-004）。


### Java-001-004 | ★★★★★

HashMap 为什么线程不安全？ConcurrentHashMap 是怎么解决并发问题的？

**答案：**
HashMap 无任何同步，并发下有四类具体问题：put 丢失更新、JDK 7 头插扩容成环（CPU 飙高）、size 不准、迭代 fail-fast。JDK 8 的 ConcurrentHashMap 用"CAS + synchronized 锁单个桶头节点"实现细粒度并发：桶为空时 CAS 无锁插入；冲突时只锁该桶首节点，不同桶互不影响；扩容时支持多线程协助迁移，每个线程认领一段桶区间；size 用 baseCount + CounterCell 数组分段计数，类似 LongAdder。查询完全无锁，Node 的 val 和 next 用 volatile 保证可见性。

**解析：**
关键方法 putVal 的并发控制：`casTabAt` 尝试把空桶从 null 换成新节点；失败说明有竞争，`synchronized(f)` 锁住桶首节点后在链表/树上插入。读操作 get 无锁：table 用 volatile 语义（tabAt 通过 Unsafe/VarHandle acquire 读），Node.val 与 next 是 volatile。

扩容协作：sizeCtl 为负数表示正在扩容，其编码含"参与线程数+迁移游标"；线程帮助迁移时认领 stride 区间，迁移完的桶放 ForwardingNode，读操作遇到它就转发到新表，put 则协助迁移后再插入。

JDK 7 对比：分段锁 Segment（继承 ReentrantLock，默认 16 段），并发度=段数，内存布局更重，JDK 8 改为桶级锁后并发度理论上等于桶数。


### Java-001-005 | ★★★☆☆

ConcurrentHashMap 的 size 怎么统计？为什么不用 AtomicLong？

**答案：**
JDK 8 的 ConcurrentHashMap 用 baseCount 加 CounterCell 数组做分段计数：无竞争时 CAS 更新 baseCount；CAS 失败说明竞争激烈，就落到某个随机 cell 上各自累加，size() 时把 base 和所有 cell 求和。这本质就是 LongAdder 的思路——在高并发写场景把一个热点变量拆成多个热点，用空间换吞吐；代价是 sum 返回的是"某一瞬间的近似值"，不是全局精确的线性一致结果。

**解析：**
对比 AtomicLong：单个 volatile long + CAS，竞争激烈时大量线程反复失败重试，总线与缓存行争用严重（伪共享问题也要提：CounterCell 用 @Contended 注解独占缓存行）。LongAdder/CHM 计数的写性能在高并发下高一个量级，读（sum）反而更贵且非精确。

什么场景需要精确原子计数：限流器、配额扣减这类"读-改-写必须严格"的逻辑不能靠 LongAdder，要用 AtomicLong、数据库乐观锁或 Redis 原子命令。


### Java-001-006 | ★★★★☆

ArrayList 和 LinkedList 的区别是什么？各自什么时候用？

**答案：**
ArrayList 底层是动态数组，支持 O(1) 随机访问，尾部均摊 O(1) 追加，中间插入/删除要移动后续元素是 O(n)，扩容为原来的 1.5 倍并数组拷贝。LinkedList 是双向链表，头尾插入删除 O(1)，但随机访问是 O(n)，且每个节点额外两个引用，内存局部性和缓存友好度都差。绝大多数业务场景选 ArrayList：即便"中间插入"在实践中常被高估，而 LinkedList 的随机访问劣势实打实。需要 Deque 语义时用 ArrayDeque 而不是 LinkedList。

**解析：**
ArrayList 扩容：`newCap = oldCap + (oldCap >> 1)`，约 1.5 倍，`Arrays.copyOf` 底层 System.arraycopy 是内存块拷贝，非常快。remove(int) 后元素整体左移。modCount 支持 fail-fast。

LinkedList 每个元素是一个 Node（item、next、prev），查找第 i 个元素会从较近的一端开始遍历；实现了 Deque 接口，但作为队列/栈使用时 ArrayDeque 数组实现局部性更好、无节点分配。

一个反直觉的工程事实：对几千个元素的列表做一次中间插入，arraycopy 的开销通常低于链表的指针跳转；所谓"LinkedList 插入快"只在已持有多迭代器/游标的场景才成立。


### Java-001-007 | ★★★☆☆

CopyOnWriteArrayList 的原理和适用场景是什么？

**答案：**
写时复制：容器内部数组用 volatile 保存，写操作（add/set/remove）在锁内复制一份新数组、修改副本、再整体替换引用；读操作无锁，永远读当前引用指向的快照。因此读完全不加锁、读写不冲突，代价是每次写都全量复制，内存翻倍，且读到的可能是稍旧的数据（弱一致）。适用场景非常明确：读极多、写极少、列表不大、能容忍毫秒级不一致，典型如监听器列表、配置/路由表快照。

**解析：**
实现细节：`final transient ReentrantLock lock`（JDK 8）/synchronized（JDK 11+ 改用 synchronized）保护写；`private transient volatile Object[] array` 保证替换后读线程立即可见。迭代器持有所创建时刻的数组快照，不支持 remove/set/add（抛 UnsupportedOperationException），因此不存在 ConcurrentModificationException。

与 volatile 数组整体替换配合的是"不可变快照发布"思想：写方构造新状态，一次赋值切换，读方无锁——这个模式在配置热更新、路由表等场景可推广到自定义结构。


### Java-001-008 | ★★★☆☆

常见的 fail-fast 和 fail-safe 有什么区别？

**答案：**
fail-fast 是集合迭代器的即时检测机制：ArrayList/HashMap 等通过 modCount 记录结构性修改次数，迭代器创建时记下快照，每次 next()/nextNode() 前发现计数不一致就抛 ConcurrentModificationException，尽早暴露"边遍历边改"的 bug。它是尽力而为的，不保证一定触发，不能依赖它保证正确性。fail-safe 指在不原数据上遍历的容器：CopyOnWriteArrayList 迭代快照、ConcurrentHashMap 弱一致迭代器，不抛异常但看到的是某一时刻或部分更新的视图。

**解析：**
正确删除元素的方式（单线程）：`iterator.remove()`（迭代器自己的删除，同步更新 expectedModCount）；JDK 8+ 集合自带的 `removeIf(predicate)` 内部做了标记-清除，性能也好。多线程：直接换并发容器。

fail-fast 的"尽力而为"要强调：`it.next()` 之后的修改在下一次 next 才被发现；某些路径（如只修改不迭代）根本检测不到。它是调试辅助不是并发安全机制。


### Java-001-009 | ★★★★☆

LinkedHashMap 怎么实现 LRU 缓存？

**答案：**
LinkedHashMap 在 HashMap 基础上用双向链表把所有节点串起来：put 时如果 accessOrder 为 true，afterNodeAccess 会把被访问节点移到链表尾；构造时重写 removeEldestEntry，当 size 超过容量返回 true，put 后自动删除链表头的最久未使用节点。三步就能得到一个 O(1) 的 LRU：`new LinkedHashMap(capacity, 0.75f, true)` + 重写 removeEldestEntry。需要注意线程不安全，并发场景要加锁或换 Caffeine。面试手写版则用 HashMap + 双向链表（伪头伪尾哨兵）实现同样的语义。

**解析：**
accessOrder 与 insertionOrder 的区别：false（默认）链表按插入序，true 按访问序——get/put 都算访问。removeEldestEntry 在每次 put 插入后回调，返回 true 就删头。

手写版要点：head/tail 两个哨兵节点消除边界判断；`remove(node)` 与 `addToTail(node)` 两个原子操作组合出 moveToTail；get 命中也 move 到尾。查找靠 HashMap O(1)，移动靠链表 O(1)。

工程升级：手写 LRU 没有 TTL、过期惰性删除、容量按字节权重、命中率统计等；生产缓存应使用 Caffeine（W-TinyLFU 淘汰策略，命中率优于纯 LRU）。


### Java-001-010 | ★★★☆☆

TreeMap 和 TreeSet 的底层原理？和 HashMap 的区别？

**答案：**
TreeMap 底层是红黑树，按 key 的自然顺序或传入的 Comparator 排序，增删查都是 O(log n)，并且支持范围查询（headMap/tailMap/subMap）、firstKey/lastKey/floorKey/ceilingKey 这些有序操作。HashMap 无序、单操作均摊 O(1)。选择标准：需要按 key 排序遍历或范围检索用 TreeMap；只要快速存取用 HashMap。TreeSet 就是 TreeMap 的 key 集合视图（value 是共享的静态占位对象）。

**解析：**
红黑树五条性质（多叉简化记忆：根黑叶黑、红不相连、等黑高）保证最长路径不超过最短路径两倍，从而增删查 O(log n)。相比 AVL，红黑树旋转次数更少，是综合增删查频率后的工程折中——JDK 里 HashMap 树化桶、TreeMap、CFS 调度器（历史）都用它。

实现细节：TreeMap 的 get 不是简单二叉查找——`getEntry` 先用 comparator 定位，失败时如果 comparator 为 null 再走 equals 兜底（并发修改/不一致 comparator 场景的补救）。元素必须可比较，否则 ClassCastException。


### Java-001-011 | ★★★☆☆

HashSet 的实现原理？LinkedHashSet 和 TreeSet 呢？

**答案：**
HashSet 就是包装了一个 HashMap：元素作为 key，value 是共享的静态 PRESENT 占位对象，去重依赖元素的 hashCode 和 equals。LinkedHashSet 继承它并利用 LinkedHashMap 的双向链表保持插入（或访问）顺序。TreeSet 基于 TreeMap 红黑树，元素有序，要求可比较或提供 Comparator。选型：纯去重用 HashSet（最快）；要保持插入顺序用 LinkedHashSet；要排序/范围查询用 TreeSet。

**解析：**
理解"Set 是 Map 的特例"这个设计：JDK 没有重写一套去重结构，复用 Map 的桶+链/树机制。因此 Set 的一切特性继承自 HashMap：初始容量 16/负载因子 0.75/树化阈值，同样线程不安全，同样 fail-fast。

LinkedHashSet 的顺序由 LinkedHashMap 的链表保证；构造时 accessOrder 固定 false（插入序）。

并发替代：CopyOnWriteArraySet（小集合）、ConcurrentHashMap.newKeySet()（通用）。


### Java-001-012 | ★★★☆☆

PriorityQueue（堆）的原理和典型应用？

**答案：**
PriorityQueue 底层是数组存储的二叉小顶堆：poll/peek 拿最小元素（自然序或 Comparator），offer 上浮、poll 下沉，都是 O(log n)。典型应用：TopK（维护 K 大小的小顶堆，遍历比堆顶大就替换）、定时任务调度（Timer、ScheduledThreadPoolExecutor 的 DelayedWorkQueue 就是按触发时间排序的堆）、Dijkstra、合并 K 个有序链表。注意它不是线程安全的，迭代顺序也不保证有序；并发场景用 PriorityBlockingQueue，延迟队列用 DelayQueue。

**解析：**
堆的数组表示：父 i、孩子 2i+1/2i+2。offer：追加到尾部后 siftUp；poll：取头部，把尾元素放头部 siftDown。构建堆（heapify）从最后一个非叶节点倒序下沉，O(n)，优于逐个插入的 O(n log n)。

TopK 细节：求最大 K 个用小顶堆（堆顶是当前第 K 大，来了更大的替换），求最小 K 个用大顶堆，复杂度 O(n log k) 优于全排序。

DelayedWorkQueue：元素实现 Delayed 接口，按剩余延迟排序，take 时若队首未到期则 await 等待——定时任务线程池的核心结构。


### Java-001-013 | ★★☆☆☆

Iterator 和 ListIterator 的区别？Enumeration 呢？

**答案：**
Iterator 是通用迭代器，支持 hasNext/next/remove，所有 Collection 都能用。ListIterator 是 List 专属增强版：支持双向遍历（hasPrevious/previous）、add/set 修改、以及 nextIndex/previousIndex，可以从指定位置开始迭代。Enumeration 是更老的只读接口（Vector/Hashtable 时代），没有 remove，现在主要用于兼容遗留代码，语义上应统一用 Iterator。

**解析：**
ListIterator 的 add/set 语义细节：set 替换 last 返回的元素（必须先调过 next 或 previous）；add 在游标前插入，游标前移一位。remove 同样基于 last 返回元素，连续两次调用会抛 IllegalStateException。

迭代器与并发：普通 Iterator fail-fast；并发容器返回弱一致迭代器；COW 迭代快照。选择时根据容器并发语义决定能否在遍历中修改。


### Java-001-014 | ★★★☆☆

Arrays.asList、Collections.emptyList、List.of 有什么区别？

**答案：**
Arrays.asList 返回定长视图：底层就是传入数组，不支持 add/remove（抛 UnsupportedOperationException），但 set 可以改元素且会影响原数组。Collections.emptyList 是共享的不可变空列表（不分配）。List.of（JDK 9+）是真不可变列表：任何修改操作都抛异常，不接受 null 元素，元素是值拷贝，与源数组无关联。选择：只读常量用 List.of；可变列表正常 new ArrayList。把不可变集合当可变集合用是最常见的线上异常来源之一。


### Java-001-015 | ★★★★☆

fail-fast 的 modCount 机制与 ConcurrentHashMap 的弱一致迭代

**答案：**
ArrayList/HashMap 迭代器创建时快照 modCount，每次 next 校验，结构被外部修改即抛 ConcurrentModificationException——"尽力而为"的检测而非保证。正确删除用 iterator.remove 或 removeIf。ConcurrentHashMap 迭代器是弱一致的：不抛异常、反映创建时及之后部分更新，适合并发遍历快照语义。CopyOnWriteArrayList 迭代完全冻结于创建时刻的数组。

**解析：**
为什么 modCount 声明为 transient 也不影响（序列化场景不迭代）；"倒数第二个元素删除不报错"的边界（hasNext 检查 cursor != size，删除后恰好相等提前退出）；并发容器的选择树：Map→CHM、List→COW、Queue→ConcurrentLinkedQueue/BlockingQueue。


### Java-001-016 | ★★★★☆

为什么 ArrayList 初始容量建议预估传入？扩容成本分析

**答案：**
无参构造首次 add 分配 10，之后 1.5 倍扩容，每次扩容是 Arrays.copyOf 的全量数组搬迁（O(n)）。n 次添加的总搬迁成本均摊 O(n)，但大列表的"单次扩容尖峰"（内存翻倍+全量复制）在低延迟接口里有感。已知规模时 `new ArrayList<>(expectedSize)` 或 ensureCapacity 消除尖峰；配合 toCollection 精确分流。

**解析：**
1.5 倍 vs HashMap 2 倍的策略差异（list 只需顺序追加，增长因子是"空间浪费 vs 搬迁频率"折中；hashmap 2 的幂是位运算定位的硬约束）。stream.collect(toList()) 在 JDK 10+ 有 size 预估优化。面试可延伸：为什么 Arrays.asList 不可 add（固定尺寸视图）。


### Java-001-017 | ★★★★☆

BIO、NIO、AIO 的区别？

**答案：**
BIO（同步阻塞）：一个连接一个线程处理，线程在 read/write 时阻塞等待，连接数大时线程爆炸。NIO（同步非阻塞，JDK 1.4）：基于 Channel + Buffer + Selector（IO 多路复用，内核 epoll），一个线程管理大量连接，事件就绪才处理——Netty 的底座；面向**缓冲区**与**块**。AIO（异步，JDK 1.7）：内核完成数据拷贝后回调通知（Proactor 模式），Linux 成熟异步实现出现较晚，实际生产 NIO/epoll 仍是主流（K-OS-010 的五种 IO 模型是理论底座）。选型：连接少逻辑简单 BIO 即可；海量连接 NIO；真正的异步通知场景少有落地。

**解析：**
NIO 三件套语义：Channel 双向（读也可写也可，区别于流的单向）；Buffer 写 flip 读（position/limit/capacity 三指针）；Selector 注册 OP_ACCEPT/OP_READ 等事件，select() 阻塞至有就绪集合。零拷贝 FileChannel.transferTo 对应 sendfile（K-OS-009）；MappedByteBuffer 对应 mmap。


### Java-001-018 | ★★★★☆

序列化是什么？选择序列化方案考虑什么？

**答案：**
序列化把对象转为可传输/存储的字节流，反序列化还原。选型五维：性能（编解码速度/体积）、跨语言、兼容性（字段增删的前后兼容）、安全性（反序列化漏洞）、易用性。Java 原生序列化：只支持 Java、体积大、**反序列化漏洞重灾区**（readObject 执行逻辑，经典攻击链），生产禁用于不可信数据。主流：JSON（可读、跨语言、体积中等，Jackson/Fastjson）、Protobuf（紧凑高效、Schema 驱动、强兼容规范，RPC 标配）、Hessian（RPC 友好）。对象含流/线程/连接等资源时不可序列化，transient 关键字跳过字段。


### Java-001-019 | ★★★★☆

字符流和字节流？编码问题怎么避坑？

**答案：**
字节流（InputStream/OutputStream）处理原始 8 位字节：图片、视频、任意二进制；字符流（Reader/Writer）在字节流之上按**字符编码**解码处理文本。避坑三条：①文本必须显式指定字符集（`new InputStreamReader(in, StandardCharsets.UTF_8)`），不指定则用平台默认编码（历史坑：Windows GBK 与 Linux UTF-8 不一致的乱码问题）；JDK 18 起 默认 UTF-8（file.encoding）；②字节→字符的长度语义变化（UTF-8 中文 3 字节，1 字符 ≠ 1 字节），网络协议按字节设计长度；③拷贝二进制必须字节流，字符流会丢数据。


### Java-001-020 | ★★★★★

== 和 equals 的区别是什么？为什么重写 equals 必须重写 hashCode？

**答案：**
`==` 比较的是值本身：基本类型比数值，引用类型比内存地址（是否同一个对象）。`equals` 是方法，默认实现等同 `==`，但可以被重写来表达"业务上的相等"，比如 String 按字符内容比较。重写 equals 后必须同时重写 hashCode，因为规范要求两个 equals 相等的对象必须有相同 hashCode，否则放进 HashMap/HashSet 会出现"逻辑相等但查不到"的问题。

**解析：**
`==` 对基本类型（int、long 等）直接比较栈上的数值；对引用类型比较的是引用值，即两个变量是否指向堆中同一个对象。

`equals` 来自 Object，其默认实现就是 `return this == obj`。业务类通常会重写它，例如按字段逐个比较。重写时有几条契约（Java 规范约定）：自反性、对称性、传递性、一致性，以及对 null 返回 false。

hashCode 契约是问题的关键：**equals 相等 ⇒ hashCode 必须相等；hashCode 相等不要求 equals 相等**。HashSet/HashMap 先用 hashCode 定位桶，再用 equals 在桶内确认。若只重写 equals 不重写 hashCode，两个"内容相同"的对象会落进不同的桶——`set.contains(new EqualObj(...))` 返回 false，Map 里出现两个语义重复的 key。


### Java-001-021 | ★★★★★

String 为什么设计成不可变？String、StringBuilder、StringBuffer 怎么选？

**答案：**
String 用 final 修饰类、内部字符数组也不可访问修改，一旦创建内容不可变。不可变带来四个好处：可以安全地缓存 hashCode（HashMap key 的前提）；字符串常量池可以共享同一对象；天然线程安全；作为参数传递时不用担心被方法内部修改。因此频繁拼接字符串不能用 `+`（每次产生新对象），循环拼接要用 StringBuilder；StringBuffer 功能相同但方法加了 synchronized，多线程下才需要它。

**解析：**
String 旧版本（JDK 8）内部是 `final char[] value`，JDK 9 之后改为 `byte[]` 加编码标记（紧凑字符串，Latin-1 字符省一半内存）。类与字段都是 final，且不暴露修改数组的途径，保证不可变。

不可变的价值链条：①hashCode 只需计算一次并缓存——String 是最常用的 HashMap key；②常量池（JDK 7 起在堆中）让相同字面量共享一个对象，`"a" + "b"` 编译期直接折叠为 `"ab"`；③不可变对象发布即安全，多线程共享无需同步；④安全性：网络地址、文件路径、数据库连接串等不会被中途篡改。

字符串拼接：编译器会把单行 `+` 优化成 StringBuilder（JDK 9 后是 StringConcatFactory 的 invokedynamic 实现），但**循环内**的 `+` 每轮都会 new StringBuilder，产生大量中间对象，应手动提到循环外或用 StringBuilder.append。


### Java-001-022 | ★★★★★

面向对象三大特性是什么？多态的实现原理？

**答案：**
封装是把状态和行为收进对象、用访问控制暴露必要接口，隐藏实现细节；继承实现类型复用与"is-a"关系，Java 单继承；多态指同一调用在不同对象上表现不同行为，编译期看左边的声明类型，运行期执行右边实际类型的方法，也就是动态绑定。多态的底层依赖方法表（vtable）：每个类的方法入口存在方法表里，invokevirtual 按运行时实际类型查表分派。

**解析：**
封装解决"改内部不影响外部"，是可维护性的基石；继承要注意它表达强耦合的 is-a，组合优于继承是更常用的工程取向；多态让程序面向抽象编程，新增实现不改调用方代码（开闭原则的基础）。

Java 多态主要有两种形态：重写（运行期多态，依赖动态绑定）和重载（编译期多态，按静态类型和方法签名在编译期确定）。运行期动态绑定过程中，涉及私有方法、static 方法、final 方法和构造器时使用静态绑定（invokestatic/invokespecial），它们不参与多态。


### Java-001-023 | ★★★★☆

接口和抽象类有什么区别？什么时候用哪个？

**答案：**
接口描述"能做什么"，是一组行为契约，Java 8 后可以有 default 和 static 方法，一个类可以实现多个接口；抽象类描述"是什么"，是半成品模板，可以有状态（成员变量）和构造器，只能单继承。选择上：需要复用模板代码、维护共同状态时用抽象类；只定义能力契约、希望多继承效果时用接口。JDK 8 之后二者在"带默认实现"上的界限变模糊，但语义定位仍然不同。

**解析：**
语法差异：接口的成员变量隐式 public static final；方法默认 public abstract（default/static/private 除外，JDK 9 起允许 private 方法复用 default 代码）；没有构造器，不能实例化。抽象类可以有任意成员、构造器（供子类初始化流程调用）、任意访问级别方法。

语义差异更重要：接口是能力横切（Comparable、AutoCloseable），抽象类是类型纵向骨架（AbstractList、InputStream）。模板方法模式几乎总是落在抽象类上：父类固化流程，子类填差异。

default 方法的出现是为了接口演进（Collection.stream() 不破坏旧实现），同时引入"类优先"规则：类中继承的实现优先于接口 default；多个接口的 default 冲突时必须显式覆盖。


### Java-001-024 | ★★★★☆

Java 的异常体系是怎样的？受检异常和非受检异常怎么区分？

**答案：**
Throwable 下分 Error 和 Exception。Error 是 JVM 级严重错误（OutOfMemoryError、StackOverflowError），程序不应捕获；Exception 里 RuntimeException 及其子类是非受检异常（NPE、数组越界、类型转换），代表编程缺陷，编译器不强制处理；其余如 IOException、SQLException 是受检异常，编译器强制捕获或声明。工程实践：可恢复的业务/外部依赖异常用受检或业务异常表达，编程错误让 RuntimeException 暴露，不要用异常控制正常流程，资源关闭用 try-with-resources。

**解析：**
异常处理的两难在于"强制处理"的取舍：受检异常逼调用方面对失败路径（适合外部交互可能失败且可恢复的场景），代价是签名污染与 lambda 兼容性差；非受检异常让代码干净，但容易漏处理。现代框架（Spring Data 等）普遍把底层受检异常翻译成运行时异常体系（DataAccessException），让上层统一在合适层次处理。

工程规范要点：①不要捕获 Throwable/Error；②不要 `catch (Exception e) {}` 吞异常，至少记日志或向上抛；③自定义业务异常继承 RuntimeException，带错误码；④finally 里不要 return（会吞掉异常）；⑤try-with-resources 自动关闭实现 AutoCloseable 的资源，编译器生成反序 close 并抑制次级异常（getSuppressed）。


### Java-001-025 | ★★★☆☆

final、finally、finalize 分别是什么？final 的语义细节？

**答案：**
三个东西只是拼写相近。final 是修饰符：类不可继承、方法不可重写、变量不可重新赋值——引用不可变不等于对象内容不可变；finally 是异常处理的收尾块，保证清理逻辑执行；finalize 是 Object 的回收前回调方法，JDK 9 起已废弃，因为执行时机不确定、可能复活对象、性能差，资源释放应该用 try-with-resources 或 Cleaner/PhantomReference。

**解析：**
final 三个层次：final 类（String、Integer，禁止继承）；final 方法（禁止重写，早期 JIT 可内联优化，现代主要表达设计意图）；final 变量——基本类型值不可变，引用类型引用不可变但对象内容可变。final 字段还有内存语义：构造器内对 final 字段的写入在对象引用发布后对其他线程可见（JSR-133 的 final 字段安全性），这也是不可变对象线程安全的依据之一。另外 final 局部变量/参数是 lambda 捕获的前提（effectively final）。

finally 保证清理逻辑在 try/catch 之后执行（System.exit、JVM 终止等除外）。finalize 曾被用于资源兜底回收，问题是：GC 时机不定导致资源延迟释放、finalize 队列拖慢回收、对象可在 finalize 中复活。JDK 9 起 Deprecated，替代方案是 try-with-resources（首选）和 java.lang.ref.Cleaner。


### Java-001-026 | ★★★☆☆

深拷贝和浅拷贝的区别？如何实现深拷贝？

**答案：**
浅拷贝只复制对象第一层字段：基本类型复制值，引用类型复制引用，副本与原对象共享内部对象。深拷贝递归复制所有引用对象，得到完全独立的副本。实现方式：手动逐层复制、重写 clone 并对每个可变引用字段也克隆（Object.clone 本身是浅拷贝）、序列化/反序列化（JSON 或 Java 序列化）走一轮字节流、或用拷贝构造器/工厂。工程上更推荐拷贝构造器或 MapStruct 这类映射工具，clone 协议（Cloneable + clone 重写）设计公认糟糕。

**解析：**
Object.clone 是 native 浅复制：按字段逐个复制，引用字段复制的是指针。使用它需要实现 Cloneable 标记接口，否则抛 CloneNotSupportedException——这个"标记接口+Object 方法"的设计是历史包袱。

深拷贝的四种实现：①逐字段手动构造新对象（清晰、可控、字段多时繁琐）；②clone 链式深克隆（每个可变成员类都要正确实现，维护脆弱）；③序列化法（Java 序列化或 JSON：对象 → 字节/字符串 → 新对象，要求全部可序列化，性能一般，注意循环引用）；④拷贝构造器 `new Person(other)` 或 MapStruct/BeanUtils 映射（工程主流；注意 Spring 的 BeanUtils 是浅拷贝且易错）。


### Java-001-027 | ★★★★☆

什么是反射？它有什么优缺点和典型应用？

**答案：**
反射是在运行期动态获取类信息（字段、方法、构造器、注解）并调用它们的能力，入口是 Class 对象，获取方式有三种：类名.class、对象.getClass()、Class.forName(全限定名)。它是各类框架的基石——Spring IoC 按类名实例化 Bean、MyBatis 把结果集映射进实体、Jackson 序列化都靠反射。代价是：比直接调用慢（有方法查找、装箱、内联受阻）、绕过编译期检查、可能破坏封装（setAccessible）。JDK 9 模块化后跨模块深反射需要显式 open，新方向是 MethodHandles 与类生成库。

**解析：**
类加载后 JVM 在堆中生成该类的 Class 对象，反射 API（java.lang.reflect / java.lang.invoke）以它为根读取运行时结构。典型链路：`Class.forName("com.x.Foo")` → `getDeclaredConstructor().newInstance()` → `getMethod("bar").invoke(obj, args)`。

性能问题要讲准：现代 JVM 对反射做了膨胀优化（JIT 可将反射调用内联到接近直接调用），慢主要发生在方法查找、参数装箱、访问检查上；缓存 Method/Field 对象、`setAccessible(true)` 减少检查可显著改善。真正的新约束是模块化：未 open 的包不允许 setAccessible（非法反射访问在 JDK 17 默认拒绝）。

替代/演进：MethodHandle（更接近字节码层、可被 JIT 更好优化）、VarHandle、以及运行时代码生成（JDK Proxy、CGLIB、ByteBuddy）——很多框架在热路径上从反射切换到生成类。


### Java-001-028 | ★★★☆☆

注解是怎么工作的？元注解和保留策略了解一下？

**答案：**
注解本身只是一个"带元数据的标记接口"，不承载逻辑；它发挥作用靠三股力量：源码期由 APT 注解处理器生成代码（如 Lombok、MapStruct）、编译期由编译器检查（@Override）、运行期由框架反射读取（Spring 的 @Component、@Transactional）。定义注解用 @interface，可用的元注解中关键是 @Target（能用在哪）和 @Retention（保留到哪一层：SOURCE 只留源码、CLASS 留到字节码、RUNTIME 可被反射读到——运行期生效必须 RUNTIME）。

**解析：**
运行期流程示例（Spring 组件扫描）：类加载 → 扫描器反射读取类上的 @Component 及元注解 → 注册 BeanDefinition → 实例化。所以"注解驱动"本质是"注解承载配置元数据 + 容器反射消费"。AOP 注解如 @Transactional 也一样：事务拦截器在方法调用时反射检查注解属性决定传播行为。

APT（Annotation Processing Tool 机制，现为 javax.annotation.processing）在编译期处理注解：处理器可以校验、生成新源码/资源，但不能修改已有类——所以 Lombok 实际是用了编译器内部 API 做语法树改写，属于特例，这也是它升级 JDK 常出兼容问题的原因。

注解继承：@Inherited 只对类生效，接口方法上的注解不会被实现类"继承"，这就是 Spring 提供 @AnnotatedElementUtils/合成注解工具的原因。


### Java-001-029 | ★★★☆☆

泛型的类型擦除是怎么回事？通配符 ? extends 和 ? super 怎么用？

**答案：**
Java 泛型是编译期检查、运行期擦除的实现：编译后字节码里 `List<String>` 和 `List<Integer>` 都是 `List`，类型参数被替换为边界（无边界就是 Object），并在调用点插入强制转换，必要时生成桥接方法。所以运行期拿不到 `T.class`，不能 `new T()`。通配符遵循 PECS：生产者用 `? extends T`（只读取，作为数据来源），消费者用 `? super T`（只写入），既保证类型安全又提升 API 灵活性。

**解析：**
擦除的动机是兼容：泛型（JDK 5）要在旧字节码与旧类库上运行，因此选择编译期语法糖路线。后果清单：运行期无泛型信息（除非保留在签名/父类/字段声明上，可通过 getGenericSuperclass 拿到声明期类型——框架据此做超类型令牌）；不能实例化类型参数、不能泛型数组、原始类型与泛型混用产生 unchecked 警告。

桥接方法：子类覆盖泛型方法时，编译器生成一个以擦除后签名为签名的方法转发到具体类型版本，保证多态分派在字节码层成立。

PECS 示例：`copy(List<? extends T> src, List<? super T> dst)`——src 只读出 T，dst 只写入 T。如果集合又读又写，就不能用通配符，直接用 T。


### Java-001-030 | ★★★★☆

JDK 动态代理和 CGLIB 有什么区别？Spring AOP 用哪个？

**答案：**
JDK 动态代理基于接口：运行期生成一个实现目标接口的代理类（$Proxy0），方法调用转发给 InvocationHandler，所以目标必须有接口。CGLIB 基于继承：生成目标类的子类，重写非 final 方法插入拦截逻辑，不要求接口但不能代理 final 类/方法，构造与调用开销略高。Spring AOP 的选择规则：目标实现了接口时默认 JDK 代理，没有接口时用 CGLIB；Spring Boot 2 起默认改为统一使用 CGLIB（proxyTargetClass=true），避免同一 Bean 因接口存在与否导致代理类型不一致的注入问题。

**解析：**
JDK 代理的核心结构：`Proxy.newProxyInstance(loader, interfaces, handler)`，生成的代理类继承 Proxy、实现指定接口，每个方法体是 `super.h.invoke(this, method, args)`，所有拦截逻辑集中在 handler（Spring 中是 JdkDynamicAopProxy，链式调用通知后反射调用目标）。CGLIB 通过 ASM 字节码库生成子类，方法体直接织入拦截器回调（MethodInterceptor），并用 FastClass 机制按索引调用避免反射。

选择考量：有无接口只是"能不能"问题；工程上更该关心语义差异——CGLIB 代理的是子类，目标类的 final 方法无法增强；JDK 代理对外只暴露接口方法，类上非接口方法不会被拦截。另一个高频坑（对两种代理都成立）：**自调用不走代理**，`this.method()` 是原始对象调用，事务/缓存注解失效。


### Java-001-031 | ★★★★☆

Java 8 的 Lambda 和 Stream 用过吗？Stream 有哪些常见坑？

**答案：**
Lambda 是函数式接口（单抽象方法）的实例化语法，配合方法引用让"行为"可以像数据一样传递；Stream 是对集合的声明式流水线，分中间操作（filter/map/sorted，惰性）和终端操作（collect/forEach/reduce，触发执行），一次消费不可复用。常用坑：流被复用或终端漏写导致"看起来执行了其实没执行"；在流里用并行流但操作非线程安全或数据量小反而更慢；collect 里修改外部状态破坏无状态要求；以及 boxed 装箱带来的性能损耗。

**解析：**
函数式接口核心几个：Function<T,R>、Consumer<T>、Supplier<T>、Predicate<T>，以及基本类型特化版（ToIntFunction 等）避免装箱。方法引用四种：静态引用、实例方法引用、特定对象引用、构造器引用。

Stream 执行模型：中间操作只是记录管道，终端操作触发一次性遍历（short-circuit 操作如 findFirst 可提前终止）。collect 的正确姿势是 Collectors 工具（groupingBy/partitioningBy/joining/toMap）， groupingBy 可叠加下游收集器实现多层聚合。toMap 遇到重复 key 会抛 IllegalStateException，要提供 merge 函数。

并行流基于公共 ForkJoinPool，适合无状态、无副作用、数据量大、CPU 密集的独立元素计算；Web 环境混用会争抢公共池，慎用。


### Java-001-032 | ★★★★☆

int 和 Integer 的区别？自动装箱拆箱有什么坑？

**答案：**
int 是基本类型，直接存值在栈上（或作为对象字段的一部分），默认 0；Integer 是包装对象，堆上分配，可为 null，带有 parseInt、比较等工具方法。自动装箱调用 Integer.valueOf，拆箱调用 intValue。最大的坑是 Integer 缓存：valueOf 对 -128~127 返回缓存的同一对象，所以这个区间内 `==` 为 true，区间外为 false；包装类型比较必须用 equals。其他坑：null 拆箱 NPE（常见于数据库可空字段映射到包装类型后参与运算）、循环装箱产生大量对象、三目运算符混合类型的隐式拆箱。

**解析：**
缓存机制是 Integer 的静态内部类 IntegerCache，默认缓存 -128~127，上限可用 `-XX:AutoBoxCacheMax` 调整（仅上限）。Long 同样有缓存。这个设计的初衷是频繁的小整数（循环下标等）减少分配。

拆箱 NPE 的隐蔽场景：`Integer total = null; int x = total + 1;`；三目运算 `flag ? intVal : integerVal` 会把两个分支统一类型引发拆箱，若 integerVal 为 null 则 NPE——JDK 7 后不少工具（如 Map.getOrDefault 配合）依赖注意这一点。

性能：装箱对象头 16 字节左右，加引用间接性；集合里 `List<Long>` 的 Long 占用远高于 long[]，高频数值计算用特化流（IntStream）或数组。


### Java-001-033 | ★★★☆☆

SPI 机制是什么？和 Spring 的依赖注入有什么关系？

**答案：**
SPI（Service Provider Interface）是 JDK 内置的服务发现机制：接口方定义接口，实现方在自己的 jar 里放 `META-INF/services/接口全限定名` 文件，内容为实现类全限定名，使用方通过 `ServiceLoader.load(接口)` 在运行期加载全部实现。它实现了"面向接口、调用方不依赖实现"的反转，典型应用是 JDBC 驱动加载、SLF4J 绑定、Spring Boot 自动配置的扩展土壤。缺点是每次全量实例化、不能按条件选择、失败诊断差，所以 Dubbo 做了增强 SPI（按 key 懒加载、自适应扩展），Spring 则有自己的 BeanFactory 体系，Spring Boot 的 spring.factories/自动导入注册器是同思想的工程化版本。

**解析：**
工作原理：ServiceLoader 惰性解析 services 目录文件（类路径下所有 jar 的同名文件会合并），迭代时按行反射实例化实现类。JDK 9 模块化后提供了 module-info 的 `provides ... with ...` 声明方式，与文件方式并存。

与 Spring 的关系：SPI 是"实现查找"的原始机制，Spring DI 是"实例装配"的容器体系；Spring 内部也大量使用 SPI 思想——`SpringFactoriesLoader`（旧）读 spring.factories，Spring Boot 2.7+/3 用 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`。面试里常问 JDBC 与 SPI：DriverManager 初始化时通过 ServiceLoader 扫描 classpath 下所有驱动实现并注册，所以 JDBC 4.0 之后不需要 Class.forName。


### Java-001-034 | ★★★☆☆

Java 8 之后的版本有哪些对你影响大的新特性？

**答案：**
按实用程度说四个：JDK 8 的 Stream/Lambda 与 Optional 早已是日常；JDK 11（LTS）的 var 局部类型推断、HttpClient 标准化、单文件运行；JDK 17（LTS）的 sealed 密封类、record 记录类、switch 表达式与模式匹配入门、以及模块化强封装对老框架的影响；JDK 21（LTS）的虚拟线程改变 IO 密集服务的并发写法。回答时结合自己项目版本讲实际收益，比堆名词可信。

**解析：**
- record（16+）：一行定义不可变数据载体，自动生成构造/访问器/equals/hashCode/toString，适合 DTO、值对象；字段不可变、可加紧凑构造器做校验。
- sealed（17）：`sealed interface X permits A,B` 精确控制实现集，配合 switch 模式匹配实现穷尽检查，替代"接口+私购构造"的代数类型模拟。
- switch 表达式（14 正式）：箭头语法、返回值、yield，配合模式匹配（21 正式）可按类型解构。
- 虚拟线程（21 正式）：JVM 调度的轻量线程，阻塞成本极低，让"同步阻塞写法"获得高吞吐，适合 IO 密集（数据库调用、HTTP 客户端），与现有 ThreadLocal 生态兼容性好；CPU 密集无收益。
- 其他值得点名的：文本块（15）、Optional 增强、ZGC/Shenandoah 低延迟 GC 的成熟、G1 成为默认后的持续优化。

版本采用现状（表述要留余地）：国内企业主力仍在 8/11/17，新项目 17/21 渐多；回答时说明自己项目的实际版本即可。


### Java-001-035 | ★★★★☆

Java 中的泛型通配符使用与集合协变问题

**答案：**
Java 数组是协变的（Object[] 可接收 String[]，运行期可能 ArrayStoreException），集合泛型是不变的（List<String> 不是 List<Object> 子类型）——不变性把类型错误从运行期提前到编译期，是泛型的安全设计。通配符在使用处恢复灵活性：`List<? extends Fruit>` 可读不可写（生产者），`List<? super Apple>` 可写不保证元素类型（消费者），即 PECS。能答出"协变是历史包袱、泛型不变是修正"的因果即高分。

**解析：**
数组协变早于泛型（JDK 1 数组 vs JDK 5 泛型）：当时没有泛型，协变让 sort(Object[]) 之类的 API 可行，代价是存取检查推迟到运行期。泛型设计吸取教训选择不变+通配符使用处型变。追问链：为什么 Kotlin 用声明处型变（out/in）更优雅；`? extends` 的集合 add(null) 是唯一合法写入的原因（null 是所有引用类型成员）。


### Java-001-036 | ★★★★☆

Comparable 和 Comparator 的区别与选用

**答案：**
Comparable 是"自然排序"——类实现 compareTo，与类绑定（如 String、Integer 的默认顺序）；Comparator 是"外部比较器"——独立定义比较策略，不侵入原类，可多套并存（按年龄排、按入职日期排）。选型：类有唯一自然的顺序用 Comparable；多种排序维度、无法修改源码、或需要策略复用时用 Comparator。Java 8 后 Comparator 提供 comparing/thenComparing 链式与 reversed/nonnull 组合，实践中优先。

**解析：**
契约：sgn(compare(x,y)) == -sgn(compare(y,x))；与 equals 一致性建议（不一致时 TreeMap/TreeSet 的"相等"语义与 equals 冲突，出现"两个 equals 的对象都在 Set 里"）。经典坑：`(a, b) -> a - b` 整型溢出（大数相减翻转符号），应使用 Integer.compare。排序稳定性：Collections.sort/TimSort 稳定，依赖顺序的场景注意。


### Java-001-037 | ★★★★☆

Java 注解 @FunctionalInterface 与函数式接口的关系

**答案：**
函数式接口=有且仅有一个抽象方法的接口（可含 default/static/Object 类重写）；@FunctionalInterface 是编译期校验注解，加上后不满足条件会编译报错，不加只要满足条件也能当函数式接口用（如自定义接口直接写 lambda）。四大原生：Function、Consumer、Supplier、Predicate 及基本类型特化。作用：lambda/方法引用的目标类型。

**解析：**
默认方法不占"唯一抽象方法"名额：接口可以有多个 default 仍保持函数式。接口继承若引入第二个抽象方法则失效。这解释了为什么 Collection.stream 之类以 default 加入不破坏函数式语义。追问：方法引用四种形式；lambda 与匿名类的差异（this 指向、字节码 invokedynamic）。


### Java-001-038 | ★★★★☆

NIO 三大组件

Java NIO 的三大核心组件包括：

A. Channel
B. Buffer
C. Selector
D. Stream

**答案：** A、B、C

**解析：**
- A：正确。Channel 双向数据通道，可同时读写。
- B：正确。Buffer 数据容器，读写经由缓冲区（flip 切换模式）。
- C：正确。Selector 多路复用器，单线程监听多 Channel 就绪事件。
- D：错误。Stream 是 BIO 的单向流抽象。

Channel(通道) + Buffer(缓冲) + Selector(选择器)。


### Java-001-039 | ★★★☆☆

序列化 transient

Java 原生序列化时，被 `transient` 修饰的字段会：

A. 被加密后序列化
B. 跳过序列化，反序列化时为该类型默认值
C. 以明文强制序列化
D. 导致序列化抛出异常

**答案：** B

**解析：**
- A：错误。transient 是"不序列化"，不提供加密能力。
- B：正确。序列化跳过该字段，反序列化得到的对象中该字段为默认值（0/null/false）。
- C：错误。语义相反。
- D：错误。正常跳过不报错。

transient 排除敏感/可重建字段；static 字段同样不参与序列化。


### Java-001-040 | ★★☆☆☆

Buffer flip

NIO 中向 Buffer 写入数据后，准备读取数据前应调用：

A. clear()
B. flip()
C. rewind()
D. reset()

**答案：** B

**解析：**
- A：错误。clear() 清空整个缓冲区（position=0, limit=capacity），会"忘记"刚写入的数据边界。
- B：正确。flip() 将 limit 置为当前 position、position 归 0，把"写模式"切换为"读模式"。
- C：错误。rewind() 只把 position 归 0、limit 不变，用于重读已界定区间。
- D：错误。reset() 回到 mark 标记处。

Buffer 三指针 position/limit/capacity 与读写模式切换。


### Java-001-041 | ★★☆☆☆

字符流与二进制拷贝

需要原样拷贝一张 PNG 图片，正确的做法是：

A. 用 FileReader 读字符、FileWriter 写字符
B. 用 BufferedReader 按行读取后拼接写入
C. 用 InputStream/OutputStream 字节流按缓冲块读写
D. 先把图片 Base64 解码再写文件

**答案：** C

**解析：**
- A/B：错误。字符流按编码解码，二进制数据中出现非法字节序列会被替换/破坏，拷贝结果损坏。
- C：正确。二进制必须走字节流，按 4~8KB 缓冲块循环读写。
- D：错误。图片本身不是 Base64 文本，"先解码"会直接失败；Base64 用于文本协议承载二进制。

字节流处理一切二进制；字符流只用于文本且必须指定编码。


### Java-001-042 | ★★★☆☆

BIO 模型线程数

传统 BIO 服务端采用"一个客户端连接分配一个线程"的模型，其最主要的问题是：

A. 代码无法读懂
B. 并发连接数大时线程数量爆炸，内存与上下文切换开销不可承受
C. 无法传输二进制数据
D. 不支持 TCP 协议

**答案：** B

**解析：**
- A：错误。BIO 代码反而最直观。
- B：正确。每线程默认栈约 1MB 且调度开销随数量增长，数千连接即压力巨大；这正是 NIO 多路复用解决的问题。
- C：错误。BIO 可以传输任意字节流。
- D：错误。与协议无关。

BIO 线程模型的天花板 → NIO 事件驱动的动机（C10K 问题）。


### Java-001-043 | ★★☆☆☆

字符编码

UTF-8 编码下，一个常用汉字（基本平面）通常占几个字节？

A. 1 个
B. 2 个
C. 3 个
D. 4 个

**答案：** C

**解析：**
- A：错误。1 字节只有 ASCII。
- B：错误。2 字节多为西欧扩展字符。
- C：正确。常用汉字码位在 U+0800~U+FFFF，UTF-8 编码为 3 字节；生僻扩展区汉字（emoji 同级）为 4 字节。
- D：错误。4 字节用于增补平面（生僻字、emoji）。

UTF-8 变长：ASCII 1B、常用中文 3B、emoji/生僻字 4B；MySQL 的 utf8 是残缺 3 字节实现（必须 utf8mb4）。


### Java-001-044 | ★★★☆☆

String 拼接编译期优化

```java
String s = "a" + "b" + "c";
String t = "abc";
System.out.println(s == t);
```
输出是：

A. false
B. true
C. 编译错误
D. 运行时异常

**答案：** B

**解析：**
- A：错误。编译期常量折叠会把 `"a"+"b"+"c"` 直接折叠为 "abc"，指向常量池同一对象。
- B：正确。全部由编译期常量拼接的表达式在编译期即完成求值并入池，s 与 t 是同一引用。
- C：错误。字符串拼接语法合法。
- D：错误。无异常场景。

编译期常量折叠；只有含变量/方法的拼接才是运行期新对象。


### Java-001-045 | ★★★★☆

自动装箱与缓存

```java
Integer a = 127, b = 127;
Integer c = 128, d = 128;
System.out.println((a == b) + " " + (c == d));
```
输出是：

A. true true
B. true false
C. false true
D. false false

**答案：** B

**解析：**
- A：错误。128 超出缓存区间，c 与 d 是不同对象。
- B：正确。IntegerCache 缓存 -128~127，区间内 == 为 true；区间外自动装箱产生新对象，== 为 false。
- C：错误。127 在缓存内，a==b 为 true。
- D：错误。同上。

包装类型比较必须用 equals；缓存区间是实现细节但属高频考点。


### Java-001-046 | ★★★★☆

HashMap 树化条件

JDK 8 的 HashMap 中，某个桶的链表长度达到 8，该桶**一定**会转成红黑树吗？

A. 一定会，阈值就是 8
B. 不一定，还需数组长度 ≥ 64，否则优先扩容
C. 不一定，还要求负载因子大于 1
D. 一定不会，JDK 8 没有红黑树化

**答案：** B

**解析：**
- A：错误。漏掉了数组容量的前提条件。
- B：正确。树化条件为"链长 ≥ 8 且 table.length ≥ MIN_TREEIFY_CAPACITY(64)"，容量不足时先 resize 分散节点。
- C：错误。负载因子固定 0.75，与树化无关。
- D：错误。JDK 8 正是引入红黑树化的版本。

树化双条件：链长 8 + 数组 ≥64；退化阈值为 6。


### Java-001-047 | ★★★☆☆

ArrayList 扩容

无参构造的 ArrayList（JDK 8+）在首次 add 元素时，内部数组容量变为：

A. 0
B. 1
C. 10
D. 16

**答案：** C

**解析：**
- A：错误。无参构造确实是空数组（延迟分配），但首次 add 时会扩容。
- B：错误。首次扩容到默认容量 10，不是 1。
- C：正确。首次 add 触发 grow 到 DEFAULT_CAPACITY=10，之后每次扩为 1.5 倍。
- D：错误。16 是 HashMap 的默认容量，混淆了两个类。

懒初始化：构造不分配，首次 add 分配 10；1.5 倍增长。


### Java-001-048 | ★★☆☆☆

final 局部变量与 lambda

```java
int x = 10;
Runnable r = () -> System.out.println(x);
x = 20;
r.run();
```
结果是：

A. 打印 20
B. 打印 10
C. 编译错误
D. 打印 null

**答案：** C

**解析：**
- A：错误。代码根本无法通过编译。
- B：错误。若把 x=20 删除则打印 10；本例存在后续赋值。
- C：正确。lambda 捕获的局部变量必须是 effectively final，x 被二次赋值后编译失败（"local variables referenced from a lambda expression must be final or effectively final"）。
- D：错误。类型不匹配且无法编译。

lambda 捕获局部变量要求 effectively final；捕获的是值快照。


### Java-001-049 | ★★★☆☆

异常 finally 返回

```java
static int f() {
    int a = 1;
    try {
        return a;
    } finally {
        a = 2;
        System.out.println("finally");
    }
}
System.out.println(f());
```
输出顺序是：

A. finally 然后 1
B. 1 然后 finally
C. finally 然后 2
D. 2 然后 finally

**答案：** A

**解析：**
- A：正确。try 的 return 已把返回值 1 暂存，finally 先执行打印，随后方法返回暂存值 1；finally 中对局部变量 a 的修改不影响已暂存的基本类型返回值。
- B：错误。finally 在真正返回前执行。
- C：错误。返回值在 finally 修改局部变量前已固定为 1（基本类型值传递语义）。
- D：错误。同上。

finally 在返回值暂存后、真正返回前执行；基本类型返回值不受 finally 修改影响（引用类型改其内容则可见）。


### Java-001-050 | ★★☆☆☆

HashMap null 键位置

JDK 8 HashMap 中，null 作为 key 被存储在：

A. 数组的第 0 个桶
B. 数组最后一个桶
C. 单独的红黑树中
D. 不允许 null key

**答案：** A

**解析：**
- A：正确。hash(null) 固定返回 0，null 键存于 table[0]。
- B：错误。与数组长度无关联。
- C：错误。null 键不树化。
- D：错误。"不允许 null key"是 ConcurrentHashMap 的行为。

HashMap 允许一个 null key（hash 定位到 0 桶）、多个 null value。


### Java-001-051 | ★★★★☆

String 不可变与拼接

```java
String a = "hello";
String b = "he" + new String("llo");
System.out.println(a == b);
System.out.println(a.equals(b));
```

输出是：

A. `true true`
B. `false true`
C. `true false`
D. `false false`

**答案：** B

**解析：**
`new String("llo")` 是运行期堆对象，含变量的拼接在 JDK 8 生成新 StringBuilder 再 toString，结果在堆中，与常量池的 "hello" 不是同一对象，`==` 为 false；内容相同 equals 为 true。A/C/D 错。

编译期常量折叠入池 vs 运行期拼接进堆。


### Java-001-052 | ★★★☆☆

try-with-resources 关闭顺序

两个实现了 AutoCloseable 的资源 A、B 按声明顺序 `try (A a = ...; B b = ...)` 使用，退出 try 块时关闭顺序是：

A. 先 A 后 B
B. 先 B 后 A
C. 同时关闭
D. 只关闭 B

**答案：** B

**解析：**
try-with-resources 按声明的**逆序**关闭（类似栈），后声明的 B 先关；A 错；C/D 错。

逆序关闭匹配依赖关系（后获取的依赖先释放）。


### Java-001-053 | ★★★☆☆

重载匹配

```java
void f(int x)  { System.out.println("int"); }
void f(long x) { System.out.println("long"); }
void f(Integer x) { System.out.println("Integer"); }
void f(Object x) { System.out.println("Object"); }
...
f(10);
```

输出是：

A. int
B. long
C. Integer
D. Object

**答案：** A

**解析：**
重载解析优先级：精确匹配基本类型 > 宽化（int→long）> 装箱（Integer）> 变参/父类。f(10) 精确命中 f(int)。B 是宽化次选；C 装箱再次；D 最后。

重载选择在编译期按静态类型，优先级：基本精确→宽化→装箱→父类。


### Java-001-054 | ★★★☆☆

LinkedHashMap accessOrder

`new LinkedHashMap<>(16, 0.75f, true)` 第三个参数 true 的作用是：

A. 开启线程安全
B. 按访问顺序维护内部链表（get 也移动节点到尾部）
C. 允许 null key
D. 启用红黑树化

**答案：** B

**解析：**
A 错，LinkedHashMap 非线程安全；B 对，accessOrder=true 时访问序，配合 removeEldestEntry 即 LRU；C 错，本就允许；D 错，无树化。

accessOrder 决定插入序还是访问序；LRU 三步实现。


### Java-001-055 | ★★☆☆☆

NIO Buffer 状态

ByteBuffer 写入 10 字节后直接调用 get() 读取，正确做法是先调用：

A. clear()
B. flip()
C. rewind()
D. compact()

**答案：** B

**解析：**
flip 把 limit=position、position=0，切换为读模式；A 清空缓冲"忘记"边界；C 只归零 position 适合重读；D 用于读后接着写保留未读部分。

position/limit/capacity 三指针的读写切换。


### Java-001-056 | ★★☆☆☆

接口默认方法冲突

类 C 实现了接口 A、B，两者都有默认方法 `default String f()`。类 C 未重写 f() 时：

A. 随机使用其中一个
B. 编译错误：必须重写 f() 解决冲突
C. 使用先声明的接口
D. 使用父类版本

**答案：** B

**解析：**
多接口同名默认方法产生歧义，编译器强制类重写（可在重写中用 `A.super.f()` 指定）；A/C/D 错。

菱形冲突的"类优先+必须重写"规则。

