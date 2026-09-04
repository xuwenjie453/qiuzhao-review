### ComputerNetworks-002-001 | ★★★★★

TCP三次握手的过程是怎样的？

**答案：**
作者秋招被问5次。客户端发SYN进入SYN_SENT，服务端回SYN+ACK，客户端再回ACK，双方进入ESTABLISHED。


### ComputerNetworks-002-002 | ★★★★★

TCP四次挥手的过程是怎样的？

**答案：**
作者秋招被问5次。主动方发FIN、被动方回ACK，被动方数据发完后也发FIN，主动方回ACK并等待2MSL后关闭。


### ComputerNetworks-002-003 | ★★★★☆

TCP连接为什么不能两次握手？

**答案：**
被问3次。三次握手主要为了阻止历史连接初始化、避免资源浪费，同时帮助双方同步初始化序列号；两次握手下服务端收到旧SYN就会直接进入ESTABLISHED，无法阻止历史连接。


### ComputerNetworks-002-004 | ★★★★★

TCP为什么需要三次握手、四次挥手，用一句话来回答？

**答案：**
三次握手保证双方收发能力都得到确认并同步初始序列号；四次挥手是因为被动关闭方收到FIN后可能还有数据要发，ACK和FIN需分开发送。


### ComputerNetworks-002-005 | ★★★★☆

time_wait、close_wait状态过多分别是什么原因造成的？

**答案：**
time_wait过多通常是本端主动断开连接过多（大量短连接）；close_wait过多说明对端关闭后本端程序没有调用close，常为代码泄漏连接。


### ComputerNetworks-002-006 | ★★★★☆

TCP一方一直发送数据，另一方一直不读，会发生什么情况？

**答案：**
接收窗口逐渐减小为0（零窗口），发送方停止发送并周期性发送零窗口探测报文；若接收方持续不读，发送方最终可能因重传超时断开连接。


### ComputerNetworks-002-007 | ★★★★☆

TCP粘包是什么？有哪些解决方法？

**答案：**
TCP是字节流协议没有消息边界会产生粘包；解决：用特殊分隔符（如HTTP按行分隔请求头）、用Content-Length指明消息体长度。


### ComputerNetworks-002-008 | ★★★★☆

MSS与MTU是什么？它们的关系是什么？

**答案：**
MTU是链路层最大传输单元（一般1500字节），MSS是TCP单个报文段最大数据量，MTU=1500时MSS=1500-20(IP头)-20(TCP头)=1460字节。


### ComputerNetworks-002-009 | ★★★★☆

DNS查询用的什么协议？

**答案：**
域名解析场景下报文一般不超过512字节，通常使用UDP；区域传送等场景用TCP。


### ComputerNetworks-002-010 | ★★★★☆

DNS解析的流程是怎样的？

**答案：**
客户端先查本地DNS缓存/服务器，未命中则本地DNS依次向根域名服务器、顶级域名服务器、权威DNS服务器查询，最终返回真实IP。


### ComputerNetworks-002-011 | ★★★★☆

HTTP2相比HTTP1.1有什么改进？

**答案：**
HTTP/2引入二进制分帧、多路复用（一个TCP连接并发多个流）、头部压缩HPACK、服务器推送，解决了HTTP层的队头阻塞。


### ComputerNetworks-002-012 | ★★★★☆

HTTP GET和POST的区别是什么？

**答案：**
GET一般用于获取资源、参数在URL、可缓存可收藏；POST用于提交数据、参数在请求体、不缓存，语义上非幂等。


### ComputerNetworks-002-013 | ★★★★☆

键入网址到网页显示，期间发生了什么？

**答案：**
DNS解析得到IP -> TCP三次握手建立连接（封装端口/SYN/序列号）-> 生成IP数据包、查路由表 -> ARP查询下一跳MAC -> 封帧发送 -> 服务端按MAC/IP/TCP解封，回SYN+ACK完成握手 -> 在TCP上发送HTTP报文，浏览器渲染。


### ComputerNetworks-002-014 | ★★★★☆

TCP/IP四层模型是什么？每一层的作用是什么？为什么网络要分层？

**答案：**
应用层（HTTP/DNS等具体业务）、传输层（TCP/UDP端到端通信）、网络层（IP寻址路由）、网络接口层（相邻节点传输）；分层让各层独立演进、复用、便于排障。


### ComputerNetworks-002-015 | ★★★★☆

HTTP常见的状态码有哪些？

**答案：**
2xx成功（200/204/206）、3xx重定向（301/302/304）、4xx客户端错误（400/401/403/404）、5xx服务端错误（500/502/503/504）。


### ComputerNetworks-002-016 | ★★★★★

HTTP和HTTPS有什么区别？

**答案：**
HTTPS=HTTP+TLS：端口443 vs 80，HTTPS对报文加密传输、校验完整性、通过证书做身份认证，握手阶段多了TLS协商过程。


### ComputerNetworks-002-017 | ★★★★☆

HTTP/1.0和HTTP/1.1有什么区别？

**答案：**
1.1支持长连接（默认keep-alive）、管道化、更多的缓存控制字段、Host头（支持虚拟主机）、断点续传（Range）。


### ComputerNetworks-002-018 | ★★★★☆

HTTP/1.1和HTTP/2.0有什么区别？

**答案：**
HTTP/2采用二进制分帧、多路复用（并发流不再队头阻塞于HTTP层）、HPACK头部压缩、服务器推送，废弃了1.1的文本协议。


### ComputerNetworks-002-019 | ★★★★☆

HTTP/2.0和HTTP/3.0有什么区别？

**答案：**
HTTP/3把传输层从TCP换成基于UDP的QUIC，彻底解决TCP层队头阻塞，且握手更快（0/1-RTT）、连接迁移。


### ComputerNetworks-002-020 | ★★★★☆

HTTP/1.1和HTTP/2.0的队头阻塞有什么不同？

**答案：**
1.1是HTTP层队头阻塞（一个连接同时只能处理一个请求，管道化也需按序返回）；2.0解决了HTTP层（多路复用），但TCP层丢包会阻塞所有流，仍是TCP队头阻塞。


### ComputerNetworks-002-021 | ★★★★☆

HTTP是不保存状态的协议，如何保存用户状态？

**答案：**
用Cookie（客户端存）和Session（服务端存，靠Cookie里的SessionID关联）保存状态，也可用Token（如JWT）。


### ComputerNetworks-002-022 | ★★★★☆

Cookie和Session有什么区别？

**答案：**
Cookie存在客户端、容量小、可被篡改；Session存在服务端、安全性高、依赖Cookie中的SessionID识别用户，分布式下需共享Session。


### ComputerNetworks-002-023 | ★★★★☆

什么是WebSocket？WebSocket和HTTP有什么区别？

**答案：**
WebSocket通过HTTP Upgrade握手升级为全双工长连接，服务端可主动推送；HTTP是请求-响应模式，客户端发起、单向。


### ComputerNetworks-002-024 | ★★★★☆

TCP与UDP的区别是什么？什么时候选择TCP，什么时候选UDP？

**答案：**
TCP面向连接、可靠有序、流量/拥塞控制、字节流、首部20字节；UDP无连接、不可靠、报文-oriented、开销小实时性好。要可靠传输选TCP，追求实时性/广播（视频、DNS、游戏）选UDP。


### ComputerNetworks-002-025 | ★★★★☆

HTTP基于TCP还是UDP？你知道哪些基于TCP/UDP的协议？

**答案：**
HTTP/1.1与HTTP/2基于TCP，HTTP/3基于UDP上的QUIC；基于TCP：HTTP/FTP/SSH/SMTP；基于UDP：DNS、DHCP、SNMP、QUIC。


### ComputerNetworks-002-026 | ★★★★★

TCP三次握手中，第2次握手传回了ACK，为什么还要传回SYN？

**答案：**
ACK是应答客户端的SYN，SYN是服务端向客户端发起并同步自己的初始序列号，两个动作目的不同无法合并。


### ComputerNetworks-002-027 | ★★★★★

四次挥手中为什么不能把服务器发送的ACK和FIN合并起来，变成三次挥手？

**答案：**
收到FIN时被动方可能还有数据未发完，ACK先回，等数据发完再发FIN；若此时恰好无数据可发（延后机制）就可能合并为三次，但通常不行。


### ComputerNetworks-002-028 | ★★★★★

为什么第四次挥手客户端需要等待2*MSL（报文段最长寿命）时间后才进入CLOSED状态？

**答案：**
一是保证最后的ACK能到达对端（丢失则对端重传FIN可再应答），二是让本连接的旧报文在网络中消亡，避免污染新连接。


### ComputerNetworks-002-029 | ★★★★☆

TCP如何保证传输的可靠性？

**答案：**
序列号+确认应答、超时重传/快速重传、校验和、滑动窗口流量控制、拥塞控制（慢启动、拥塞避免、快恢复）。


### ComputerNetworks-002-030 | ★★★★☆

什么是MAC地址？ARP协议解决了什么问题，工作原理是什么？

**答案：**
MAC地址是网卡在链路层的物理地址；ARP解决同一局域网内IP地址到MAC地址的映射，通过广播ARP请求、目标主机单播应答实现，结果缓存于ARP表。


### ComputerNetworks-002-031 | ★★★★☆

HTTP返回状态301和302分别是什么？

**答案：**
301是永久重定向（浏览器/搜索引擎会缓存新地址），302是临时重定向（仍请求原地址）。


### ComputerNetworks-002-032 | ★★★★☆

http 502和504的区别是什么？

**答案：**
502 Bad Gateway是网关收到了后端无效响应（后端挂了/拒绝），504 Gateway Timeout是网关等待后端响应超时；常出现在Nginx反代后端异常时。


### ComputerNetworks-002-033 | ★★★★☆

如果客户端禁用了Cookie，Session还能用吗？

**答案：**
可以，把SessionID通过URL重写（URL参数）传递，但存在泄露风险；现代做法改用URL参数/LocalStorage携带token。


### ComputerNetworks-002-034 | ★★★★☆

token、session、cookie的区别是什么？

**答案：**
cookie是浏览器存储并随请求携带的机制；session把状态存服务端、靠cookie里的SessionID识别；token（如JWT）是自包含凭证存客户端，服务端无状态校验签名即可。


### ComputerNetworks-002-035 | ★★★★☆

为什么有了HTTP协议还要用RPC？

**答案：**
RPC面向服务间调用，可定制高效序列化协议（protobuf）、长连接多路复用、IDL强类型契约，性能与工程效率优于通用文本协议HTTP/1.1（gRPC基于HTTP/2并吸收两者优点）。


### ComputerNetworks-002-036 | ★★★★★

TCP三次握手中，客户端第三次发送的确认包丢失了会发生什么？

**答案：**
服务端停留/重试SYN_RCVD并重发SYN+ACK；若客户端此时发数据，数据包自带ACK可使服务端直接进入ESTABLISHED；若最终收不到确认，服务端释放半连接。


### ComputerNetworks-002-037 | ★★★★★

三次握手和accept是什么关系？accept做了哪些事情？

**答案：**
三次握手由内核协议栈在监听socket上自动完成（放入全连接队列），accept只是从全连接队列取出已完成的连接并创建已连接socket用于读写，本身不参与握手。


### ComputerNetworks-002-038 | ★★★★★

TCP四次挥手中，第三次挥手（FIN）一直没发，会发生什么？

**答案：**
被动关闭方进入CLOSE_WAIT可继续发数据；主动关闭方停在FIN_WAIT_2，若开启keepalive且超时（tcp_fin_timeout）会直接关闭连接。


### ComputerNetworks-002-039 | ★★★★☆

怎么用UDP实现HTTP？

**答案：**
需在应用层实现可靠传输：序列号确认、重传、流量/拥塞控制，QUIC正是这样在UDP上承载HTTP/3，且支持0-RTT与连接迁移。


### ComputerNetworks-002-040 | ★★★★☆

网页打开非常慢一直转圈，要定位问题需要从哪些角度？

**答案：**
分层排查：DNS解析慢？TCP连接慢？TLS握手慢？服务端处理慢（后端日志/链路追踪）？还是传输体积大/静态资源慢？可用浏览器Network面板、curl分段计时。


### ComputerNetworks-002-041 | ★★★★☆

服务器ping不通但是HTTP能请求成功，会出现这种情况吗？什么原因造成的？

**答案：**
会。ping用ICMP，HTTP用TCP/80/443，防火墙可能只禁ICMP放行TCP端口，故ping不通但HTTP正常。


### ComputerNetworks-002-042 | ★★★★☆

Nginx有哪些负载均衡策略（算法）？

**答案：**
字节/顺丰/大华/跟谁学/有赞真题。轮询（默认）、权重weight、ip_hash（会话粘滞）、最少连接least_conn、一致性哈希，第三方还有fair（按响应速度）等。


### ComputerNetworks-002-043 | ★★★★☆

TCP拥塞控制慢启动算法的门阈（ssthresh）初始是多少？

**答案：**
初始值为64KB（65535字节）；发生一次数据丢失（超时）时，ssthresh变为当时拥塞窗口的一半。


### ComputerNetworks-002-044 | ★★★★☆

TCP传输时如果遇到传输的数据不完整该怎么办？比如200k的数据只接收了100k。

**答案：**
TCP本身通过序列号与确认重传保证可靠有序传输，应用层若读到不完整数据应继续读取直到收满期望长度（配合Content-Length或自定义长度字段）。


### ComputerNetworks-002-045 | ★★★★☆

应用层有哪些常见的协议？

**答案：**
HTTP/HTTPS、FTP、SMTP/POP3、DNS、SSH、Telnet、DHCP等。


### ComputerNetworks-002-046 | ★★★★☆

从输入URL到页面展示到底发生了什么？打开一个网页整个过程会使用哪些协议？

**答案：**
DNS(UDP/TCP 53)->TCP握手->若HTTPS则TLS握手->HTTP请求响应->浏览器解析渲染；涉及DNS、TCP、IP、ARP、TLS/HTTP等协议。


### ComputerNetworks-002-047 | ★★★★☆

URI和URL的区别是什么？

**答案：**
URI是统一资源标识符（标识），URL是URI的子集，不仅标识还给出定位方式（协议+主机+路径）。


### ComputerNetworks-002-048 | ★★★★☆

WebSocket与短轮询、长轮询的区别是什么？SSE与WebSocket有什么区别？

**答案：**
短轮询客户端定时发请求、长轮询请求挂起直到有数据返回、WebSocket是持久双向连接；SSE只能服务端单向推送且基于HTTP，WebSocket全双工。


### ComputerNetworks-002-049 | ★★★★☆

PING命令的作用是什么？它的工作原理是什么？

**答案：**
检测主机间连通性与往返时延；基于ICMP协议（Echo Request/Reply），不使用TCP/UDP端口。


### ComputerNetworks-002-050 | ★★★★☆

DNS服务器有哪些？根服务器有多少个？

**答案：**
分根域名服务器、顶级域名服务器、权威域名服务器和本地DNS；根服务器全球共13个IP（通过任播扩展为大量实例）。


### ComputerNetworks-002-051 | ★★★★☆

DNS劫持了解吗？如何应对？

**答案：**
DNS劫持是查询结果被恶意篡改指向错误IP；可用DoH/DoT加密DNS、改用可信公共DNS（如114/8.8.8.8）、HTTPDNS等方式应对。


### ComputerNetworks-002-052 | ★★★★☆

如果第二次挥手时服务器的ACK没有送达客户端，会怎样？

**答案：**
客户端超时未收到ACK会重传FIN报文，直到收到ACK或达到最大重传次数后断开。


### ComputerNetworks-002-053 | ★★★★☆

什么是IP地址？IP寻址如何工作？IPv4和IPv6有什么区别？

**答案：**
IP地址是网络层逻辑地址，通过子网划分+路由表逐跳转发寻址；IPv4是32位地址已耗尽，IPv6是128位、地址空间巨大、首部简化、原生支持IPSec与自动配置。


### ComputerNetworks-002-054 | ★★★★☆

NAT的作用是什么？如何获取客户端真实IP？

**答案：**
NAT把内网私有地址映射为公网地址，缓解IPv4地址不足并提供一定隔离；服务端可通过X-Forwarded-For/Proxy-Protocol等头部获取经过代理/负载均衡的客户端真实IP。

