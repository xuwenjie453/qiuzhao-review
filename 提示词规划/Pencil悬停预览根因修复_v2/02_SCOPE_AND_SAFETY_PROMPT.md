# 范围、安全与不可变数据提示词

## 允许修改范围

优先限制在：

- `DualEnd-iPad/QiuZhaoReader/Reader/AnnotatedReaderView.swift`；
- `DualEnd-iPad/QiuZhaoReader/Reader/ReaderHostView.swift`；
- `DualEnd-iPad/QiuZhaoReader/Pencil/PencilToolController.swift`；
- `DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift`；
- 必要时新增 Reader/Pencil 诊断或纯逻辑测试文件。

## 禁止修改

- 不改 Mac canonical 数据模型、daemon 协议、Bonjour、WebSocket、scheduler 或正式题库。
- 不批量重写、缩放、裁剪或迁移已有 `PKDrawing`。
- 不改变 `pkdrawing-v1`、`node_id`、`ink_revision`、`blob_sha256` 的语义。
- 不用 PDF 图片、截图或假的自绘线条替代 `PKCanvasView`。
- 不把页面正文变成可编辑文本。
- 不通过固定偏移值、不同区域不同偏移、`sleep`/固定几十毫秒延迟掩盖问题。

## 修改前证据

记录：

```text
git status --short
git log -1 --oneline
iPad 型号、iPadOS 版本、Apple Pencil 型号
当前 commit 与安装包 build
```

保存现有真机复现视频或截图路径。若没有实体 Pencil，必须把 hover Gate 标记为 `BLOCKED_BY_DEVICE`。

## 数据安全检查

修复前后比较同一节点：

```text
node_id
ink_revision
blob_sha256
PKDrawing.dataRepresentation() SHA-256
ReaderTypography.layoutSignature
```

差异只能来自用户实际新画的 stroke，不能来自 hover、布局、旋转或缩放。
