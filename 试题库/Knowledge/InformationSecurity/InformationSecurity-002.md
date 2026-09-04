### InformationSecurity-002-001 | ★★★★☆

什么是缓冲区溢出？如何防范缓冲区溢出攻击？

**答案：**
字节实习一面。如strcpy拷贝超长数据覆盖返回地址转而执行攻击代码；防范：栈不可执行(NX)、地址空间随机化(ASLR)、栈保护Canary、用带长度检查的strcpy_s等安全函数。


### InformationSecurity-002-002 | ★★★★★

HTTP为什么不安全？HTTPS是如何防范中间人攻击的？

**答案：**
HTTP明文传输可被窃听、篡改、冒充；HTTPS靠CA证书体系：浏览器用CA公钥验证证书签名确认服务器身份，再协商出会话密钥加密通信，中间人无私钥无法伪造。


### InformationSecurity-002-003 | ★★★★★

HTTPS握手过程说一下

**答案：**
TCP三次握手后：ClientHello(随机数+支持的套件) -> ServerHello(随机数+选定套件)+证书 -> 客户端验证证书并生成预主密钥用服务器公钥加密发送 -> 双方基于三个随机数生成会话密钥，后续对称加密通信（TLS1.3已简化为1-RTT）。


### InformationSecurity-002-004 | ★★★★☆

大量SYN包发送给服务端会发生什么事情？

**答案：**
SYN洪泛攻击会占满半连接队列导致正常连接无法建立（DoS）；防护：开启tcp_syncookies、增大backlog、缩短重传、防火墙限速。


### InformationSecurity-002-005 | ★★★★☆

什么是DDoS攻击？怎么防范？

**答案：**
分布式拒绝服务，攻击者控制大量肉鸡耗尽目标带宽/连接/计算资源；防范：流量清洗/高防IP、CDN分散、限流、SYN cookies、防火墙ACL、云厂商抗DDoS服务。


### InformationSecurity-002-006 | ★★★★☆

SQL注入问题是什么？

**答案：**
用户输入被拼接到SQL语句改变其语义（如' or 1=1 --）导致越权查询/删库；防范：参数化查询（预编译）、ORM、输入校验、最小权限、WAF。


### InformationSecurity-002-007 | ★★★★☆

CSRF攻击是什么？

**答案：**
跨站请求伪造：恶意网站借用用户浏览器里已登录的Cookie，诱导其向目标站点发请求冒名操作；防范：CSRF Token、SameSite Cookie、校验Referer/Origin、二次验证。


### InformationSecurity-002-008 | ★★★★☆

XSS攻击是什么？

**答案：**
跨站脚本：攻击者把恶意JS注入页面（存储型/反射型/DOM型），在受害者浏览器执行窃取Cookie等；防范：输出转义、CSP、HttpOnly Cookie、输入过滤。


### InformationSecurity-002-009 | ★★★★☆

JWT令牌和传统session方式有什么区别？JWT令牌都有哪些字段？

**答案：**
JWT无状态、签名自包含、服务端不用存会话（利于集群扩展），session存服务端可主动踢人；JWT由Header（算法）.Payload（claims如sub/exp）.Signature三段Base64组成。


### InformationSecurity-002-010 | ★★★★★

JWT为什么能解决集群部署下的会话问题？JWT的缺点是什么？如果泄露了怎么解决？

**答案：**
集群各节点只需密钥即可验签，无需共享Session存储；缺点是无法主动失效、Payload明文可见、续签麻烦；泄露后应设置短有效期+RefreshToken轮换、黑名单（配合Redis）并吊销旧token。

