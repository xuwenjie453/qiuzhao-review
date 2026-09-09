# Pencil 悬停预览修复实施提示词包 v3

本包是 **实施契约**：根因已定位并经用户确认症状，本包冻结修复设计与执行流程，指导 AI 从取证到真机交付全程执行。不是诊断包——诊断结论见 `02_根因与设计冻结.md`，不要重新推导。

## 适用问题（用户确认的症状，以此为准）

- Pencil **离屏幕很近时**（悬停在上方，或接触屏幕书写中），PencilKit 的**实时渲染错位**：
  - 悬停预览点偏离笔尖实际指向；
  - **书写中的墨迹也画在错位的位置**（与预览同样偏移）。
- **Pencil 一远离屏幕，刚写的笔迹立刻回到正确位置**，页面恢复。
- 笔迹**数据始终正确**：退出重进笔迹在正确位置，Mac 同步 / ink_revision / node_id 正常。
- 偏移的**方向规律与复现条件未确认**（不得引用旧诊断报告中的方向描述作为事实）。
- 第一轮补丁（Canvas 内部状态归零：contentInset/contentOffset/zoomScale/contentSize + 布局期禁交互）装真机后**行为无任何变化**。

## 与 v1 / v2 的关系

| 包 | 角色 | 状态 |
|---|---|---|
| `Pencil悬停预览坐标修复` (v1) | 坐标级补丁思路 | 已证明无效（未触及结构） |
| `Pencil悬停预览根因修复_v2` | 根因诊断 + 架构方向 | 诊断已完成；09 号架构修复提示词是本包前身 |
| **本包 (v3)** | 基于确认根因的冻结设计 + 分阶段实施 | ★ 当前执行 |

## 根因一句话

> 旧架构中 PKCanvasView 处于被外层 UIScrollView 放大约 2 倍的层级内、自身 `zoomScale` 锁定为 1。PencilKit 的实时渲染路径（悬停预览 + 书写中墨迹）以 `canvas.zoomScale` 为几何基准，提交路径（tile 渲染）跟随真实 layer 树——两套基准分裂导致“笔在附近时实时渲染错位、笔远离后提交路径重渲归位”；触点→数据链路走标准坐标转换，故数据始终正确。

## 执行顺序（阶段间有硬闸门，不得跳步）

1. `01_MASTER_EXECUTION_PROMPT.md` —— 总控
2. `02_ROOT_CAUSE_AND_DESIGN_FREEZE.md` —— 根因与设计冻结（先读，禁止改设计）
3. `03_SCOPE_AND_SAFETY_PROMPT.md` —— 范围与安全边界
4. `04_PHASE0_DEVICE_INSTRUMENTATION_PROMPT.md` —— 真机取证（go/no-go 闸门）
5. `05_ARCHITECTURE_IMPLEMENTATION_PROMPT.md` —— 架构实施
6. `06_PREVIOUS_ATTEMPT_CORRECTIONS_PROMPT.md` —— 对「暂存」版的修正清单
7. `07_UNIT_TEST_PROMPT.md` —— 纯逻辑单测
8. `08_HOSTED_SMOKE_TEST_PROMPT.md` —— 全链路冒烟（“进不去节点”回归闸门）
9. `09_OFFLINE_REPRO_HARNESS_PROMPT.md` —— 离线端到端复现装置
10. `10_REAL_DEVICE_QA_PROMPT.md` —— 真机验收
11. `11_REVIEW_AND_DELIVERY_PROMPT.md` —— 复核与交付报告

## 绝对约束（继承 v2，全文有效）

- 不修改学习系统、scheduler、正式题库、Mac canonical schema、WebSocket 协议。
- 不修改 `PKDrawing` stroke 点坐标，不迁移历史笔迹。
- 禁止 `+dx/+dy` 补偿、分区域补偿、魔法延迟等“修复”。
- 不以禁用 Pencil 书写或禁用 hover 作为方案。
- 不用 `UIScreen.main.bounds` 替代 Reader 实际视口。
- **没有实体 iPad + Apple Pencil 验证前，交付状态只能写“待真机验证”，不得写 PASS。**

## 当前仓库状态（执行前必须核对）

- 工作区 HEAD：**detached 于 `9866df4`「完成初步实现」**（旧架构：外层 UIScrollView 缩放）——本包在此基线上实施。
- `main` 分支指向 `5121d17`「暂存」（一次方向正确但有缺陷的架构重构，引入了“双击节点进不去”回归）——**只作只读参考**，见 `06` 号修正清单。
- 真机：iPad Air 11-inch (M4)，已配对，CoreDevice ID `AD98BAD8-7CB8-5EE3-AC86-8517E419613F`；真机上已装 `9866df4` 构建版。
- 模拟器：`iPad Air 11-inch (M4)` 可用；App Bundle ID `local.qiuzhaoreview.ipad`。
- 注意：模拟器内 App 的 WebSocket 传输要求 wifi 接口，连不上 Mac daemon（lo0 不满足）——模拟器验证一律走 `09` 号离线复现装置，不依赖 Bonjour。
