# 问题图节点拖动导致画布联动/闪烁：Bugfix Prompt 包 V1

本 Prompt 包用于修复 iPad QuestionGraph 的一个交互回归：

> 拖动单个节点时，整个问题图也会发生位移，背景持续抖动/闪烁。

当前问题发生在已经支持 Canvas Pan + Parent Node 的实现上。修复目标不是重写手势系统，而是恢复一个必须成立的交互不变量：

```text
Node Drag 只改变节点 canonical/transient position；
Canvas Pan 只改变本地 viewport offset；
两者不能形成反馈环。
```

## 使用方式

将 `01_总控修复Prompt.md` 作为主 Prompt 交给实现型 AI，并允许它读取本目录其余文件。推荐顺序：

```text
01 总控修复
  ↓
02 根因分析与不可破坏契约
  ↓
03 实现策略与代码修改
  ↓
04 回归测试与验收
```

## 修复边界

本 Bugfix 原则上只允许修改：

```text
DualEnd-iPad/QiuZhaoReader/Topology/QuestionGraphView.swift
DualEnd-iPad/QiuZhaoReader/Topology/GraphCanvasGeometry.swift   # 仅必要 helper
DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift
```

禁止为了修这个 Bug 修改：

```text
DualEnd-Mac/
Mac SQLite schema
parent_node_id 数据模型
sync wire protocol
ClientStore canonical/cache schema
RuntimePrompt
```

## 冻结结论

当前实现的主要问题不是“Canvas Pan 手势 guard 完全失效”，而是：

```text
Node drag → dragTransient 变化
          → baseNodeCenters 变化
          → viewport clamp bounds 变化
          → liveCanvasOffset 被重新 clamp
          → 整张图移动
          → Node inverse transform 又使用变化后的 viewportOffset
          → 形成视觉/坐标反馈环
```

因此主修复必须是：

> **viewport clamp 不得依赖节点拖动中的 `dragTransient`。**

进一步要求：

> **Node Drag 生命周期内 viewport offset 必须保持稳定；节点拖动不能反向驱动 camera/viewport。**

## 完成标准

修复后必须同时满足：

- 拖动任意非 CENTER 节点时，整张图不跟随移动；
- 背景不闪烁、不抖动；
- 节点仍能正常拖动并最终产生原有 MOVE_NODE canonical mutation；
- Canvas Pan 从空白处开始时仍能正常平移整图；
- 从节点开始的 drag 不得转化成 Canvas Pan；
- pan 后再拖节点，逆坐标变换仍正确；
- parent-child 连线仍随节点位置实时更新；
- 不引入 Mac/schema/sync 改动。
