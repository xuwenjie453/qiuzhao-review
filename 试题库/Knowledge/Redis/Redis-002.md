### Redis-002-001 | ★★★★☆

怎么保证MySQL和Redis的数据一致性？

**答案：**
常用Cache Aside旁路缓存+延迟双删，或订阅binlog（Canal）异步更新缓存；强一致场景需加锁串行化。


### Redis-002-002 | ★★★★☆

Redis数据结构有哪些？

**答案：**
String、List、Hash、Set、ZSet五种基础类型，及Bitmap、HyperLogLog、GEO、Stream等扩展类型。


### Redis-002-003 | ★★★★☆

RDB和AOF分别是什么？

**答案：**
RDB是定时内存快照，文件小恢复快但可能丢数据；AOF追加写命令（可everysec），更可靠但文件大恢复慢；4.0后支持混合持久化。


### Redis-002-004 | ★★★★☆

redis为什么快？

**答案：**
纯内存操作、单线程无锁竞争和上下文切换、IO多路复用、高效数据结构（SDS、跳表、压缩列表等）。


### Redis-002-005 | ★★★★★

介绍一下redis中的事务、lua脚本和pipeline？

**答案：**
multi/exec事务不保证原子性（命令入队出错外不回滚）；lua脚本原子执行且可带逻辑；pipeline批量发送命令减少网络RTT但非原子。


### Redis-002-006 | ★★★★★

redis分布式锁的实现？

**答案：**
set key uniqueValue nx ex加锁，释放时用lua校验value再删防止误删；生产建议Redisson（可重入、看门狗自动续期）。


### Redis-002-007 | ★★★★★

出现单机redis挂掉的场景，如何保证分布式锁可用？

**答案：**
主从+哨兵/集群自动故障转移；但主从异步复制可能丢锁，更严格可用RedLock多实例或Redisson，或改用ZooKeeper/etcd。


### Redis-002-008 | ★★★★★

redis的集群模式，为什么槽位是16384，不是1024？

**答案：**
节点间心跳用bitmap传播槽位信息，16384个槽约2KB够用且控制了心跳包大小；集群设计上限约1000节点，1024不够表达，CRC16取模16384计算方便。


### Redis-002-009 | ★★★★★

Redis集群部署模式了解吗？

**答案：**
主从复制（读写分离）、哨兵Sentinel（高可用自动故障转移）、Cluster集群（16384槽分片+Gossip协议）。


### Redis-002-010 | ★★★★★

在主从集群上使用SETNX做分布式锁，可能有什么问题，怎么解决？

**答案：**
主从异步复制，主节点写锁后宕机、从晋升时锁丢失导致两个客户端同时持锁；可等复制到从节点再加锁、RedLock多数派方案，或用ZooKeeper/etcd。


### Redis-002-011 | ★★★★★

Redis的缓存穿透、击穿、雪崩问题是怎么解决的？

**答案：**
穿透：缓存空值或布隆过滤器；击穿：热点key互斥锁或逻辑过期；雪崩：过期时间加随机、多级缓存、集群高可用、限流降级。


### Redis-002-012 | ★★★★☆

为什么用Redis而不用本地缓存（如Guava Cache/Caffeine）？

**答案：**
本地缓存进程内最快但容量受限于JVM堆、多节点数据不一致、重启丢失；Redis集中式大容量、持久化、多应用共享并支持丰富数据结构与高可用。


### Redis-002-013 | ★★★★☆

常见的缓存读写策略（Cache Aside/Read-Write Through/Write Behind）有哪些？

**答案：**
Cache Aside旁路缓存：读先查缓存、写先更库再删缓存（最常用）；Read/Write Through缓存层代理同步读写；Write Behind先写缓存异步批量刷库（性能高可能丢）。


### Redis-002-014 | ★★★★☆

Redis 6.0之前为什么不使用多线程？之后为何又引入了多线程？

**答案：**
瓶颈在内存与网络而非CPU，单线程免锁免切换且实现简单；6.0引入多线程只用于网络IO读写与协议解析，命令执行仍单线程，提升吞吐且保持一致性。


### Redis-002-015 | ★★★★☆

Redis过期key的删除策略了解吗？

**答案：**
惰性删除（访问时检查）+定期删除（周期随机抽样淘汰过期键）组合，再配合内存淘汰策略兜底。


### Redis-002-016 | ★★★★☆

Redis的内存淘汰策略了解吗？

**答案：**
8种：noeviction（默认，写报错）、allkeys-lru、volatile-lru、allkeys-lfu、volatile-lfu、allkeys-random、volatile-random、volatile-ttl。


### Redis-002-017 | ★★★★☆

Redis的有序集合（ZSet）底层为什么用跳表而不用红黑树？

**答案：**
跳表实现简单、范围查询（zrange）天然高效、内存可通过节点层数概率调节，并发修改也更简单；综合性能与红黑树相当。


### Redis-002-018 | ★★★★☆

如何基于Redis实现延时任务？

**答案：**
ZSet以到期时间戳为score，轮询zrangebyscore取出到期任务执行；或Redisson的DelayedQueue；key过期事件通知不可靠不建议。


### Redis-002-019 | ★★★★☆

什么是Redis的bigkey（大Key）？有什么危害，怎么处理？

**答案：**
value过大或集合元素过多的key；危害：单线程阻塞、网络拥塞、删除卡顿、集群数据倾斜。用redis-cli --bigkeys 扫描，拆分数据、异步unlink删除。


### Redis-002-020 | ★★★★★

Redis主从复制的原理能介绍一下吗？

**答案：**
首次全量复制：主库bgsave生成RDB发给从库，期间新写命令进缓冲区后补发；之后增量复制走repl_backlog_offset，断线重连按offset补发。


### Redis-002-021 | ★★★★★

Redis Cluster集群模式的工作原理？key是如何寻址的？

**答案：**
16384个哈希槽分布在多个节点，key经CRC16(key)%16384定位槽；请求错节点返回MOVED/ASK重定向，smart客户端本地缓存路由，Gossip协议维护元数据。

