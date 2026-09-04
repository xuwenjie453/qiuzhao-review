### ComputerNetworks-004-001 | ★★★★★

TLS 1.3 相比 TLS 1.2 有哪些改进？0-RTT 有什么风险？
SRC2: https://www.xiaolincoding.com/network/3_tcp/tcp_tls.html

**答案：**
握手从 2-RTT 减到 1-RTT，会话复用 PSK 可 0-RTT；废除 RSA 密钥交换、CBC 等不安全算法，只保留 AEAD 与 (EC)DHE 前向安全。0-RTT 数据无前向安全且易被重放攻击，需服务端只允许幂等请求。


### ComputerNetworks-004-002 | ★★★★★

QUIC 是如何解决 TCP 队头阻塞问题的？HTTP/2 的队头阻塞和 HTTP/1.1 有什么不同？
SRC2: https://javaguide.cn/cs-basics/network/other-network-questions.html

**答案：**
QUIC 在单连接上复用多个互不阻塞的 Stream，某 Stream 丢包只影响自身，接收缓冲按 Stream 独立管理；HTTP/1.1 阻塞在 TCP 连接层（并发需多连接），HTTP/2 多路复用后所有 Stream 共用一个 TCP 流，一个包丢失仍阻塞全部 Stream。


### ComputerNetworks-004-003 | ★★★★★

QUIC 是如何做连接迁移的？拥塞控制上有什么改进？

**答案：**
QUIC 用 Connection ID 标识连接而非四元组，WiFi 切 4G 时 IP/端口变化连接不中断；拥塞控制默认仍类 CUBIC 但在应用层可插拔（BBR 等），单调递增的 Packet Number 精确测量 RTT 避免重传歧义。


### ComputerNetworks-004-004 | ★★★★☆

TCP 拥塞控制介绍一下？拥塞控制的具体逻辑（慢启动、拥塞避免、快重传、快恢复）？
SRC2: https://www.xiaolincoding.com/backend_interview/internet_medium/haoweilai.html

**答案：**
慢启动 cwnd 指数增长到 ssthresh，超阈值后线性加性增大；超时 RTO 视为拥塞，ssthresh=cwnd/2、cwnd 重置 1 重新慢启动；收到 3 个重复 ACK 触发快重传+快恢复（cwnd 减半而非归 1）。若接收窗口缩到 0，发送方靠持续计时器定时发零窗口探测报文恢复。


### ComputerNetworks-004-005 | ★★★★★

零拷贝是什么？Redis、Nginx、Netty 是依赖什么做到高性能的？

**答案：**
传统 read+write 4 次拷贝 4 次上下文切换；mmap+write 减少 CPU 拷贝，sendfile 一次系统调用完成文件到 socket 传输，配合 DMA gather copy 只需 2 次 DMA 拷贝、0 次 CPU 拷贝。它们共同依赖 epoll 事件驱动 + 零拷贝 + 内存池/进程内单线程避免切换。


### ComputerNetworks-004-006 | ★★★★☆

RocketMQ 如何保证高性能读写？

**答案：**
CommitLog 单文件顺序写、消息经 ConsumeQueue 索引读取、基于 mmap 的内存映射文件与页缓存读写、刷盘可选同步/异步，消费传输走零拷贝。


### ComputerNetworks-004-007 | ★★★★☆

TCP 有分段，IP 层有分片，这两个有什么区别？现在用的是哪个？

**答案：**
MSS 分段在传输层按 MSS 切，每个段独立有序可重传；IP 分片在网按 MTU 切，任一分片丢失整包作废且重组开销大；现代网络通过路径 MTU 发现让 TCP 按 MSS 分段，尽量避免 IP 分片。


### ComputerNetworks-004-008 | ★★★★☆

TIME_WAIT 会等待 2MSL 才释放，了解吗？服务端出现大量 TIME_WAIT 有哪些原因？
SRC2: https://www.xiaolincoding.com/interview/network.html

**答案：**
2MSL 确保最后的 ACK 可达并让旧报文自然消亡防止污染新连接；服务端大量 TIME_WAIT 说明服务端主动断开（短连接、HTTP 未开 keep-alive、连接池配置问题），可开端口重用/长连接优化。

