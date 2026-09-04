### Docker-001-001 | ★★★★☆

Docker 的底层原理？容器和虚拟机的区别？

**答案：**
容器是"被隔离与限制的进程"，三件套：①Namespace——视图隔离（PID/网络/挂载/UTS/IPC/User 六大空间），让容器看到独立的进程树与网络栈；②Cgroup——资源限额（CPU、内存、IO、pids），OOMKilled 即内存 cgroup 触发；③UnionFS（overlay2）——镜像分层只读叠加+容器可写层，镜像共享基础层省存储、构建缓存加速。与虚拟机区别：VM 虚拟整套硬件+客户机内核，隔离强但重（GB 级、分钟级启动）；容器共享宿主内核，秒级启动、MB 级开销，隔离性弱于 VM（同内核逃逸风险、/proc 信息共享等）。


### Docker-001-002 | ★★★☆☆

Dockerfile 的最佳实践？镜像分层机制如何利用？

**答案：**
按"层缓存友好+最小镜像+安全"三条线：①层顺序——不常变的放前面（系统依赖→依赖清单→源码），依赖文件单独 COPY 后安装，源码变更不触发依赖重装；②多阶段构建——编译阶段用全量工具链，运行阶段只拷贝产物到 slim/distroless 基础镜像（Java：jlink 定制 JRE 或 JRE-slim，体积从 GB 降到百 MB 级）；③合并 RUN 减层、清理包管理缓存同层删除（否则缓存层仍在）；④安全——不用 latest 固定版本、非 root 用户运行、.dockerignore 排除秘钥与构建产物；⑤可观测与优雅停机——正确 ENTRYPOINT 形态（exec 格式让 PID 1 收到信号）。


### Docker-001-003 | ★★☆☆☆

Docker 的网络模式有哪些？

**答案：**
五种常用：bridge（默认，docker0 网桥+NAT，容器互访走内部网络，外部访问需 -p 端口映射）、host（共享宿主网络栈，性能最好无 NAT，端口直接冲突）、container（共享另一容器网络栈，sidecar 形态）、none（无网络）、overlay（跨主机容器互通，Swarm/K8s CNI 底层，VXLAN 封装）。理解 bridge 的关键链路：veth pair 一端在容器一端在 docker0，出网走 iptables MASQUERADE 伪装；外部访问经 DNAT 映射。K8s 场景换 CNI 语义：Pod 各有独立 IP，跨节点通过 overlay/路由直通，Service 再做虚拟 IP 负载（K-TOOL-010）。


### Docker-001-004 | ★★★☆☆

Kubernetes 的核心概念？Pod、Deployment、Service 之间的关系？

**答案：**
核心抽象链：Pod 是最小调度单元（一个或多个共享网络/存储的容器，业务容器+sidecar）；ReplicaSet 维持副本数；Deployment 管理 ReplicaSet 实现声明式发布与回滚（滚动更新 maxSurge/maxUnavailable 控制节奏）；Service 给一组 Pod 提供稳定访问入口（ClusterIP 虚拟 IP + kube-proxy 转发，对外用 NodePort/LoadBalancer）；Ingress 七层路由入口（域名/路径→Service）。声明式与控制循环是 K8s 的灵魂：用户提交期望状态（YAML），控制器持续比对实际状态收敛（自愈、扩缩容由 HPA 按指标自动伸缩）。配置与敏感信息：ConfigMap/Secret 挂载或注入环境变量。


### Docker-001-005 | ★★★★☆

容器与虚拟机

容器与虚拟机的本质区别是：

A. 容器没有文件系统
B. 容器共享宿主机内核、以 Namespace/Cgroup 隔离限制；虚拟机虚拟完整硬件与独立内核
C. 容器不能联网
D. 虚拟机更轻量

**答案：** B

**解析：**
容器=进程级隔离（秒级启动、MB 开销、隔离弱）；VM=硬件级（分钟级、GB 级、隔离强）；A/C/D 错。

Namespace 视图隔离 + Cgroup 资源限额 + UnionFS 分层镜像。


### Docker-001-006 | ★★★☆☆

Dockerfile 层缓存

Dockerfile 中应把最常变动的指令放在：

A. 尽量靠前
B. 尽量靠后（如源码 COPY），使前面层的缓存可复用
C. 任意位置无差别
D. 放在 FROM 之前

**答案：** B

**解析：**
某层变更使其后所有层缓存失效，稳定层（依赖安装）在前、易变层（源码）在后；A 反了；C/D 错。

层缓存按顺序失效；.dockerignore 减少无效失效。

