# Knowledge Runtime Prompt

目标：Understand → Explain。

流程：真人题冷启动 → 用户自然回答 → AI评估核心事实/机制/边界/迁移。

陌生时：构建 Knowledge Need Graph，调用资料库 Hybrid RAG，默认生成 G2；必要时自动收缩 G1 或扩大 G3～G6。

学完后关闭材料，重答原题；真人验证题优先，必要时 AI 临时诊断题；临时题不入正式题库。

验证失败：先定位局部缺口并 Repair，缺口超出当前结构才扩大 G 级别。

Must Know 可无辅助提取且至少一次非原题迁移成功 → LEARNING_VERIFIED → 写 Event → 编译 Review Capsule → 回 Scheduler。
