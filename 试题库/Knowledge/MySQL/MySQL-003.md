### MySQL-003-001 | ★★★★☆

如何排查慢 SQL？如果不改代码，慢查询可以怎么优化？慢查询日志阈值过小或过大会怎么样？

**答案：**
开慢查询日志定位，explain 看 type/key/Extra 判断索引与全表扫描；不改代码可加覆盖索引、调大 buffer pool、上缓存、分库分表/冷热分离；阈值过小日志暴增占磁盘，过大漏检慢 SQL。


### MySQL-003-002 | ★★★★★

间隙锁的原理是什么？什么时候会加间隙锁？MySQL 的什么命令会加上间隙锁？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_giants/aliyun.html

**答案：**
RR 级别下可重复读防幻读，锁住索引记录之间的开区间，与行锁合成临键锁 Next-Key Lock；当前读（select ... for update / lock in share mode、update、delete）命中非唯一索引或范围条件时加，唯一索引等值命中退化为行锁。


### MySQL-003-003 | ★★★★★

间隙锁会不会出现死锁情况？为什么？

**答案：**
会。间隙锁之间相互兼容（两个事务可同时锁同一间隙），但插入意向锁要等待对方的间隙锁释放，形成"你等我间隙锁、我等你插入"的交叉等待即可死锁，InnoDB 回滚代价小的事务解除。


### MySQL-003-004 | ★★★★☆

MySQL update 语句会上哪些锁？当我范围查询的时候是怎么上锁的？查询的时候字段必须建立索引吗？

**答案：**
当前读对命中的记录加 X 行锁，RR 下对扫描范围加 Next-Key Lock，未命中退化为间隙锁；无索引可用时全表扫描会对所有记录加锁（近乎锁全表），所以范围更新条件字段最好有索引。


### MySQL-003-005 | ★★★★☆

两条 update 语句处理同一张表不同主键范围的记录（一个<10，一个>15），会不会阻塞？如果 2 个范围不是主键或索引，还会阻塞吗？

**答案：**
主键范围不重叠时各锁各的范围记录与间隙，不阻塞；无索引时都会走全表扫描并给扫过的记录加锁，导致相互阻塞。


### MySQL-003-006 | ★★★★★

设计一个行级锁的死锁，举一个实际的例子。

**答案：**
事务 A 先 update id=1 再 update id=2，事务 B 先 update id=2 再 update id=1，两事务各持一把对方需要的锁形成循环等待；或两个事务先共享锁再升级排他锁、间隙锁+插入交叉等待。


### MySQL-003-007 | ★★★★★

死锁的时候 CPU 利用率是高还是低？为什么？

**答案：**
低。死锁线程都在等待锁被挂起，不消耗 CPU；而 CPU 飙高通常是死循环、频繁 GC 或大量计算/上下文切换导致的。


### MySQL-003-008 | ★★★★★

介绍 MVCC 的实现原理？RC 和 RR 隔离级别下 MVCC 的差异是什么？
SRC2: https://javaguide.cn/database/mysql/innodb-implementation-of-mvcc.html

**答案：**
通过隐藏字段 trx_id/roll_pointer 串成 undo log 版本链，读时生成 ReadView（m_ids、min/max_trx_id、creator_trx_id）沿版本链找可见版本；RC 每次快照读生成新 ReadView，RR 只在第一次快照读生成并复用，从而实现可重复读。


### MySQL-003-009 | ★★★★☆

undo log 撤销过程具体是怎么撤销的？

**答案：**
undo log 记录反向操作（insert 存主键对应删除、update 存旧值反向更新、delete 存整行），回滚时按 trx_id 找到对应 undo 链从后往前执行反向补偿，同时清理对应版本链。


### MySQL-003-010 | ★★★★☆

为什么要写 RedoLog，而不是直接写到 B+ 树里面？RedoLog 是在内存里吗？MySQL 如何保障数据不丢失？

**答案：**
直接改 B+ 树页是随机 IO 且页未刷盘宕机即丢；redo log 是 WAL 顺序写，先写 log buffer 并在事务提交时刷盘（innodb_flush_log_at_trx_commit=1）保证持久性，脏页后台再慢慢刷。数据不丢失靠 redo log 刷盘 + binlog 两阶段提交。


### MySQL-003-011 | ★★★★☆

mysql 两次写（double write buffer）了解吗？为什么 redolog 无法代替 double write buffer？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_medium/haoweilai.html

**答案：**
部分写失效（partial page write，16KB 页只写了一半断电）时 redo 无法应用，double write 先把脏页顺序写进共享表空间的副本区再写磁盘页，崩溃恢复用副本还原完整页后再做 redo。


### MySQL-003-012 | ★★★★☆

binlog 两阶段提交过程是怎么样的？能不能只用 binlog 不用 redo log？

**答案：**
写 redo log 置 prepare → 写 binlog → 提交时 redo log 置 commit，保证两日志逻辑一致，崩溃恢复时按 binlog 是否完整决定提交或回滚；只用 binlog 无法做崩溃恢复过程中的未提交事务回滚与幂等，只用 redo 无法支撑主从复制和归档。


### MySQL-003-013 | ★★★★★

MySQL 主从复制了解吗？主从延迟都有什么处理方法？

**答案：**
主库写 binlog，从库 IO 线程拉取写 relay log，SQL 线程重放。延迟处理：写后短时间读主、强制走主读（GTID/标注）、并行复制（MTS）降低重放延迟、监控 Seconds_Behind_Master，敏感业务读写分离时做会话内粘性读主。


### MySQL-003-014 | ★★★★☆

MySQL 什么情况下需要分库分表？分片键如何选择？分库分表后数据怎么迁移？
SRC2: https://javaguide.cn/high-performance/read-and-write-separation-and-library-subtable.html

**答案：**
单表数据量/并发到瓶颈（B+ 树层高、锁与备份压力）时考虑；分片键选查询最常用、分布均匀的字段（如 user_id）；迁移用双写+全量同步+增量追平+灰度切流，保留回滚窗口。


### MySQL-003-015 | ★★★★☆

深度分页为什么慢？如何优化？

**答案：**
LIMIT offset,N 要扫描并丢弃前 offset 行；优化：游标分页（where id > last_id limit N，连续页）、延迟关联（先覆盖索引查主键再回表）、子查询定位起始主键，业务上限制最大页数。


### MySQL-003-016 | ★★★★☆

count(*)、count(1)、count(主键)、count(字段) 哪种性能最好？如何优化 count(*)？

**答案：**
count(字段) 最慢（要取值判空）；count(主键)/count(1)/count(*) InnoDB 都会选最小的索引扫描，count(*) 与 count(1) 无差别且语义安全。优化：近似值 explain rows、缓存计数、单独计数表维护。


### MySQL-003-017 | ★★★★☆

字符集会不会影响索引？常见的索引失效场景还有哪些？

**答案：**
会，字段与查询字符集不一致需隐式转换函数，破坏索引有序性导致失效。其他：对索引列用函数/运算、前导模糊 LIKE '%x'、隐式类型转换、不满足最左匹配、OR 两侧有无索引、优化器估算走错索引等。


### MySQL-003-018 | ★★★★☆

如果 Explain 用到的索引不正确的话，有什么办法干预吗？

**答案：**
用 force index / ignore index / use index 强制或建议索引，或改写 SQL、更新统计信息（analyze table）影响优化器代价估算。

