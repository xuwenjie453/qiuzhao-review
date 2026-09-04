### Redis-003-001 | ★★★★☆

Redis 的大 Key 问题是什么？有什么缺点？如何解决？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_giants/mayi.html

**答案：**
单个 key 的 value 过大（String 几 MB、集合元素几万以上），缺点是阻塞单线程、慢查询、网络拥塞、集群数据倾斜、删除引发阻塞；解决：拆分成多个 key/分片集合、压缩、用 UNLINK 异步删除、scan 渐进式排查、业务侧限制写入大小。


### Redis-003-002 | ★★★★★

什么是热 key？如何解决热 key 问题？

**答案：**
某个 key 访问 QPS 极高打满单节点带宽/CPU。解决：本地缓存（多级缓存）拦截热点读、key 加随机后缀打散到多节点、读写分离扩副本、限流兜底。


### Redis-003-003 | ★★★★☆

Redis Cluster 集群的客户端是怎样知道该访问哪个分片的？

**答案：**
客户端可连任意节点，节点返回 CRC16(key) % 16384 对应 slot 的路由信息；访问到非负责节点时返回 MOVED 重定向（扩缩容迁移中返回 ASK，需先发 ASKING 再重试）。


### Redis-003-004 | ★★★★☆

Redis 主从同步中的增量和完全同步是怎么实现的？

**答案：**
首次/断线过久做完全同步：主 bgsave 生成 RDB 发给从库，期间写命令进 replication buffer 随后补发；短暂断线用 repl_backlog 环形缓冲区做增量同步（PSYNC 带 offset），offset 被覆盖则退化为全量。


### Redis-003-005 | ★★★★★

Redisson 的看门狗机制是什么？Redis 锁不释放/业务没执行完锁过期了怎么续期？
SRC2: https://www.cnblogs.com/crazymakercircle/p/19591448

**答案：**
lock() 不传 leaseTime 时启用看门狗：默认锁 30 秒过期，Netty 时间轮每 10 秒（1/3）用 Lua 脚本检查持有者并把 TTL 重置为 30s，unlock 时取消续期任务；显式指定 leaseTime 则不启动看门狗。


### Redis-003-006 | ★★★★☆

Redis 实现的分布式锁还有什么缺点？红锁（RedLock）是什么？zookeeper 实现分布式锁和 redisson 有什么区别？

**答案：**
主从异步复制下主宕机可能锁丢失、时钟漂移影响 RedLock 正确性，RedLock 向多个独立主节点加锁过半成功才算成功；ZK 用临时顺序节点+watch，CP 语义更可靠但吞吐低于 Redis 的 AP 方案。


### Redis-003-007 | ★★★★☆

如何设计一个可重入的分布式锁？用什么结构设计？

**答案：**
用 Hash 结构：field 存"客户端ID+线程ID"，value 存重入次数；加锁 Lua 里 HINCRBY 并设置 TTL，解锁时先判断持有者匹配再减 1，减到 0 删除 key，Redisson 正是此实现。


### Redis-003-008 | ★★★★☆

跳表是怎么实现的？跳表是怎么设置层高的？跳表的时间复杂度是多少？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_giants/byte_dance.html

**答案：**
多层有序链表，每层是下层的索引；新节点层高用幂次定律随机生成（每晋升一层概率 25%，最高 64 层），期望查找/插入/删除 O(logN)。


### Redis-003-009 | ★★★★☆

Redis 为什么使用跳表而不是用 B+ 树？为什么 MySQL 不用跳表？

**答案：**
Redis 内存操作、范围查询需求简单，跳表实现简单、无需旋转调整、并发控制容易，作者 antirez 明确此取舍；MySQL 数据在磁盘，B+ 树一个节点一页、树高低、IO 次数少，跳表层数随机导致磁盘 IO 次数不可控。


### Redis-003-010 | ★★★★☆

Redis 哪些地方使用了多线程？Redis 6.0 之后为什么引入了多线程？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_medium/haikang.html

**答案：**
命令执行仍是单线程；多线程用于后台任务（异步删除 UNLINK、AOF 刷盘/重写、大 key 异步释放）和 6.0 起的网络 IO 读写与协议解析，利用多核提升吞吐。


### Redis-003-011 | ★★★★☆

Redis 怎么实现 IO 多路复用？它的网络模型是怎样的？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_medium/xiaohongshu.html

**答案：**
单线程 Reactor 模式：IO 多路复用 epoll 统一监听 socket 事件，事件分派器把就绪事件投递给命令处理器，串行执行命令避免锁；6.0 后读写解析可多线程但命令执行仍串行。


### Redis-003-012 | ★★★★☆

Redis 的哈希表是怎么扩容的？扩容的时候有读请求怎么查？

**答案：**
渐进式 rehash：同时持有 ht[0]/ht[1]，每次增删改查迁移一个桶；读请求先查 ht[0] 再查 ht[1]，写请求只写 ht[1]，迁移完释放旧表。


### Redis-003-013 | ★★★★☆

怎么保证 Redis 和 MySQL 的数据一致性？高并发场景下数据库和缓存一致性方案怎么对比？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_medium/xiecheng.html

**答案：**
主流 Cache Aside：先更新 DB 再删缓存（概率最小），配合延迟双删、binlog 订阅（Canal）异步删缓存保证最终一致；强一致需要分布式锁/串行化代价高，一般业务接受最终一致并设过期时间兜底。

