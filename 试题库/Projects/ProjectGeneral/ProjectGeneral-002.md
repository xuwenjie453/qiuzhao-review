### ProjectGeneral-002-001 | ★★★★☆

MySQL 中如何定位慢查询？（项目场景：线上接口变慢，怀疑SQL问题）

**答案：**
作业帮Java后端一面原题。开源工具：skywalking、Prometheus+Grafana监控链路找到慢接口；MySQL侧开启slow_query_log，用mysqldumpslow或EXPLAIN分析。


### ProjectGeneral-002-002 | ★★★★☆

慢查询怎么分析？（explain 各字段怎么看）

**答案：**
贝壳找房——面原题。用EXPLAIN看：type（system>const>eq_ref>ref>range>index>ALL，尽量达到range以上）、key实际索引、rows扫描行数、extra（Using filesort/Using temporary需优化）。


### ProjectGeneral-002-003 | ★★★★☆

线上如何优化慢查询语句？（腾讯云后台技术一面原题）

**答案：**
SQL与索引层面（避免索引失效、覆盖索引、联合索引顺序）、表结构（合适字段类型、适当冗余）、架构层面（读写分离、分库分表、缓存、冷热分离）。


### ProjectGeneral-002-004 | ★★★★☆

说说 SQL 该如何优化？（华为技术二面原题）

**答案：**
从explain分析执行计划入手，优化索引设计、避免select *、减少回表、拆分复杂join、必要时引入缓存或分库分表。


### ProjectGeneral-002-005 | ★★★★☆

explain 分析后，type 的执行效率等级是怎样的？达到什么级别比较合适？（贝壳找房一面原题）

**答案：**
system>const>eq_ref>ref>range>index>ALL；一般至少达到range级别，最好ref以上，避免ALL全表扫描。


### ProjectGeneral-002-006 | ★★★★☆

explain 输出中 key_len 有什么用？你还会看 explain 中的哪些字段？extra 有哪些类型？

**答案：**
作业帮一面原题。key_len判断联合索引用了几个字段；还会看type、rows、key；extra常见Using index（覆盖索引，好）、Using where、Using filesort、Using temporary（需优化）。


### ProjectGeneral-002-007 | ★★★★★

where b = 5 这样的查询是否一定会命中索引？哪些情况会导致索引失效？（字节跳动Java后端一面原题）

**答案：**
不一定：对索引列做函数/运算、隐式类型转换、like以%开头、不满足最左前缀、or连接无索引列、优化器认为回表代价高（区分度低）等都会失效。


### ProjectGeneral-002-008 | ★★★★☆

什么是深分页？select * from tbn limit 1000000000 这样写有什么问题？表大表小分别是什么问题？（字节跳动Java后端二面原题）

**答案：**
offset过大时MySQL需扫描并丢弃前面所有行：小表 buffer pool 能放下影响稍小，大表大量回表/磁盘IO导致严重性能问题；优化：游标/延迟关联（先查id再回表）、子查询定位起始id。


### ProjectGeneral-002-009 | ★★★★☆

说说 OOM（内存溢出）的原因有哪些？（京东Java技术一面原题）

**答案：**
堆内存不足（大对象、内存泄漏）、元空间溢出（动态生成类过多）、虚拟机栈/本地方法栈溢出、直接内存不足；常见如一次性查询大量数据、静态集合持有对象不释放。


### ProjectGeneral-002-010 | ★★★★☆

Java 哪些内存区域会发生 OOM？为什么？（快手主站技术部原题）

**答案：**
堆（对象过多/泄漏）、元空间（类元数据超MaxMetaspaceSize）、虚拟机栈（线程过多或栈深递归，StackOverflow/OOM）、直接内存（NIO Buffer超出限制）。


### ProjectGeneral-002-011 | ★★★★☆

线上内存泄漏怎么排查？（美团一面原题）

**答案：**
jmap -dump导出堆快照（或-XX:+HeapDumpOnOutOfMemoryError自动dump），用MAT/JProfiler分析支配树找最大对象及GC Root引用链，定位未释放的集合/缓存/ThreadLocal等。


### ProjectGeneral-002-012 | ★★★★☆

如何排查 OOM？（华为Java通用软件开发一面原题）

**答案：**
先看OOM类型与日志，dump堆快照用MAT分析大对象与引用链，结合代码定位（大查询、缓存无上限、资源未关闭等），修复后加监控告警。


### ProjectGeneral-002-013 | ★★★★☆

服务器 CPU 占用持续升高，有哪些排查问题的手段？如果排查后发现是项目产生了内存泄露，如何确定问题出在哪里？（快手一面原题）

**答案：**
top定位进程→top -Hp看线程→jstack（或printf转16进制后匹配线程id）找高CPU线程栈；内存泄漏则jmap dump后MAT分析支配树和引用链定位泄漏对象。


### ProjectGeneral-002-014 | ★★★★☆

线上服务内存、CPU 飙高，或者接口超时，说说大概的排查思路？具体可以用哪些工具？（京东JDS原题）

**答案：**
CPU：top+jstack；内存：jmap+jstat看GC情况+MAT；接口超时：链路追踪定位慢在哪个环节（DB慢查询、下游依赖、GC停顿），结合arthas在线诊断。


### ProjectGeneral-002-015 | ★★★★★

young GC 频繁如何排查？可以修改哪些参数？（京东面试原题）

**答案：**
jstat -gcutil观察 eden增速与YGC频率，分析是否有大量朝生夕死对象或新生代过小；调整-Xmn/-XX:SurvivorRatio、检查大对象分配（-XX:PretenureSizeThreshold）。


### ProjectGeneral-002-016 | ★★★★★

Java 服务频繁 Full GC，有哪些原因？（得物一面原题）

**答案：**
老年代空间不足（内存泄漏/大对象/缓存膨胀）、元空间不足、System.gc()调用、显式 Promotion Failed；结合jstat与GC日志定位。


### ProjectGeneral-002-017 | ★★★★☆

介绍一下你的项目整体架构设计（面试官要求边画架构图边解释），并说说如果项目需要满足 10W QPS 的需求，架构该如何设计？（腾讯面经，80分钟项目拷打）

**答案：**
思路：无状态服务水平扩展+负载均衡、多级缓存（本地/Redis）、读写分离与分库分表、异步化削峰、CDN、限流熔断降级保护。


### ProjectGeneral-002-018 | ★★★★☆

项目里面高并发下如何实现请求的过滤以及削峰？（腾讯面经原题）

**答案：**
过滤：网关层黑名单/风控/限流（令牌桶、sentinel）；削峰：消息队列缓冲异步处理、缓存拦截热点读。


### ProjectGeneral-002-019 | ★★★★☆

高并发与异步的服务器怎么设计？（腾讯面经原题）

**答案：**
IO多路复用/Reactor模型、线程池处理请求、非阻塞异步调用下游、消息队列解耦异步化。


### ProjectGeneral-002-020 | ★★★★☆

你项目最初 QPS 只有几万，如何一步步优化到 20 万 QPS 的？（格蓝若二面项目拷打实例）

**答案：**
候选人答：通过内存池、无锁队列、零拷贝等优化手段逐级提升；考察高性能系统设计原理（减少拷贝、减少锁竞争、池化复用）。


### ProjectGeneral-002-021 | ★★★★★

集群环境下如何保证数据的一致性？（腾讯面经，项目追问）

**答案：**
主从复制与同步保证副本一致；跨服务按业务选强一致（分布式锁/协调服务）或最终一致（消息+补偿）。


### ProjectGeneral-002-022 | ★★★★★

服务器集群以后如何做到数据的共享？（腾讯面经，项目追问）

**答案：**
共享存储（DB/Redis/对象存储）、分布式缓存与Session集中化、配置和服务注册中心（ZooKeeper/Nacos）。


### ProjectGeneral-002-023 | ★★★★☆

如果要做万级并发（万并发）压测，你怎么做？

**答案：**
单机施压能力有限，采用分布式压测：多台施压机（JMeter master-slave或云压测平台），master调度、slave执行，汇总结果，同时监控被压端资源与中间件水位。

