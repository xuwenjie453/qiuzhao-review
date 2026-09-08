# 阅读顺序、权威与上下文预算

## 第一次接管时必须按顺序阅读

### A. 当前系统
1. 根 `AGENTS.md`
2. 根 `README.md`
3. `学习系统/README.md`
4. `学习系统/lsys/` 中 schema、scheduler、review、probe、db、materials 相关代码
5. RuntimePrompt V1 的总控、自然语言协议、事件记录、数据库 QA、对应学习/复习运行文件

### B. 本次设计
至少完整阅读 `90_设计稿基线/`：
- `00_入口/*`
- `01_产品与领域/*`
- `02_Mac端/*`
- `03_协议与同步/*`
- `04_iPad端/*`
- `05_集成与迁移/*`
- `06_质量与交付/*`
- `07_ADR/*`
- `08_附录/01_SQL_Schema_v1.md`
- `08_附录/02_协议样例.md`
- `08_附录/05_实现时禁止自行决策的事项.md`

### C. 参考项目
阅读 `reading-system` 只为寻找可复用的工程结构，优先：
- ReadingSystem-Mac daemon / store / bridge / websocket / Bonjour / tests；
- ReadingSystem-iPad Protocol / Store / Connectivity / Sync / Topology / Reader / Pencil。

## 权威规则

设计稿是产品语义权威；代码是当前事实权威。

当设计稿说“应该新增 A”，但当前仓库已经存在功能等价 B：
- 不重复造第二套；
- 先验证 B 是否完全满足设计；
- 若满足，复用并记录映射；
- 若只满足一部分，最小扩展 B。

当 reading-system 与本设计冲突：
- 一律以本设计为准。
典型冲突：
- reading-system 有 6 位配对码，本项目禁止；
- reading-system 有手动 IP 兜底，本项目禁止常规连接配置；
- reading-system 的 ContentGraph 业务不是 QuestionGraph；
- reading-system 的 Focus/Curator 不应搬入本项目学习业务。

## 上下文压缩原则

如果上下文很大，优先保留：
1. 不变量；
2. 当前阶段接口；
3. schema / wire fixtures；
4. 当前改动 diff；
5. 测试失败；
6. 与当前任务直接相关的源码。

不要把 54 份设计稿每轮全部塞进上下文；按阶段读取。
