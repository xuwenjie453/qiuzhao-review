# MASTER — QuestionGraph 继承增量更新总控 Prompt

你正在 `xuwenjie453/qiuzhao-review` 中实施已经冻结的 QuestionGraph inheritance 架构。你的职责是**按阶段安全修改现有系统**，不是重新设计产品。

## 一、开始前必须做

1. 读取仓库根 `AGENTS.md`。
2. 读取本 Prompt Pack 的 `README.md`、`MANIFEST.md`、`00_总控/*`。
3. 读取设计基线中的：问题图领域模型、问题图继承详细设计、Snapshot/Patch、iPad Topology、迁移策略、问题图继承实施清单。
4. 读取当前实现相关文件，不允许只靠设计稿猜代码。
5. 运行当前基线测试并记录真实结果；已有失败必须与本次改造引入的失败区分。

## 二、目标

实现以下事实：

```text
Question Bank Graph B owns E1,E2,E3
Review Graph A owns CENTER_A
A inherits B
=> A effective view = CENTER_A + E1 + E2 + E3
```

其中 E1/E2/E3 在 A 中仍是 B 拥有的同一 canonical node，不创建副本。

## 三、不可修改的核心语义

- child 必须是 `REVIEW_CAPSULE` graph；parent 必须是 `QUESTION_BANK` graph。
- V1 runtime 最多一个 primary parent；schema 可保留未来多 parent 能力。
- inheritance kind 只有 `SHARED_EXPLANATIONS`。
- CENTER 不继承，TEMPORARY 不继承，只继承 persistent EXPLANATION。
- inherited node 保持相同 `node_id`。
- rename/move/Ink 对 inherited node 都 write-through 到 canonical node。
- layout 和 Ink 是 node-scoped，不做 per-graph override。
- child 新 Explanation 不反向进入 parent/sibling。
- parent 后续新 Explanation 动态进入 child effective view。
- inherited delete 是 global delete，UI 必须明确告知影响范围。
- `primary_source_question_id` 是 inheritance anchor；不得从 `source_questions[0]` 猜。
- parent graph 缺失时，Review 仍可用；不得伪造历史 Explanation。

## 四、增量执行纪律

严格按 A→H Phase 推进。每个 Phase：

1. 先列出将修改的文件与不修改的文件。
2. 先补/调整最小测试，再实现代码，或至少同步完成测试。
3. 只做本 Phase 必需变更，禁止顺手重构无关模块。
4. 运行本 Phase Gate；失败则停留在本 Phase 修复。
5. 记录实际行为与设计是否一致。
6. 通过后再进入下一 Phase。

不要一次性跨 Mac Store、Wire、iPad、Review Runtime 同时大改后才运行测试。

## 五、必须保留的旧不变量

- CENTER 每图唯一且不可删除。
- body immutable。
- TEMPORARY round isolation。
- rename/delete 使用 node_revision CAS。
- move 使用 layout_revision CAS。
- Ink revision 连续与幂等。
- command dedup one-effect。
- Mac durable-before-emit/ACK。
- iPad durable-before-ACK。
- iPad outbox 仅凭 ACK 清除。
- patch base mismatch → snapshot recovery。
- daemon crash 后 canonical graph 可恢复。

## 六、完成定义

只有同时满足以下条件才允许报告“完成”：

- migration 从真实 v1 schema 无损到 v2；
- Mac unit 全绿；
- Bridge E2E 全绿；
- iPad build + unit 全绿；
- 学习系统 E2E 全绿；
- Review Capsule 能写 primary source；
- Review graph 能继承来源 Question Bank graph；
- parent/child/sibling 对 shared title/layout/Ink 一致；
- parent 新增 Explanation 能动态出现于 child；
- child 自有 Explanation 不污染 parent/sibling；
- inherited delete warning 存在；
- Release Checklist 已增加 inheritance 项；
- 无测试证据的真机项标记 NOT_RUN/BLOCKED，而不是假装 PASS。

## 七、最终输出格式

最终报告必须包含：

- 实际修改文件；
- schema/wire version 变化；
- migration 说明；
- 关键不变量实现位置；
- 测试命令与结果；
- 未运行/阻塞项；
- 已知风险；
- 与设计稿任何偏差（若有）。
