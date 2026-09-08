# 秋招复习系统双端更新 — AI 实施提示词运行包 v1

本包用于直接交给具备仓库读写、终端、Git、Node.js、Python、Xcode/Swift 能力的 AI Coding Agent，实施 `qiuzhao-review` 的双端更新。

本包不是产品设计稿的替代品。`90_设计稿基线/` 是冻结的 Canonical Design；本包其余 Markdown 是把设计稿转换成可执行工作流、阶段任务、代码审查、联调、测试与交付提示词。

## 这次必须真正交付什么

1. 在现有 `qiuzhao-review` 上新增 Mac 双端伴生守护进程。
2. 新增独立 iPadOS Reader App，形成可由 Xcode 打开的完整工程。
3. Mac 与 iPad 在同一 LAN 下使用 Bonjour 自动发现、WebSocket 自动连接，**不要求 IP、端口、验证码、人工配对**。
4. 双端围绕 `QuestionGraph` 工作：
   - `CENTER` 正方形、永久、不可删除；
   - `EXPLANATION` 圆形、用户显式加入、永久；
   - `TEMPORARY` 三角形、用户显式加入、仅当前 round。
5. iPad 高层展示问题图；低层展示 immutable Markdown body，并允许 Apple Pencil 手写。
6. Apple Pencil Ink 使用 PencilKit，`PKDrawing` 与 `node_id` 长期绑定；支持双击 Pencil 切换橡皮擦（硬件支持时）。
7. 保持原 `qiuzhao-review` Goal / Scheduler / 三引擎 / Event / Review / RAG 业务不变。
8. 更新 Runtime Prompt、AGENTS、README，使 Agent 会在讨论题目时执行 `question.open / node.add / question.close`。

## 使用顺序

实施 AI 必须先读：

1. `00_总控/00_MASTER_EXECUTION_PROMPT.md`
2. `00_总控/01_READ_ORDER_AND_AUTHORITY.md`
3. `00_总控/02_NON_NEGOTIABLE_PRODUCT_RULES.md`
4. `90_设计稿基线/00_入口/00_AI_IMPLEMENTATION_BRIEF.md`
5. `90_设计稿基线/01_产品与领域/01_需求基线与不可违反约束.md`
6. `01_基线侦察/00_REPOSITORY_RECON_PROMPT.md`

然后严格按 `02_Phase0` → `09_Phase7` 顺序执行。

## 权威顺序

当内容冲突时：

`用户最新明确要求 > 90_设计稿基线 > 本执行提示词包 > reading-system 参考实现 > 实施者偏好`

`reading-system` 只能作为工程参考，不能反向修改已经冻结的产品要求。

## 实施 AI 的基本工作方式

- 先调查，再修改。
- 每个阶段先运行基线测试，再做最小闭环实现，再测试。
- 不覆盖用户已有未提交修改。
- 不使用 `git reset --hard`、`git clean -fd` 等破坏性命令。
- 不把“能编译”当“已验收”；真机 Pencil Gate 必须真实 iPad + Apple Pencil。
- 如果环境缺 Xcode，可以继续完成源码/工程生成与静态检查，但不得把 iPad build / Pencil gate 标为 PASS。
- 如果参考排版 PDF 未提供，功能照常完成，但 PDF 排版项只能标 `BLOCKED_BY_MISSING_INPUT`。

## 交付报告

实施结束后必须按 `12_交付模板/03_FINAL_DELIVERY_REPORT_TEMPLATE.md` 输出：
- 修改文件；
- 新增工程；
- 测试证据；
- 未通过/被阻塞 Gate；
- 启动步骤；
- 风险与后续事项。

## 模块级合同

写具体代码前，进一步读取 `15_模块级实施合同/` 中对应模块，里面给出建议接口、事务边界、Actor/线程边界和 E2E 顺序。
