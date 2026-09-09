# 范围、数据边界与安全提示词

在修改代码前，先完成检查并写入阶段报告。

## 允许修改范围

优先限制在：

- `DualEnd-iPad/QiuZhaoReader/Reader/AnnotatedReaderView.swift`
- `DualEnd-iPad/QiuZhaoReader/Reader/ReaderTypography.swift`
- `DualEnd-iPad/QiuZhaoReader/Reader/ReaderHostView.swift`（确有必要时）
- `DualEnd-iPad/QiuZhaoReaderTests/QiuZhaoReaderTests.swift`
- 必要时新增 Reader 视口纯逻辑测试文件。

## 明确禁止

- 不修改 `scheduler.sqlite3`、`questions.sqlite3`、Goal、调度或学习事件。
- 不修改 Mac canonical 图结构协议，不重命名 node_id。
- 不改变 `pkdrawing-v1` 编码、数据库字段和 revision 语义。
- 不把页面截图或 PDF 图片作为替代交互实现。
- 不新增平行 Web 前端或桌面阅读器。
- 不为通过测试而删除既有测试。

## 数据安全检查

执行：

```bash
git status --short
git log -1 --oneline
rg -n "pkdrawing-v1|PKDrawing|ink_revision|node_id" DualEnd-iPad/QiuZhaoReader
```

确认不需要数据库迁移后才能继续。

## 回滚策略

每个阶段只做一组相关改动。测试失败时保存日志，只回退当前阶段改动；不得使用 `git reset --hard`，不得覆盖用户已有未提交改动。
