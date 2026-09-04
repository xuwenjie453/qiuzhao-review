### Java-002-001 | ★★★★☆

聊聊你对进程、线程、协程的理解？

**答案：**
进程是资源分配的基本单位有独立地址空间；线程是CPU调度的基本单位共享进程资源；协程是用户态调度的轻量执行单元，切换不开销内核态。


### Java-002-002 | ★★★★☆

进程和线程有什么区别？

**答案：**
进程有独立地址空间和资源，线程从属进程共享其内存；线程切换和通信开销更小，但一个线程崩溃可能影响整个进程。


### Java-002-003 | ★★★★★

HashMap和ConcurrentHashMap有什么区别？

**答案：**
HashMap线程不安全、允许一个null键多个null值；ConcurrentHashMap用CAS+synchronized保证并发安全，key和value均不能为null。


### Java-002-004 | ★★★★☆

Java动态代理了解吗？

**答案：**
JDK动态代理基于接口+反射（InvocationHandler）；CGLIB通过生成子类字节码实现，无接口也可代理，但final类/方法不行。


### Java-002-005 | ★★★★☆

StringBuilder和StringBuffer的区别？

**答案：**
都是可变字符序列；StringBuffer方法加了synchronized线程安全但性能略低，StringBuilder非线程安全性能更好。


### Java-002-006 | ★★★★☆

简单说一下LRU缓存结构的实现？

**答案：**
HashMap+双向链表：O(1)定位节点，访问移到链头，容量满淘汰链尾；Java可用LinkedHashMap并重写removeEldestEntry。


### Java-002-007 | ★★★★☆

数组（Array）和ArrayList的区别？

**答案：**
数组长度固定、可存基本类型；ArrayList容量可动态扩容（1.5倍）、只能存引用类型（泛型），底层是数组。


### Java-002-008 | ★★★★☆

哪些集合是线程安全的？

**答案：**
遗留类Vector、Hashtable、Stack；并发包下的ConcurrentHashMap、CopyOnWriteArrayList、ConcurrentLinkedQueue、BlockingQueue系列等。


### Java-002-009 | ★★★★☆

LRU缓存的核心逻辑是什么？

**答案：**
淘汰最久未使用的数据：get/put时将节点移到头部，容量超限删除尾部；HashMap+双向链表实现O(1)。


### Java-002-010 | ★★★★★

介绍一下HashMap（的底层实现）？

**答案：**
JDK1.8数组+链表+红黑树：hash扰动定位桶，链长>=8且数组容量>=64树化，退化阈值6；负载因子0.75，超阈值扩容一倍。


### Java-002-011 | ★★★★★

HashMap链表转红黑树的优缺点有哪些？

**答案：**
优点：哈希冲突严重时查找从O(n)降到O(logn)，防御哈希碰撞攻击；缺点：树节点内存占用大、维护（旋转变色）成本高，所以树化有阈值且会退化。


### Java-002-012 | ★★★★☆

说一下JDK 1.8的新特性？

**答案：**
Lambda表达式、函数式接口、Stream API、接口default/static方法、新的时间API、HashMap树化、元空间取代永久代等。


### Java-002-013 | ★★★★☆

Lambda的实现原理是什么？

**答案：**
编译为私有静态方法+invokedynamic指令，运行时由LambdaMetafactory动态生成实现函数式接口的类，并非匿名内部类。


### Java-002-014 | ★★★★☆

Java常见的函数式接口有哪些？

**答案：**
Function<T,R>、Predicate<T>、Consumer<T>、Supplier<T>，及其Bi变体和IntPredicate等原始类型特化。


### Java-002-015 | ★★★★☆

说一说ArrayList的扩容机制吧

**答案：**
无参构造默认容量10，add时容量不足则扩为原来的1.5倍（oldCap + oldCap>>1），通过Arrays.copyOf迁移数组。


### Java-002-016 | ★★★★☆

ArrayList与LinkedList的区别是什么？

**答案：**
ArrayList底层数组随机访问O(1)、中间插删O(n)、内存连续；LinkedList双向链表插删定位后O(1)但随机访问O(n)，额外存前后指针。


### Java-002-017 | ★★★★☆

集合中的fail-fast和fail-safe是什么？

**答案：**
fail-fast迭代器比对modCount，检测到结构变更抛ConcurrentModificationException；fail-safe（并发容器/CopyOnWrite）遍历快照不抛异常但可能读到旧数据。


### Java-002-018 | ★★★★★

HashMap和Hashtable的区别是什么？

**答案：**
HashMap非线程安全、允许null键值、默认容量16扩容2倍；Hashtable线程安全（方法synchronized）、不允许null、默认11扩容2n+1。


### Java-002-019 | ★★★★★

HashMap的长度为什么是2的幂次方？

**答案：**
使hash&(n-1)等价取模且更高效、散列更均匀；扩容后节点要么留原位要么移到原位置+oldCap，迁移简单。


### Java-002-020 | ★★★★★

HashMap为什么线程不安全？多线程操作HashMap会导致什么问题？

**答案：**
JDK1.7头插法并发扩容可能成环形链表导致死循环；1.8改尾插后仍有数据覆盖丢失、size不准确等问题，并发场景用ConcurrentHashMap。


### Java-002-021 | ★★★★★

ConcurrentHashMap线程安全的具体实现方式（JDK1.8底层实现）是什么？

**答案：**
CAS+volatile处理初始化与空桶插入，非空桶用synchronized锁头节点，链表/红黑树存储，扩容时多线程协助迁移（ForwardingNode）。


### Java-002-022 | ★★★★★

JDK 1.7和JDK 1.8的ConcurrentHashMap实现有什么不同？

**答案：**
1.7采用Segment分段锁（默认16段，锁粒度大）；1.8取消分段，改为CAS+synchronized锁单个桶，并引入红黑树，并发度更高。

