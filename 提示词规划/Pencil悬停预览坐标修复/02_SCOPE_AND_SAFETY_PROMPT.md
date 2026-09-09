# 范围与安全提示词

## 允许修改范围

优先限制在：

- `DualEnd-iPad/QiuZhaoReader/Reader/AnnotatedReaderView.swift`
- `DualEnd-iPad/QiuZhaoReader/Reader/ReaderHostView.swift`（仅处理初始化时序时）
- `DualEnd-iPad/QiuZhaoReader/Pencil/PencilToolController.swift`（仅有明确证据时）
- `DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift`
- 必要时新增 Reader/Pencil hover 纯逻辑测试文件。

## 禁止事项

- 不修改正式题库、scheduler、学习事件和 Goal。
- 不修改 Mac 端 canonical 数据模型和双端协议。
- 不修改 PKDrawing 序列化格式和历史笔迹。
- 不批量重写或删除 ink 数据。
- 不将实际落笔路径改为自绘假的 Pencil 线条。
- 不通过固定右下补偿值掩盖位置相关的缩放错误。

## 修改前检查

执行并记录：

```bash
git status --short
git log -1 --oneline
rg -n "UIPencil|hover|PKCanvasView|PKDrawing|zoomScale|contentOffset|transform|contentInset" DualEnd-iPad/QiuZhaoReader
```

保存现有真机复现视频、截图或日志路径。所有新改动必须可由 `git diff` 清晰解释。

## 回滚

每次只修改一个层次：诊断、时序、矩阵或测试。失败时保留日志，只回退当前层次，不使用 `git reset --hard`。
