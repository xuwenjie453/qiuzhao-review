### BigData-002-001 | ★★★☆☆

HDFS 读写流程分别介绍一下，写数据过程中有哪些故障，分别会怎么处理？

**答案：**
HDFS写流程：Client向NameNode请求上传→NameNode检查目录/权限→Client切Block请求第一个DataNode→DataNode建立pipeline逐级应答→Client以packet流式写数据，flush落到磁盘→success回执。写失败时客户端从pipeline中摘除故障节点，由剩余节点继续，并向NameNode上报，NameNode后续安排补齐副本。


### BigData-002-002 | ★★★☆☆

HDFS 的 NameNode 高可用（HA）如何实现？需要哪些角色？

**答案：**
主备NameNode + ZKFC（失败检测控制器，借助ZooKeeper做选举）+ JournalNode集群（共享edits日志，主写备读做元数据同步）+ 共享存储/standby周期性checkpoint。


### BigData-002-003 | ★★★☆☆

HDFS 的 block 为什么默认是 128M？增大或减小会有什么影响？

**答案：**
块太小→文件数多，NameNode元数据（内存）压力大、寻址时间占比高；块太大→map任务数少、并行度低，单任务失败代价大。128M是对元数据规模和并行度的折中。


### BigData-002-004 | ★★★☆☆

MapReduce 的 Shuffle 过程是怎样的？有哪些优化手段？

**答案：**
map输出写环形缓冲区（默认100M，80%溢写）→分区、排序（快排）、可选combiner、压缩溢写文件→merge归并成一个大文件→reduce端拉取（copy，默认map完成5%后开始）→merge排序→按key分组交给reduce。优化：调大缓冲区、combiner、map端压缩、调整reduce拉取并行度。


### BigData-002-005 | ★★★☆☆

MapReduce 运行过程中会发生 OOM，OOM 可能发生在哪些位置？

**答案：**
常见于：map/reduce任务的JVM堆（如reduce阶段数据倾斜、缓冲区数据过大）；溢写前内存数据过多；YARN的Container内存超限被kill（物理内存/虚拟内存超限）也可归入讨论。


### BigData-002-006 | ★★★☆☆

MapReduce 数据倾斜产生的原因是什么？如何解决？Map Join 为什么能解决数据倾斜？

**答案：**
原因：key分布不均、空值过多、大表直接join。方案：空key加随机数打散、两阶段聚合（局部聚合+全局聚合）、Map Join。Map Join把小表加载到内存构建哈希表在map端完成join，免除shuffle，因此倾斜的key不会再集中到少数reduce。


### BigData-002-007 | ★★★☆☆

Hadoop 小文件问题怎么处理？

**答案：**
小文件会占用NameNode大量元数据内存、map任务数爆炸。方案：har打包归档、sequencefile合并、定期job合并小文件、上游改成可追加写（Flume/参数控制滚动）等。


### BigData-002-008 | ★★★☆☆

Hive 内部表和外部表的区别？为什么用外部表更好？

**答案：**
drop时内部表删除元数据和HDFS数据，外部表只删除元数据（表结构），数据保留。外部表更安全，适合多方共享原始数据的场景。


### BigData-002-009 | ★★★☆☆

Hive 数据倾斜如何定位与解决？

**答案：**
定位：看task运行时间/日志中个别reduce极大延迟。解决：group by倾斜开启hive.groupby.skewindata两段聚合、join倾斜开启mapjoin（hive.auto.convert.join）、大key打散、count(distinct)改写为group by再count、过滤异常key。


### BigData-002-010 | ★★★☆☆

Hive 的 sort by、distribute by、cluster by、order by 有什么区别？

**答案：**
order by全局排序（单reduce）；sort by区内排序；distribute by指定分发到reduce的key（常与sort by配合）；cluster by = distribute by + sort by 同一字段，不支持升降序指定。


### BigData-002-011 | ★★★☆☆

Hive 分区和分桶的区别是什么？

**答案：**
分区按目录隔离数据（粗粒度裁剪，如按dt）；分桶按某列hash分成固定数量的文件，利于抽样、mapjoin和提高join效率。


### BigData-002-012 | ★★★☆☆

Hive 中 count(distinct) 有几个 reduce？海量数据下会有什么问题？

**答案：**
默认一个reduce（按distinct key聚合），海量数据会数据倾斜、单点慢。优化：先group by去重再count，或分段去重汇总。


### BigData-002-013 | ★★★☆☆

用 Hive SQL 实现查询用户连续登陆，讲讲思路。

**答案：**
经典思路：按用户去重的登陆日期，用row_number() over(partition by uid order by dt)生成序号，用 date_sub(dt, rn) 分组，组内count>=N即为连续登陆N天。


### BigData-002-014 | ★★★☆☆

一条 Hive SQL 从提交代码到执行经历了哪些过程？

**答案：**
SQL→语法/语义解析（AST）→生成查询块QB→逻辑执行计划（OperatorTree）→逻辑优化（谓词下推、列裁剪等）→物理计划（MapReduce/Tez任务）→优化→提交集群执行。


### BigData-002-015 | ★★★☆☆

Kafka 怎么保证数据不丢失、不重复？

**答案：**
不丢失：producer设acks=-1、retries；broker的min.insync.replicas>=2、unclean.leader.election.enable=false；consumer先处理后提交offset。不重复：producer开启幂等（enable.idempotence）和事务，consumer侧幂等处理。


### BigData-002-016 | ★★★☆☆

说下 Kafka 的 ISR 机制，以及 ack 参数分别有哪几种取值，各自代表什么？

**答案：**
ISR是 与leader保持同步的副本集合（含leader），落后过多被踢出。acks=0不等确认；acks=1只等leader写入；acks=-1(all)等ISR全部写入，最可靠但延迟高。


### BigData-002-017 | ★★★☆☆

正在消费一条数据时 Kafka 挂了，重启以后，消费的 offset 是哪一个？

**答案：**
取决于提交时机：若先消费后提交offset，重启后从上次已提交的offset重新消费（可能重复）；若先提交后处理则可能丢失。至少一次语义下重启会从已提交位置重新拉取。


### BigData-002-018 | ★★★☆☆

Kafka 如何实现高吞吐？

**答案：**
顺序写磁盘、页缓存、零拷贝(sendfile)、批量发送、消息压缩、分区并行、稀疏索引。


### BigData-002-019 | ★★★☆☆

Spark 的 job、stage、task 分别是什么？stage 如何划分？

**答案：**
action触发job；DAG按宽依赖（shuffle）切分stage，窄依赖pipiline在一个stage内；stage内按分区数生成task（ShuffleMapTask/ResultTask）。


### BigData-002-020 | ★★★☆☆

Spark 为什么比 Hadoop MapReduce 快？

**答案：**
基于内存的DAG计算（中间结果不落盘）、进程复用（Executor常驻，免除频繁启停JVM）、DAG调度优化pipeline、缓存/广播变量。


### BigData-002-021 | ★★★☆☆

Spark 数据倾斜如何定位，有哪些解决方案？

**答案：**
定位：Web UI看个别task耗时/数据量远超均值、shuffle read异常大。方案：过滤异常key、加盐打散（两阶段聚合）、广播小表mapjoin、提高并行度、自定义分区器。


### BigData-002-022 | ★★★☆☆

reduceByKey 和 groupByKey 的区别？使用 reduceByKey 出现数据倾斜怎么办？

**答案：**
reduceByKey在map端预聚合（combine），减少shuffle数据；groupByKey不预聚合，shuffle传输全部数据。倾斜时对key加盐局部聚合再去盐全局聚合。


### BigData-002-023 | ★★★☆☆

Spark 的 cache 和 persist 的区别？它们是 transformation 算子还是 action 算子？

**答案：**
cache等价persist(MEMORY_ONLY)；persist可指定多种级别（内存/磁盘/序列化）。它们既不是transformation也不是action，是缓存控制操作，缓存实际发生在第一个action执行时。


### BigData-002-024 | ★★★☆☆

Spark RDD、DataFrame、DataSet 的区别是什么？有了 RDD 为什么还要 DataFrame 和 DataSet？

**答案：**
RDD是无schema的分布式对象集合，编译期类型安全但无优化；DataFrame带schema，可被Catalyst优化（谓词下推、列裁剪、Tungsten堆外内存）；DataSet结合两者（强类型+优化）。


### BigData-002-025 | ★★★☆☆

Flink 的组成（运行时架构组件）有哪些？

**答案：**
JobManager（集群Master、协调者，负责接收job）；TaskManager（实际干活的Worker）；Client（提交Flink程序的客户端）。


### BigData-002-026 | ★★★☆☆

Flink 和 Spark Streaming 的区别是什么？

**答案：**
①计算速度：Flink是真实时，Spark Streaming是微批次准实时；②架构：Spark Streaming运行角色是Driver/Executor，Flink是JobManager/TaskManager；③时间语义：Spark Streaming只支持处理时间，Flink支持处理/事件/注入时间并提供watermark处理迟到数据。


### BigData-002-027 | ★★★☆☆

Flink 的 watermark 用过吗？它是怎么工作的？

**答案：**
watermark是一种特殊的时间戳，作用是让事件时间推进慢一点、等迟到数据到齐再触发窗口计算；当watermark越过窗口结束时间时触发该窗口计算。


### BigData-002-028 | ★★★☆☆

讲一下 Flink Checkpoint 的 Chandy-Lamport 分布式快照流程。

**答案：**
JobManager启动时创建CheckpointCoordinator，周期性向所有source发送barrier；source收到barrier后暂停处理、将当前状态快照到持久化存储（如HDFS），报告Coordinator并向下游广播barrier后恢复处理；下游算子对齐barrier、快照、继续传播，直到sink，Coordinator收到全部报告则本轮快照成功，超时未齐则失败。


### BigData-002-029 | ★★★☆☆

Kafka 和 Flink 分别怎么实现 exactly once？

**答案：**
Kafka：acks=-1 + 幂等性（事务可实现跨分区原子写）；Flink：利用checkpoint（分布式快照 + 两阶段提交sink）保证精准一次。


### BigData-002-030 | ★★★☆☆

Flink 的窗口有哪几种？如何定义？有什么区别？

**答案：**
滚动（Tumble，无重叠）、滑动（Slide，有重叠）、会话（Session，按活跃间隙切分）、全局窗口；按时间或计数定义，时间可用处理时间/事件时间。


### BigData-002-031 | ★★★☆☆

Flink 的 Checkpoint 超时可能是什么原因？

**答案：**
常见：barrier对流经反压的算子传播慢、状态过大快照慢、对齐耗时、checkpoint间隔/超时设置不合理、外部存储（HDFS）慢。


### BigData-002-032 | ★★★☆☆

Flink 如何处理反压（backpressure）？

**答案：**
Flink内部通过credit-based流控在TaskManager间自然反压（下游来不及消费则停止拉取）；定位用Web UI反压面板/flame graph，解决靠增大并行度、优化慢算子、异步IO等。


### BigData-002-033 | ★★★☆☆

数据仓库为什么要分层？每层做什么？分层的好处是什么？

**答案：**
常见ODS（原始贴源）→DWD（明细，清洗）→DWS（轻度汇总）→ADS（应用）。好处：解耦、复用、清晰血缘、屏蔽底层变化、减少重复开发。


### BigData-002-034 | ★★★☆☆

维度建模和范式建模的区别？星型模型和雪花模型的区别及各自适用场景？

**答案：**
维度建模面向分析，事实表+维度表，以查询性能为先；范式建模面向事务/消除冗余（3NF）。星型模型维表直接连事实表（join少、冗余多），雪花模型维表再规范化分层（冗余少、join多）。


### BigData-002-035 | ★★★☆☆

增量表、全量表和拉链表分别是什么？

**答案：**
增量表存每日新增/变更；全量表存截止当日的全部最新数据；拉链表记录数据的历史变化（起止日期），支持任意时间切片查询且节省存储。


### BigData-002-036 | ★★★☆☆

从 ODS 层到 DW 层的 ETL，你都做了哪些工作？数据质量怎么保证、有哪些衡量指标？

**答案：**
清洗（去重、补全、格式统一、脏数据处理）、维度退化、缓慢变化维处理；质量保障：数据比对/稽核（主键唯一、空值率、波动监控）、DQC规则告警。指标：完整性、准确性、一致性、及时性。


### BigData-002-037 | ★★★☆☆

Flume 的 TailDir Source 为什么可以断点续传？

**答案：**
TailDir Source将每个文件已读取到的位置（offset）记录在JSON格式的position文件中，重启后从记录位置继续读取，实现断点续传；且可监控多组文件、轮询发现新文件。


### BigData-002-038 | ★★★★★

Flume 事务机制了解一下？put/take/commit/rollback 分别做什么？

**答案：**
Source→Channel用doPut/doCommit/doRollback；Sink←Channel用doTake/doCommit/doRollback，事务保证组件间消息传递的可靠性。


### BigData-002-039 | ★★★☆☆

Kafka 的消费者组和再平衡（rebalance）机制介绍一下。

**答案：**
同一group内消费者分摊分区，一个分区只被组内一个消费者消费；消费者加入/退出、分区数变化触发rebalance，由组协调器（老版ZK，新版broker端）主持重新分配。


### BigData-002-040 | ★★★☆☆

Spark Streaming 处理数据，如果队列里面的数据来得太快，处理太慢，数据在内存里堆积，该怎么处理？

**答案：**
通过Spark Streaming的backpressure（spark.streaming.backpressure.enabled）让最大消费速率随处理能力自适应；也可限流、增加并行度、提升batch interval，或Kafka Direct模式控制拉取速率。

