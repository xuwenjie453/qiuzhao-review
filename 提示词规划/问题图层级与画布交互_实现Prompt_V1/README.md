# 问题图层级与画布交互：AI 实现 Prompt 包 V1

本 Prompt 包用于把两项已经完成设计的 QuestionGraph 功能交给实现型 AI 落地：

1. **iPad 问题图空白区域拖动画布（Canvas Pan）**：从空白处拖动时，整张图的节点与连线一起做本地 viewport 平移；不修改 canonical layout，不发 `MOVE_NODE`。
2. **解释节点指定父节点 + “解析节点”基础能力（Parent Node / Parse Foundation）**：创建 `EXPLANATION` 时可指定 `parent_node_id`；未指定默认 CENTER。用户明确要求“解析/抽取某节点的一部分”时，AI 可基于父节点正文重新收集、组织成自包含子解释节点，并把它连接到指定父节点。

> 本包是**实现提示词**，不是运行期学习 Prompt。执行者必须先阅读仓库 `AGENTS.md` 和 RuntimePrompt 21，再按本包顺序修改代码、协议、迁移、测试与运行契约。

## 使用方式

将 `01_总控实现Prompt.md` 作为主 Prompt 交给编码 AI，并允许它读取本目录其余文件。若执行环境只能一次输入一个 Prompt，则按以下顺序逐个执行：

```text
01 总控实现
  ↓
02 基线审计与不可破坏契约
  ↓
03 Canvas Pan
  ↓
04 Parent Node：Mac canonical + schema
  ↓
05 Parent Node：iPad protocol/cache/render
  ↓
06 解析节点：Runtime Agent 语义
  ↓
07 测试、兼容性与最终审计
```

## 执行原则

- **先审计，后修改。** 不要假定仓库与本 Prompt 完全一致；以当前分支代码为事实，若有小幅漂移则适配实现，但不得改变这里冻结的业务语义。
- **不要重新设计 V1。** 不新增 `PARSED_NODE`、任意 Edge 系统、多父节点、拖线建边、Web 前端、平行架构。
- **分层修改。** Canvas Pan 只能落在 iPad 本地 UI/Topology 层；Parent Node 才进入 Mac canonical schema / sync / iPad cache。
- **兼容旧数据。** 旧图升级后视觉结构必须保持原样；旧 snapshot 缺 `parent_node_id` 时客户端仍能工作。
- **测试不造假。** 能运行的测试必须运行；环境没有 Xcode/iPad Simulator 时必须明确写“未运行”，只允许报告静态核对结果。

## 最终交付

实现型 AI 最终应提交：

- 功能代码；
- schema migration；
- snapshot / patch / cache 兼容；
- Mac 与 iPad 侧测试；
- RuntimePrompt 21 对“解析节点”例外的最小更新；
- 一份最终审计报告，逐条回答 `07_测试、兼容性与最终审计.md`。
