# 问题图坐标与 PDF-like Reader 修复提示词包

本目录是一套给 AI Coding Agent 使用的执行提示词，用于修复 iPad 端两个高风险 UI 问题：

1. 问题图中节点的可见位置、实际命中位置、拖动位置不一致；
2. 节点 Reader 不是类似 iPad 横屏 PDF 阅读器的页面观感，页面留白不可写、字号和版心不匹配。

## 使用顺序

必须按以下顺序执行，不要跳过基线调查：

1. `01_MASTER_EXECUTION_PROMPT.md`
2. `02_AUTHORITY_SCOPE_AND_SAFETY.md`
3. `03_BASELINE_RECON_AND_RUNTIME_CAPTURE.md`
4. `04_GRAPH_COORDINATE_DIAGNOSTICS_PROMPT.md`
5. `05_GRAPH_GEOMETRY_IMPLEMENTATION_PROMPT.md`
6. `06_GRAPH_GESTURE_IMPLEMENTATION_PROMPT.md`
7. `07_GRAPH_OPTIMISTIC_SYNC_PROMPT.md`
8. `08_GRAPH_TEST_GATE_PROMPT.md`
9. `09_READER_PAGE_MODEL_PROMPT.md`
10. `10_READER_PDF_TYPOGRAPHY_PROMPT.md`
11. `11_READER_PENCIL_COORDINATE_PROMPT.md`
12. `12_READER_PERSISTENCE_COMPAT_PROMPT.md`
13. `13_READER_TEST_GATE_PROMPT.md`
14. `14_DUAL_END_DEVICE_QA_PROMPT.md`
15. `15_CODE_REVIEW_AND_DELIVERY_PROMPT.md`

如果只修问题图，执行 01→08；如果只修 Reader，执行 01→03、09→15。

## 权威关系

当本目录与其他内容冲突时，按照以下顺序裁决：

```text
用户最新明确要求
> AGENTS.md
> 秋招智能学习与复习体系_RuntimePrompt_V1
> qiuzhao_dual_end_execution_prompt_pack_v1/90_设计稿基线
> 本目录提示词
> 参考实现和 AI 自行偏好
```

本目录只允许修改 DualEnd-Mac / DualEnd-iPad 伴生能力，不得重构 Scheduler、Goal、三引擎、题库或学习事件系统。

## 完成标准

- 节点显示中心、命中中心、拖动中心完全一致；
- 拖动无累计漂移、无松手回弹、无旧 ACK 覆盖新位置；
- 横屏 Reader 显示居中的 A4 竖版纸张；
- A4 页面内部正文和两侧留白均可用 Apple Pencil 书写；
- 页面外灰色背景不被误认为可写区域；
- 屏幕旋转、滚动、缩放后笔迹不偏移；
- Simulator 测试通过，实体 iPad + Apple Pencil Gate 通过；
- 交付报告记录修改、命令、证据、未解决风险。

