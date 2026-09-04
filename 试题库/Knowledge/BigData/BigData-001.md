### BigData-001-001 | ★★★★☆

Hadoop 生态的基本组成？HDFS 的架构特点？

**答案：**
Hadoop 是分布式存储+计算的基础框架，核心两件：HDFS（分布式文件系统）+ MapReduce（分布式计算模型），外围 YARN 资源调度。HDFS 架构：主从式——NameNode（元数据管理：目录树、块位置，内存承载）+ 多个 DataNode（实际存储数据块）；文件切分为固定大小块（默认 128MB），每块多副本（默认 3 份）分散在不同机架节点，实现容错与本地读取。设计取向：**一次写入多次读取**（不支持随机修改）、大文件友好、移动计算而非移动数据（把计算任务调度到数据所在节点）。

**解析：**
NameNode 高可用：元数据持久化（fsimage+editlog）+ 备用 NameNode/JournalNode；小文件问题是经典缺陷（每个文件/块占 NameNode 内存，海量小文件打爆元数据，解法合并小文件/SequenceFile/HAR）。DataNode 心跳与块汇报、坏块副本自愈。


### BigData-001-002 | ★★★★☆

MapReduce 的计算模型？

**答案：**
MapReduce 把分布式计算抽象为两个阶段：**Map**——对每条输入独立处理，输出 (key, value) 中间结果；**Shuffle**——按 key 分区、排序、归组，把相同 key 的数据汇到同一 Reducer（这是网络开销与复杂度的大头）；**Reduce**——对每个 key 的值集合做汇总。经典词频统计：Map 输出 (word, 1)，Reduce 对同 word 求和。价值在于"分而治之+数据汇聚"的通用范式；局限：中间结果落盘、Shuffle 代价高，多轮计算串成作业链效率低——这正是 Spark 用内存 RDD 替代的动机。


### BigData-001-003 | ★★★★☆

Spark 为什么比 MapReduce 快？

**答案：**
核心差异一句话：MapReduce 每个作业的中间结果必须写 HDFS 落盘，Spark 的 RDD（弹性分布式数据集）中间结果留在内存、算子间以血统（lineage）而非物化数据衔接。三个关键词：①**内存计算**——迭代式任务（机器学习）省去反复读写盘；②**惰性求值与 DAG**—— transformations 只记录依赖，action 触发整体 DAG 优化后一次调度，避免 MapReduce 的作业链开销；③**丰富的算子**——上百个转换/动作算子替代裸 Map/Reduce 编程。Spark SQL/DataFrame 提供声明式接口并有 Catalyst 优化器。

**解析：**
RDD 容错靠 lineage 重算（宽依赖需重算父分区，可 checkpoint 截断血统）；宽窄依赖区分（是否需要 shuffle）决定 stage 划分。内存不够时 Spark 也会溢写磁盘——"更快"不是绝对，是迭代/多轮场景的优势显著。


### BigData-001-004 | ★★★★☆

Flink 和 Spark 的区别？批流一体怎么理解？

**答案：**
核心分歧在**流与批谁是第一公民**：Spark 以批为骨架，流处理（Structured Streaming）用微批（micro-batch，小时间片当小批处理）模拟流，延迟秒级；Flink 以流为骨架，批是有界流，真·逐条/事件驱动，延迟毫秒级，且提供**事件时间语义**（EventTime + Watermark 处理乱序数据）、**状态管理**与 **Checkpoint（Chandy-Lambara 分布式快照）实现 Exactly-Once 语义**。选型：离线数仓/大规模 ETL 用 Spark；实时风控、实时大屏、CEP 复杂事件用 Flink；"批流一体"即同一套 SQL/代码同时跑有界流（历史批）与无界流（实时），保证口径一致（Lambda 架构批流两套代码的痛点）。


### BigData-001-005 | ★★★★☆

数据仓库的基本概念？OLTP 和 OLAP 的区别？

**答案：**
OLTP（联机事务处理）：业务系统的高并发短事务（下单、扣款），行存、强事务、毫秒级单条操作——MySQL 是代表。OLAP（联机分析处理）：分析查询（聚合、多维统计、全表扫描），列存、弱事务、秒级大范围查询——Hive/ClickHouse/Doris 是代表。数据仓库分层：ODS（原始贴源层）→ DWD（明细层，清洗规范化）→ DWS（汇总层）→ ADS（应用层报表）；建模方法范式建模（3NF，一致性优先）与维度建模（星型/雪花模型，事实表+维度表，分析友好）。数仓核心动作是"分主题、分层、缓慢变化维处理"，为 BI 与 AI 提供干净口径的数据。


### BigData-001-006 | ★★★★☆

Kafka 在大数据体系中的位置？

**答案：**
Kafka 是分布式日志流平台，在大数据体系中担任"数据的入口总线"：上游业务库（CDC/Canal）、埋点日志、设备数据统一汇入 Kafka，下游 Spark/Flink 消费做实时或离线计算，结果入数仓/OLAP/服务库。它作为总线的三大保障：高吞吐（顺序写+零拷贝+批量，K-MQ-006）、可重放（按 offset/时间戳重读）、削峰解耦（生产消费速率独立）。与 Hadoop 的关系：Kafka 补的是"实时数据管道"，历史存储仍在数仓/HDFS——两者互补不是替代。


### BigData-001-007 | ★★★☆☆

HDFS 架构组件

HDFS 中负责管理文件系统元数据（目录树、数据块位置）的节点是：

A. DataNode
B. NameNode
C. JobTracker
D. Secondary NameNode

**答案：** B

**解析：**
- A：错误。DataNode 负责实际数据块的存储与读写服务。
- B：正确。NameNode 管理元数据并常驻内存，是 HDFS 的"大脑"。
- C：错误。JobTracker 是 MapReduce v1 的作业调度组件，不属于 HDFS。
- D：错误。Secondary NameNode 的职责是合并 fsimage 与 editlog，不是热备节点（常见误解）。

NameNode 元数据、DataNode 数据、Secondary NameNode 做检查点不做 HA。


### BigData-001-008 | ★★★☆☆

HDFS 设计取向

下列符合 HDFS 设计目标的有：

A. 一次写入、多次读取
B. 存储超大文件（GB~TB 级）
C. 支持低延迟的随机记录修改
D. 通过多副本容错，将计算调度到数据所在节点

**答案：** A、B、D

**解析：**
- A：正确。顺序写+追加语义，不做随机修改。
- B：正确。大文件按 128MB 块切分正是其优化点。
- C：错误。随机修改/低延迟访问不是 HDFS 的目标，应使用数据库/对象存储。
- D：正确。多副本容错+"移动计算到数据"是其吞吐来源。

HDFS = 高吞吐、大文件、多副本、不可随机修改。


### BigData-001-009 | ★★★☆☆

MapReduce Shuffle

MapReduce 作业中，Shuffle 阶段的主要工作是：

A. 将 Map 输出按 key 分区、排序并传输给对应的 Reduce 端
B. 将输入文件切分为多个 split
C. 执行用户编写的 reduce() 业务逻辑
D. 检查 HDFS 数据块健康状况

**答案：** A

**解析：**
- A：正确。Shuffle 覆盖 map 端溢写分区到 reduce 端归并排序的全过程，是性能开销大头。
- B：错误。InputSplit 是作业输入阶段的工作。
- C：错误。reduce() 逻辑在 Reduce 阶段执行，不属于 Shuffle。
- D：错误。块健康由 DataNode/NameNode 协作维护。

流程：input split → map → shuffle（分区/排序/传输）→ reduce → output。


### BigData-001-010 | ★★★☆☆

Spark RDD 特性

关于 Spark RDD，下列说法正确的有：

A. transformation（如 map/filter）是惰性的，遇到 action 才触发计算
B. RDD 通过血统（lineage）信息实现容错，失败分区可由父 RDD 重算
C. 中间结果必须全部写入 HDFS 才能进行下一阶段计算
D. 宽依赖（如 reduceByKey）会引入 shuffle 并切分 stage

**答案：** A、B、D

**解析：**
- A：正确。惰性求值+DAG 整体优化是 Spark 的执行模型。
- B：正确。血统重算是容错机制，可配合 checkpoint 截断长血统。
- C：错误。中间结果默认在内存（不足时溢写盘），"必须写 HDFS"恰是 MapReduce 的行为。
- D：正确。stage 边界即宽依赖处。

RDD：惰性求值、血统容错、内存迭代、宽窄依赖。


### BigData-001-011 | ★★★☆☆

Flink 时间语义

流计算中，按"数据中携带的业务发生时间"统计窗口结果，使用的时间语义是：

A. 处理时间（Processing Time）
B. 事件时间（Event Time）
C. 摄入时间（Ingestion Time）
D. 系统当前时间

**答案：** B

**解析：**
- A：错误。处理时间是数据到达算子的机器时钟时间，受延迟/乱序影响，结果不稳定。
- B：正确。事件时间取数据自身的时间戳，配合 Watermark 处理乱序，保证结果可重现。
- C：错误。摄入时间是进入系统的时间，介于两者之间，仍受传输延迟影响。
- D：错误。即处理时间的另一说法。

事件时间+Watermark 是乱序流上得到确定性结果的机制。


### BigData-001-012 | ★★★★☆

OLTP 与 OLAP

下列关于 OLTP 与 OLAP 的对比，错误的是：

A. OLTP 面向高并发短事务，OLAP 面向复杂分析查询
B. OLTP 通常采用行存储，OLAP 分析场景常采用列存储
C. OLAP 系统强调强事务支持与高频单条更新
D. 企业通常将分析查询从 OLTP 业务库剥离到数仓/OLAP 引擎

**答案：** C

**解析：**
- A：正确（不选）。这是二者的基本定位。
- B：正确（不选）。列存利于聚合分析（只读所需列、压缩率高）。
- C：错误（选它）。强事务+高频单条更新是 OLTP 的特征；OLAP 弱事务、批量导入为主。
- D：正确（不选）。隔离分析负载是数仓存在的基本理由。

OLTP：行存/事务/毫秒单条；OLAP：列存/聚合/秒级大查询。


### BigData-001-013 | ★★★☆☆

数仓分层

数据仓库中，对 ODS 层贴源数据进行清洗、去重、规范化后的明细数据层通常称为：

A. ADS 层
B. DWD 层
C. DWS 层
D. DIM 层

**答案：** B

**解析：**
- A：错误。ADS 是面向应用的聚合结果层。
- B：正确。DWD（Data Warehouse Detail）是清洗后的明细层。
- C：错误。DWS 是轻度汇总层（按主题预聚合）。
- D：错误。DIM 是维度层，存放维度表。

分层：ODS（贴源）→ DWD（明细）→ DWS（汇总）→ ADS（应用），逐层解耦与复用。


### BigData-001-014 | ★★★☆☆

Kafka 在数仓实时链路的角色

企业构建实时数仓时，业务数据库变更通常通过什么方式进入数据管道？

A. 直接让 Flink 每秒全表轮询业务库
B. 通过 CDC 工具（如 Canal/Debezium）解析 binlog 发送到 Kafka，再由流计算消费
C. 要求业务方每天导出 Excel 上传
D. 复制数据库文件到计算集群

**答案：** B

**解析：**
- A：错误。高频全表轮询压垮业务库且延迟与开销都不合理。
- B：正确。CDC 把行级变更转为事件流，削峰、解耦、可重放，是实时数仓标准入口。
- C：错误。人工导出不可持续且无实时性。
- D：错误。直接拷贝物理文件绕过事务一致性，且对运行中的库不安全。

CDC（binlog→事件流）+ Kafka + Flink 是实时数仓的标准三段式。


### BigData-001-015 | ★★★☆☆

MapReduce 与 Spark 定位

"迭代式机器学习任务显著快于 MapReduce"是哪个系统的宣传点？

A. HDFS
B. Spark
C. Hive
D. YARN

**答案：** B

**解析：**
Spark 内存计算+RDD 血统，迭代场景免落盘；A 存储；C 是 SQL on MR；D 资源调度。

MapReduce 中间结果落盘、Spark 留内存。


### BigData-001-016 | ★★★☆☆

Flink Exactly-Once 条件

Flink 端到端 Exactly-Once 语义依赖：

A. Checkpoint 分布式快照（Chandy-Lamport 思想）
B. Source 可重放（如 Kafka offset 回拨）
C. Sink 事务性/幂等提交（两阶段提交或幂等写）
D. 增大并行度

**答案：** A、B、C

**解析：**
三条件构成端到端精确一次；D 只影响吞吐不影响语义。

Exactly-Once=快照+可重放+事务/幂等 sink。


### BigData-001-017 | ★★☆☆☆

维度建模事实表

星型模型中存放"度量/事件"（如一笔交易金额）的表是：

A. 维度表
B. 事实表
C. 临时表
D. 索引表

**答案：** B

**解析：**
事实表=度量+外键指向维度；维度表=描述性属性（日期、商品）；C/D 无关。

事实表大而窄、维度表小而宽。


### BigData-001-018 | ★★☆☆☆

OLAP 引擎选型

需要"亿级数据、亚秒级多维聚合分析、高并发报表"的场景，最合适的引擎类型是：

A. 行存 OLTP 数据库（MySQL）
B. 列存 OLAP 引擎（ClickHouse/Doris 类）
C. 文件系统
D. 消息队列

**答案：** B

**解析：**
列存+预聚合是 OLAP 引擎的主场；A 做重分析会拖垮且慢；C 无查询能力；D 是传输组件。

OLTP 行存事务、OLAP 列存分析，选型第一分叉。

