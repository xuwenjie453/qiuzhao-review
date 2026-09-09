# 总控执行提示词：修复问题图坐标与 PDF-like Reader

你是本仓库的 AI Coding Agent。请在当前工作区中完成问题一和问题二的工程修复，但必须先调查再修改，禁止凭感觉直接改字号或 offset。

## 必读内容

完整阅读：

- 根目录 `AGENTS.md`；
- `提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/00-运行总控Prompt.md`；
- `提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/21_双端问题图与iPad协作协议.md`；
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/04_iPad端/02_问题图Topology设计.md`；
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/04_iPad端/03_Markdown阅读器.md`；
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/04_iPad端/04_阅读排版Token.md`；
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`；
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/03_协议与同步/04_ClientCommand与冲突处理.md`；
- `提示词规划/qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线/06_质量与交付/03_测试策略.md`。

## 不可违反约束

- Mac 是 QuestionGraph canonical authority，iPad 是本地优先 reader/interaction client；
- `x_norm/y_norm` 仍是 0..1 逻辑坐标，不把屏幕像素写进协议；
- Node body immutable，不能通过本次修复修改正文；
- PencilDrawing 仍按 node_id 绑定，不能因为版式重构丢失旧笔迹；
- 不改正式题库、scheduler、Goal、三引擎或学习事件；
- 不引入 WebView 作为默认 Reader 捷径，除非证明坐标稳定并得到明确记录；
- 不用 `git reset --hard`、`git clean -fd` 覆盖用户改动；
- 任何未实际发生的真机测试、Pencil 测试、网络结果都不得声称 PASS。

## 执行方式

1. 记录当前 `git status --short`，保护已有修改；
2. 运行基线测试并记录输出；
3. 按编号逐个执行本目录提示词；
4. 每完成一个阶段都做最小编译/测试；
5. 遇到坐标或版式问题时先加诊断数据，再做实现；
6. 最后运行完整测试和实体设备验收；
7. 输出修改文件、测试证据、设备信息、已知风险和回滚边界。

每个阶段完成后，必须回答：修改了什么、证明了什么、还有什么没有证明。

