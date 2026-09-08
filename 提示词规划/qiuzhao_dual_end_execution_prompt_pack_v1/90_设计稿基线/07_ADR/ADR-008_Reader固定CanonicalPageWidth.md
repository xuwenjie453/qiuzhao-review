# ADR-008：Reader 使用稳定 canonical page width

Status: Accepted

Ink 是页面坐标数据。若旋转/窗口宽度变化导致 Markdown 大规模重排，旧 Ink 会错位。因此正文 column 使用固定/受控 canonical width；更宽屏幕增加外围留白，而不是无限扩正文。

参考 PDF 提供后，只校准 typography tokens 和 canonical width。
