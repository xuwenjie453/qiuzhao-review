# 小林面试笔记「大模型面试题」Markdown 合集（AI / Agent 方向）

> 内容搬运自小林coding旗下 [xiaolinnote.com](https://xiaolinnote.com/ai/)，
> **版权归原作者「小林coding」所有**，仅供个人学习使用，请勿用于商业用途或二次分发。
> 整理时间：2026-09-03（对应官网当期版本）。

## 目录结构（与官网侧边栏 5 个子类一一对应）

| 子类 | 篇数 | 内容 |
|------|------|------|
| [01｜Agent面试题](<01｜Agent面试题/>) | 17 | Agent 概念与架构、Workflow/Tools、ReAct 与设计范式、任务拆分、记忆机制与压缩、Multi-Agent 协作等 |
| [02｜RAG面试题](<02｜RAG面试题/>) | 21 | RAG 工作流程、文档切割与 Embedding、向量数据库选型、多路召回、检索优化、幻觉规避、效果量化等 |
| [03｜LLM工具调用面试题](<03｜LLM工具调用面试题/>) | 17 | Function Calling 原理与训练、MCP 协议、Skill、A2A、SSE/WebSocket/WebRTC、大模型网关等 |
| [04｜大模型工程面试题](<04｜大模型工程面试题/>) | 23 | Transformer、MHA/MQA/GQA、位置编码、分词器、训练与微调（LoRA/SFT/RLHF/DPO/PPO）、解码策略、KV Cache、量化、Prompt、幻觉、MoE、部署方案等 |
| [05｜LangChain框架面试题](<05｜LangChain框架面试题/>) | 13 | LangChain 架构与 Chain、构建 Agent、工具注册、记忆、LlamaIndex/LangGraph 对比、LangChain4j、版本演进、Deep Research 等 |

另附官网总览页：[00-AI面试总览.md](<00-AI面试总览.md>)。共 **5 个子类、92 个 Markdown 文件**，文件顺序与官网一致（`00-` 为该子类的介绍页）。

## 说明

- 每个 Markdown 文件由官网页面（VuePress 静态页）转换而来，正文为官网原样的「面试官 / 我」对话体，保留全部图片外链（托管在 `cdn.xiaolincoding.com`，联网时可正常显示）、代码块与表格。
- 文件头部有 YAML front matter：`title` / `source`（原文链接）/ `author` / `fetched`。
- 官网后续更新不会自动同步到这里，如需最新版请直接访问官网。
- 配套的 Java 后端「面试八股题」9 大子类合集在本库 `Java面试资料/xiaolincoding_教程原文MD/`。
