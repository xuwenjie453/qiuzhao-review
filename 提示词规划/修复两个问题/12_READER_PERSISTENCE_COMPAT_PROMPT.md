# 问题二：排版版本与 Ink 持久化兼容提示词

请在 Reader 版式重构中保护已有 Apple Pencil 笔迹。

## 数据不变量

- body 仍 immutable；
- drawing 仍按 node_id 绑定；
- 旧 `pkdrawing-v1` 仍然可读取；
- 不因为页面分页而丢失旧 drawing；
- layout 变化必须可检测。

## layout signature

为 Reader 排版生成稳定 signature，至少包含：

```text
body hash
page size
body column width
font family/token version
font sizes
line height
paragraph spacing
renderer version
```

如果 signature 未变化，直接复用旧页面坐标。如果只是横竖屏、滚动或缩放，禁止迁移 drawing。

## 多页批注策略

可以采用以下任一兼容实现，但必须保留旧数据：

1. 维持一个 document-space PKDrawing，并以页面 origin 组织多页；
2. 按 pageIndex 保存多个 Drawing，再提供旧格式迁移；
3. 以可逆容器封装多个页面 Drawing，并明确 `format` 版本。

选择后说明：读取旧数据如何处理、上传 Mac 的格式是否兼容、失败如何回退。

## 禁止

- 仅因为新页面宽度不同就把旧笔迹直接按屏幕宽度缩放；
- 无 signature 检查地强行套旧 drawing；
- 把 drawing 当成正文的一部分重新生成；
- 删除旧 ink_cache 或服务器 ink。

