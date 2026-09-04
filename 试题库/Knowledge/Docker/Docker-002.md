### Docker-002-001 | ★★★★☆

Docker底层依托于Linux是怎么实现资源隔离的？

**答案：**
通过Linux Namespace（PID/NET/MNT/UTS/IPC/USER）实现视图隔离，通过Cgroups限制CPU、内存、IO等资源用量，配合UnionFS实现镜像分层。


### Docker-002-002 | ★★★★☆

Docker和虚拟机有什么区别？

**答案：**
容器共享宿主机内核、通过namespace/cgroup做隔离，秒级启动、开销小；虚拟机通过Hypervisor虚拟出完整硬件并运行独立内核，隔离更强但重、启动慢。


### Docker-002-003 | ★★★★☆

Docker有哪几个核心组件？镜像和容器有什么区别？

**答案：**
核心组件：客户端docker CLI、服务端dockerd（containerd、runc）、镜像、容器、仓库；镜像是只读的分层模板，容器是镜像的一个可写运行实例（镜像+可写层）。


### Docker-002-004 | ★★★★☆

Docker镜像的分层原理是什么？

**答案：**
基于联合文件系统（OverlayFS），镜像由多个只读层叠加，容器启动时在其上加一个可写层（写时复制），多镜像可共享基础层节省存储与传输。


### Docker-002-005 | ★★★★☆

Dockerfile常用指令有哪些？CMD和ENTRYPOINT有什么区别？COPY和ADD有什么区别？

**答案：**
FROM/RUN/COPY/ADD/CMD/ENTRYPOINT/EXPOSE/ENV/ARG/VOLUME/WORKDIR等；CMD提供默认命令可被docker run参数覆盖，ENTRYPOINT固定入口不易覆盖；ADD在COPY基础上支持自动解压tar和远程URL（不建议用于远程）。


### Docker-002-006 | ★★★★☆

如何减小Docker镜像体积？

**答案：**
选精简基础镜像（alpine/slim）、多阶段构建、合并RUN层并清理缓存（rm -rf /var/lib/apt/lists/*）、使用.dockerignore、必要时用distroless/scratch。


### Docker-002-007 | ★★★★★

Docker容器数据持久化有哪些方式？

**答案：**
三种：volume（由Docker管理、推荐）、bind mount（挂载宿主机目录）、tmpfs mount（内存挂载）。


### Docker-002-008 | ★★★★☆

Docker的网络模式有哪些？同一个宿主机上的多个容器之间怎么通信？

**答案：**
bridge（默认，docker0网桥+veth）、host（共享宿主网络栈）、none、container（共享另一容器网络）、自定义overlay；同宿主机容器通过bridge网桥+iptables/veth互连，可用容器名走嵌入式DNS。


### Docker-002-009 | ★★★★☆

Docker常用命令有哪些？如何进入一个运行中的容器？

**答案：**
docker ps/run/exec/build/images/logs/inspect/stop/rm/rmi等；进入运行中容器用docker exec -it <容器> /bin/bash。


### Docker-002-010 | ★★★★☆

容器启动后立刻退出，怎么排查？

**答案：**
先docker logs看日志、docker inspect看退出码与OOMKilled；常见原因是主进程前台无任务（如bash未加-ti）、应用崩溃或配置错误；可改交互式启动复现。


### Docker-002-011 | ★★★★☆

Docker和Kubernetes是什么关系？

**答案：**
Docker负责"怎么把一个容器跑起来"，Kubernetes负责"怎么把一大堆容器跨多台机器跑起来、管起来"（调度、扩缩容、服务发现、自愈）；K8s通过CRI对接容器运行时（现多用containerd）。


### Docker-002-012 | ★★★★☆

Kubernetes的网络模型是如何实现的？如何实现跨节点通信？

**答案：**
K8s要求每个Pod有全局唯一IP（扁平网络）；同节点走docker0/网桥，跨节点由CNI插件（Flannel VXLAN、Calico BGP等）建立overlay或路由转发。


### Docker-002-013 | ★★★★☆

在Kubernetes中，如何保证Pod重启后其IP地址不变？

**答案：**
Pod重启IP通常会变，这是设计使然；对外稳定访问靠Service（虚拟IP+DNS）或StatefulSet（稳定网络标识+持久存储），而不是固定Pod IP。


### Docker-002-014 | ★★★★★

如何保护Kubernetes集群安全、防止集群被攻击？

**答案：**
启用RBAC最小权限、API Server禁用匿名访问/TLS双向认证、限制etcd访问、NetworkPolicy隔离Pod、镜像扫描与只读rootfs、不特权容器、及时升级补丁。


### Docker-002-015 | ★★★★☆

讲讲cgroup v2.0

**答案：**
cgroup v2统一层级（统一层级结构），所有控制器挂在同一棵树，改进了进程移动规则、增加了压力通知（PSI）等，替代v1的多挂载点混乱模型。


### Docker-002-016 | ★★★★☆

什么是多阶段构建（multi-stage build）？有什么好处？

**答案：**
一个Dockerfile中写多个FROM阶段，最终阶段只COPY前一阶段的构建产物；好处是不把编译工具链打进最终镜像，显著减小体积。


### Docker-002-017 | ★★★★☆

Docker Compose是什么？什么场景用？

**答案：**
用一个yaml文件定义并编排多个容器（服务、网络、卷依赖），适合本地开发/单机多容器应用的启动管理。


### Docker-002-018 | ★★★★☆

docker commit和docker build有什么区别？docker run的常用参数有哪些？

**答案：**
commit把容器当前状态固化为镜像（不可复现、不推荐），build按Dockerfile可重复构建；run常用参数：-d后台、-p端口映射、-v挂载、-e环境变量、--name、--restart、--network。


### Docker-002-019 | ★★★★☆

如何清理Docker的无用镜像、容器和卷？

**答案：**
docker system prune清理停止的容器、悬空镜像、未用网络；加-a清理所有未使用镜像，docker volume prune清理未用卷。


### Docker-002-020 | ★★★★☆

Kubernetes网络插件有哪些？Calico和kube-router有什么区别？哪种适合大规模部署？

**答案：**
常见Flannel（VXLAN简单）、Calico（BGP路由+网络策略）、Cilium（eBPF）、Weave、kube-router；Calico用原生路由性能好、支持NetworkPolicy，适合大规模。


### Docker-002-021 | ★★★★☆

如何在Kubernetes中进行故障排查？

**答案：**
kubectl describe pod看事件、kubectl logs看容器日志、kubectl get events排查调度/镜像/探针问题，必要时exec进容器、查节点与CNI/DNS状态。


### Docker-002-022 | ★★★★☆

如何在Kubernetes中进行应用的灰度发布？

**答案：**
用Deployment+Service，配合rollingUpdate(maxSurge/maxUnavailable)、按版本打标签切流量，或用Nginx/Istio ingress按权重、header分流实现金丝雀发布。


### Docker-002-023 | ★★★★☆

请解释Kubernetes中的Helm及其用途。

**答案：**
Helm是K8s包管理工具，用chart模板化管理应用的所有资源清单，支持版本化安装、升级、回滚，简化复杂应用部署。


### Docker-002-024 | ★★★★☆

如何在Kubernetes中实现CI/CD流水线？请简述K8s中的监控方案。

**答案：**
CI/CD常用Jenkins/GitLab CI/ArgoCD，代码合并触发构建镜像推仓库再kubectl/Helm/Argo Rollouts更新；监控主流Prometheus+Grafana+Alertmanager（cAdvisor/kube-state-metrics采集），日志用EFK/Loki。

