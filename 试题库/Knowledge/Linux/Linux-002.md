### Linux-002-001 | ★★★★☆

如何进行CPU绑核？如何查看进程运行在哪个CPU上？为什么绑核能提高系统效率？

**答案：**
命令用taskset，编程用sched_setaffinity；ps -o pid,psr可查看进程所在核。绑核减少跨核迁移带来的缓存失效和NUMA远端内存访问，提高缓存命中率。


### Linux-002-002 | ★★★★☆

服务端正常启动了，但是客户端请求不到，有哪些原因？如何排查？

**答案：**
可能监听127.0.0.1而非0.0.0.0、防火墙/安全组拦截、端口不对、SELinux限制、DNS问题；排查：netstat/ss看监听、curl本机、telnet测端口连通、查防火墙规则。


### Linux-002-003 | ★★★★★

什么是IO多路复用？

**答案：**
单个线程通过select/poll/epoll同时监听多个fd的就绪事件，谁就绪处理谁，避免为每个连接建线程，是Reactor模式和高并发服务器（Nginx/Redis）的基础。


### Linux-002-004 | ★★★★☆

Linux中想在多个文件里匹配查找一个字符串用什么命令？

**答案：**
grep -r "str" dir/（递归查找），配合--include过滤文件类型；也可用find + xargs grep。


### Linux-002-005 | ★★★★☆

如何查看磁盘使用空间？如何一页一页地查看大文件内容？

**答案：**
df -h看文件系统磁盘占用，du -sh看目录大小；大文件用less（支持上下翻页/搜索）或more分页查看。


### Linux-002-006 | ★★★★☆

对一个文件的内容进行统计（行数、字节数、单词数）用什么指令？查看当前IP的网络连接用什么指令？

**答案：**
wc -l/-c/-w统计行数/字节数/单词数；netstat -anp或ss -tnp查看当前连接与监听端口。


### Linux-002-007 | ★★★★★

秒杀日志中记录了商品的下单情况，如何统计出秒杀失败的人数？

**答案：**
用文本三剑客组合：grep过滤失败关键字、awk按列聚合统计、sort+uniq去重计数，如 grep 'fail' access.log | awk '{print $uid}' | sort | uniq -c。


### Linux-002-008 | ★★★★★

项目上线之后想查看JVM的GC情况，在Linux中用什么命令？

**答案：**
美团真题。jstat -gcutil <pid> 1000查看各代使用率与GC次数耗时，配合jmap、jstack和GC日志分析。


### Linux-002-009 | ★★★★☆

pidstat命令能查看什么？如何查看进程自愿和非自愿的上下文切换次数？

**答案：**
被问1次。pidstat -w可查看进程自愿（voluntary）和非自愿（nonvoluntary）上下文切换次数。


### Linux-002-010 | ★★★★☆

缓存命中率怎么看？

**答案：**
面试真题。可用perf stat（cache-misses等事件）、cachestat，或针对应用缓存用监控统计命中/未命中比计算。


### Linux-002-011 | ★★★★☆

GDB条件断点怎么实现？

**答案：**
科大讯飞提前批一面。用 b 行号 if 条件，如 b 2 if i==1，当条件满足时才在该行停下。


### Linux-002-012 | ★★★★☆

GDB断点的实现原理是什么？

**答案：**
基于ptrace系统调用+INT 3指令+信号机制：GDB用ptrace把断点处代码替换为INT 3，子进程执行到断点触发SIGTRAP暂停，GDB恢复指令后继续执行。


### Linux-002-013 | ★★★★☆

用GDB如何调试多线程程序？

**答案：**
info threads查看线程、thread <id>切换线程、set scheduler-locking on锁定其他线程、thread apply all cmd让所有线程执行命令、break xx thread <id>对指定线程打断点。


### Linux-002-014 | ★★★★☆

如何调试段错误？

**答案：**
打开core dump，用gdb加载core文件，bt查看调用栈定位引发段错误的函数，frame切换栈帧看具体行。


### Linux-002-015 | ★★★★☆

Linux常见的目录结构是怎样的（FHS标准）？

**答案：**
被问1次。/bin基础命令、/sbinroot命令、/home用户主目录、/lib共享库、/usr/bin大部分可执行文件、/usr/local手动安装软件、/proc进程与内核信息等，由FHS（Filesystem Hierarchy Standard）规定。

