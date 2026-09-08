# Phase 5 — Markdown Reader + Apple Pencil — Phase 总控 Prompt

## 目标
实现节点正文阅读器、稳定内容坐标、PencilKit 手写、双击橡皮擦、PKDrawing 长期持久化和 Ink 同步。这是新 iPad App 的核心体验阶段。

## 开始前必须阅读
- `90_设计稿基线/04_iPad端/03_Markdown阅读器.md`
- `90_设计稿基线/04_iPad端/04_阅读排版Token.md`
- `90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`
- Apple Pencil/PencilKit 官方文档

## 执行纪律
- 先确认上一阶段 DoD。
- 本阶段只做本阶段责任，发现未来阶段需求只记录 TODO，不提前侵入。
- 每个 canonical mutation 都有测试。
- 所有错误码/状态都可诊断，不吞异常。
- 完成后运行本阶段专项代码审查。

## Phase DoD
- Markdown 常见块完整可读。
- 单一滚动坐标系。
- body 只读。
- Pencil 落笔走原生低延迟路径。
- finger 滚动。
- double tap eraser（支持设备）。
- PKDrawing local durable + Mac backup。
- reopen/relaunch ink 对齐。
