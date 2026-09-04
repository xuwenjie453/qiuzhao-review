### Linux-001-001 | ★★★★★

线上问题排查你会用哪些 Linux 命令？

**答案：**
按排查对象组织：CPU——top（整体+load）、top -Hp（线程）、pidstat -u；内存——free -h（区分 buff/cache）、ps aux --sort=-rss、vmstat（si/so 换页）；磁盘——df -h（空间）、iostat -x（延迟）、du 找大文件；网络——ss/netstat（连接状态分布，CLOSE_WAIT/TIME_WAIT）、tcpdump 抓包、curl 测链路；日志——grep -C 上下文、tail -f、awk 统计（如按状态码聚合）、less 定位大文件；进程——jstack/jmap/jstat（Java 专用，K-JVM-008）。答题技巧：给出"现象→命令→判读"的三段式，例如"接口超时→ss -s 看连接堆积→发现 CLOSE_WAIT 暴涨→定位未关闭连接的代码"。


### Linux-001-002 | ★★★☆☆

chmod 755 和 644 分别是什么意思？

**答案：**
三位数字依次是属主/属组/其他用户的权限，每位是 r(4)+w(2)+x(1) 之和：755=rwxr-xr-x（属主全权，其他只读执行），常用于目录与可执行程序；644=rw-r--r--（属主读写，其他只读），常用于普通文件与配置。补充深度：目录的 x 权限是"进入/穿越"目录而非执行内容；SUID/SGID/粘滞位（passwd 改密码、/tmp 目录）是第四位特殊权限；umask 决定新建文件默认权限（022 → 文件 644、目录 755）。安全取向：最小权限原则，应用运行账号不使用 root，配置文件 600。


### Linux-001-003 | ★★☆☆☆

软链接和硬链接的区别？

**答案：**
硬链接是同一 inode 的多个目录项（ln source target）：删除任一名字文件内容仍在（引用计数减到 0 才释放），不能跨文件系统、不能对目录；软链接是独立文件存目标路径（ln -s）：可跨盘、可指目录，目标删除后成悬空链接。判读技巧：ls -i 看 inode 相同即硬链接。实践映射：版本切换（current -> releases/v12）用软链接；防误删共享内容（如备份池去重）用硬链接。


### Linux-001-004 | ★★★★☆

文件权限数字

`chmod 640 file` 后，file 的权限是：

A. 属主读写、属组读、其他无权限
B. 属主读写执行、属组读、其他无
C. 属主读、属组读写、其他读
D. 所有人读写

**答案：** A

**解析：**
6=rw-、4=r--、0=---；B 是 740；C 是 464（非法顺序）；D 是 666。

r=4 w=2 x=1 按位求和。


### Linux-001-005 | ★★★☆☆

常用命令组合

统计 access.log 中出现次数最多的前 10 个 IP，正确的管道是：

A. `awk '{print $1}' access.log | sort | uniq -c | sort -rn | head`
B. `head access.log | sort -r`
C. `grep IP access.log | wc`
D. `cat access.log | uniq | head -10`

**答案：** A

**解析：**
取第一列→排序（uniq 前必须 sort）→计数→按次数逆排→取前 10；B/C/D 语义不符。

uniq 只合并相邻重复，必须先 sort。


### Linux-001-006 | ★★★☆☆

查看端口占用

查看 8080 端口被哪个进程占用的命令是：

A. `lsof -i:8080` 或 `ss -ltnp | grep 8080`
B. `ps -ef | grep 8080`
C. `netstat -s`
D. `df -h`

**答案：** A

**解析：**
A 直接给出监听进程；B 只能匹配命令行含 8080 的进程，不可靠；C 是协议统计；D 是磁盘。

ss 替代 netstat（更快）；-p 显示进程。


### Linux-001-007 | ★★★☆☆

CPU 与负载判读

8 核机器 top 显示 load average 7.5、%us 90%，说明：

A. 系统空闲
B. CPU 密集已接近饱和，需定位高 CPU 进程（top -Hp/火焰图）
C. 磁盘 IO 瓶颈
D. 内存泄漏

**答案：** B

**解析：**
load≈核数且 us 高=CPU 饱和；A 相反；C 的特征是 wa 高/D 状态；D 的特征是内存持续增长/OOM。

load≈核数为满负荷线；us/sy/wa/si 四分项定性。

