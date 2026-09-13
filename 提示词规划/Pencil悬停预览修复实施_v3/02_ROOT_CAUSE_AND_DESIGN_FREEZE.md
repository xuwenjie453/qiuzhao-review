# 根因与设计冻结（不得重新设计）

本文件冻结两件事：根因结论（WHY）与目标架构契约（WHAT）。实施细节见 `05`。执行 AI 可以在 Phase 0 用数据**证伪**根因（触发停止闸门），但不可以修改设计本身。

## 一、根因冻结

### 症状 → 机制映射

| 用户确认的症状 | 机制解释 |
|---|---|
| 悬停预览偏离笔尖 | hover 预览由 PencilKit **实时渲染路径**绘制，几何基准取自 `canvas.zoomScale` |
| 书写中墨迹也错位 | 未提交笔迹同样在实时路径（live 图层），同一错误基准 |
| Pencil 远离屏幕后笔迹归位 | 近屏会话结束，live 图层内容冲刷进**提交路径**（tile 渲染，跟随真实 layer 树）重渲，位置正确 |
| 抬笔不归位、远离才归位 | live 图层在整个近屏会话期间存续，会话结束才 flush |
| 数据始终正确（重开/同步正常） | 触点→PKDrawing 数据走 UIKit 标准坐标转换（正确合成祖先变换），与实时渲染层无关 |
| 第一轮补丁（Canvas 内部状态归零）无效 | 根因是**结构关系**（祖先 ×2 变换 + zoomScale 未同步），不是 Canvas 内部状态脏；`zoomScale=1` 钳位反而把失配固化 |
| 方向规律未确认 | 偏移 ΔP = (S′−S)·P + (O′−O)。S′≠S → 偏移随位置线性变化并在锚点两侧反向；S′=S、O′≠O → 恒定平移。两者同属“基准分裂”家族，具体参数由 Phase 0 测定 |

### 旧架构的坐标链（现状，将被替换）

```text
scroll: UIScrollView（缩放 owner，zoomScale≈2.0 横屏适宽）
└── contentView（A4 canonical 595.92×842.88）
    ├── ReaderPageView × N（正文）
    └── canvas: PKCanvasView（钉在 contentView 内，zoomScale 锁 1）
```

三条链路命运：数据链路 ✅（标准转换）；提交渲染 ✅（tile 在 layer 树内随祖先变换）；**实时渲染 ❌（以 zoomScale=1 为基准，被祖先 ×2 叠加摆放 → 分裂）**。

## 二、路线决策冻结（为什么不是“同步 zoomScale 补丁”）

保留外层缩放、只同步 `canvas.zoomScale = 外层 zoomScale` 在几何上不可能自洽：Canvas frame 保持 canonical（595.92），`zoomScale=2` 使 PencilKit 在 Canvas **自身 bounds 内**以 2 倍渲染（内容 1191.84 溢出被裁剪），祖先再 ×2 → 页面左上四分之一的二次放大。**“祖先变换 + zoomScale 同步”两个机制叠加使用必然有一个错**——这正是私有语义雷区。因此唯一结构正确的方案：

> **路线 B（冻结采用）：PKCanvasView 自己成为唯一滚动/缩放视口，Canvas 之上不存在任何祖先缩放变换。**

此时 PencilKit 的内置假设“我自身的 zoomScale 就是全部显示变换”**按构造成立**，实时路径与提交路径共享同一基准，分裂从结构上消失。

## 三、目标架构契约

### 3.1 视图层级（冻结）

```text
AnnotatedReaderView（autolayout 钉满 ReaderHostVC.view）
├── contentView（文档镜像层：非交互兄弟层，isUserInteractionEnabled=false）
│   └── ReaderPageView × N（页内 autolayout，canonical 坐标）
└── canvas: PageCanvasView（autolayout 钉满自身四边）
```

### 3.2 唯一变换不变量（冻结）

全 Reader 只允许一条 canonical → 屏幕映射：

```text
screen(P) = P · z − contentOffset
    P = canonical 页面点（595.92×842.88 系，永不改变）
    z = canvas.zoomScale（横屏适宽 ≈ 2.0）
```

两个参与方各自实现这条映射：

| 对象 | 实现方式 |
|---|---|
| Canvas（悬停预览 + 书写墨迹 + 提交笔迹） | `zoomScale = z`；PencilKit 以 z 为基准排布内容；数据 canonical |
| contentView（正文镜像层） | `bounds.size = documentSize`；`layer.anchorPoint = (0,0)`；`layer.position = −contentOffset`；`layer.transform = scale(z)` |

代入验证：canonical P 经镜像层 = `position + P·z = P·z − contentOffset` ✓ 与 Canvas 一致。**正文、提交笔迹、实时笔迹、悬停预验四者共享同一仿射——根因消除的证明。**

### 3.3 属性所有权表（冻结，每行只有一个写入者）

| 属性 | 唯一写入者 | 写入时机 |
|---|---|---|
| `canvas.zoomScale` / min / max | `applyViewport()` | 初次布局、旋转/尺寸变化 |
| `canvas.contentSize` | `applyViewport()`，**display 单位 = documentSize × z** | 同上；drawing 异步装载不触碰几何 |
| `canvas.contentOffset` | 用户滚动；`applyViewport()` 负责夹取 | 滚动中只镜像不修正（x 归零除外） |
| `contentView.bounds.size` | `renderDocument()`（canonical） | 构建时一次 |
| `contentView.layer.position / transform` | `syncDocumentMirror()` | 每次 scroll / zoom / 渲染完成 / 布局兜底 |
| 页面内文字布局 | contentView 内部 autolayout | 构建时一次 |
| PKDrawing 数据 | 仅 `loadInk()` 装载与用户书写 | 永不因视口操作改写 |

### 3.4 坐标换算基准（冻结，附防误改理由）

- `hitTest` 的 point 与 `location(in:)` 同处 canvas **bounds 坐标系**，该系原点已随 contentOffset 移动（UIScrollView 的 bounds.origin == contentOffset）→ canonical 换算**只除 zoomScale，不再加 contentOffset**：`canonical = point / z`。
- `allowedPageRects` 为 canonical 页矩形。
- 镜像层 `layer.position` 在父层（AnnotatedReaderView.layer）坐标系，canvas 钉边后两者同系，直接用 `−contentOffset`。

### 3.5 不变量回归（冻结）

- 两代架构的 PKDrawing 数据同为 canonical → **历史笔迹零迁移、必须真机实证对齐**（Phase 3 第一项）。
- hover / 滚动不产生 ink revision、outbox、网络发送。
- `layoutSignature` 不含任何显示缩放或屏幕尺寸。
