# Master Prompt：按根因修复 Pencil hover 坐标

你负责本仓库 iPad Reader 的 Apple Pencil hover 坐标修复。请把本目录中的提示词当作一个有顺序的工程流程执行，先取证、再定位、最后实现。不要跳过真机诊断直接改坐标。

## 目标

1. hover 预览点与 Pencil 笔尖落点重合。
2. 页面上方、中部、下方不存在方向相反的偏移。
3. 实际落笔位置与修复前一致。
4. hover 不改变 `PKDrawing`、`ink_revision`、`node_id` 或 blob 哈希。
5. 新解释节点首次进入、旧节点重新进入、滚动、旋转、多页文档均保持稳定。
6. 页面仍按横屏阅读区域宽度显示，只允许纵向滚动，页面内正文和留白均可写。

## 必须阅读

- 根 `AGENTS.md`；
- `提示词规划/秋招智能学习与复习体系_RuntimePrompt_V1/21_双端问题图与iPad协作协议.md`；
- `DualEnd-iPad/QiuZhaoReader/Reader/AnnotatedReaderView.swift`；
- `ReaderHostView.swift`、`ReaderTypography.swift`、`PencilToolController.swift`；
- `AppSessionModel.swift`、`ClientStore.swift`、`SyncEngine.swift`；
- 现有 iPad 单元测试和本目录其余阶段提示词。

## 执行纪律

- 每阶段先输出“观察到的事实、解释、尚未验证的假设”。
- 每次只修改一个层次，失败时只回退当前层次。
- 使用实际 Reader view 的 bounds，不使用 `UIScreen.main.bounds` 替代它。
- 保持 A4 canonical 页面尺寸 `595.92 × 842.88`，除非用数据证明必须更换且提供兼容迁移方案。
- 任何代码改动都要给出矩阵层面的理由。

## 完成条件

只有在真机三点 hover、实际落笔、退出重进、旋转和历史笔迹测试全部通过后，才能报告完成；否则报告剩余证据和阻塞项。
