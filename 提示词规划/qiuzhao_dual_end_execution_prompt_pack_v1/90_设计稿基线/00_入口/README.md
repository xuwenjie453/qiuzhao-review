# 秋招复习系统双端更新完整设计稿包 v1

> 目标：在**不重做现有秋招学习/复习算法**的前提下，把 iPad 纳入现有 Agent-native 秋招复习系统，形成“Mac 上与 ZCode/Codex 等 Agent 讨论问题，iPad 自动显示该问题的问题图并承担阅读与 Apple Pencil 批注”的双端系统。

## 0. 本设计稿的使用方式

任何接手实现的 AI，先按以下顺序阅读：

1. `00_AI_IMPLEMENTATION_BRIEF.md`：10 分钟内建立完整心智模型。
2. `01_产品与领域/01_需求基线与不可违反约束.md`：用户硬需求，优先级最高。
3. `01_产品与领域/03_总体架构.md`：系统边界与端到端主流程。
4. `01_产品与领域/04_问题图领域模型.md`：核心对象与不变量。
5. `02_Mac端/01_Mac守护进程.md` + `02_Agent接入契约.md`。
6. `03_协议与同步/*`：网络、Envelope、Patch、幂等、重连。
7. `04_iPad端/*`：问题图 UI、Markdown Reader、PencilKit。
8. `06_质量与交付/*`：测试、验收、实施顺序。

## 1. 一句话架构

```text
现有 qiuzhao-review 学习系统（Python/SQLite，继续负责调度、三引擎、复习）
        │
        │ Agent 显式调用双端命令
        ▼
DualEnd Mac Daemon（新增；问题图真源 + Bridge + 同步）
        │ Bonjour 自动发现 + WebSocket
        ▼
iPad Reader（新增；问题图 + Markdown Reader + PencilKit + 本地缓存/outbox）
```

**最重要的边界：**本次更新不是把 `qiuzhao-review` 改造成 `reading-system`。参考 `reading-system` 的是双端运行时、Bridge、Snapshot/Patch、durable-before-ACK、本地优先、PencilKit 等工程模式；秋招系统原有 Goal / Scheduler / Knowledge / Algorithms / Projects / Review Capsule 继续保留。

## 2. 本包目录

- `00_入口/`：AI 接管入口、术语、决策摘要。
- `01_产品与领域/`：范围、业务对象、问题图、会话轮次、不变量。
- `02_Mac端/`：守护进程、Agent 接口、存储、命令服务。
- `03_协议与同步/`：Bonjour、WebSocket、消息协议、同步、离线重连、信任模型。
- `04_iPad端/`：App 架构、Topology、Reader、Apple Pencil、本地数据库。
- `05_集成与迁移/`：与现有 qiuzhao-review 的结合、文件级改造、迁移。
- `06_质量与交付/`：状态机、失败矩阵、测试、验收、工作拆分。
- `07_ADR/`：关键架构决策记录。
- `08_附录/`：来源、协议样例、SQL、追踪矩阵。

## 3. 设计状态

- 架构：可直接实现。
- 协议：v1 已冻结到字段级。
- 数据模型：v1 已冻结到表级。
- iPad 阅读排版：**结构已冻结，但具体字号/左右留白必须从用户提到的参考 PDF 校准；本次输入中没有该 PDF，因此数值不能伪造。**
- 安全：按“个人可信局域网”威胁模型设计；为满足“零手动配对”不使用验证码配对。
