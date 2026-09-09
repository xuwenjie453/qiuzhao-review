# 问题二：参考 PDF 排版与字体提示词

请根据用户提供的 PDF 做排版校准，而不是凭感觉增大字号。

## 参考测量

两份参考文件均为 A4 竖版。以 PDF 页面坐标测量并记录：

- 页面宽高；
- 标题左边界、顶部位置、标题高度；
- 正文左右边界；
- 正文行高和段间距；
- 二级标题颜色、左侧竖线宽度和内间距；
- 页码和底部边界。

## 字体

优先明确指定 PingFangSC：

```text
正文：PingFangSC-Regular
一级标题：PingFangSC-Medium/Semibold
二级标题：PingFangSC-Medium
代码：系统等宽字体
```

如果指定字体不存在，必须记录 fallback，而不是默默使用不同字体。

## 排版实现

- 正文、标题和列表使用统一的 TextKit 2 或等价连续排版模型；
- 不要把每段独立 UILabel 的 intrinsic height 当成 PDF 排版；
- 设置明确的 font、line height、paragraph spacing、alignment 和 wrapping；
- 标题左侧竖线不能参与正文宽度计算；
- 保证中文、英文、代码、列表换行稳定；
- 版式参数集中在 `ReaderTypography.referencePDF_v1`，并产生 layout signature。

## 稳定性

同一 node 的 body、font token、page width 不变时，排版 signature 必须稳定。旋转和缩放只改变显示 transform，不能重新生成另一套文字坐标后强行套旧笔迹。

实现后把参考 PDF 渲染图与 Reader 截图并排比较，记录偏差，不以“代码字号为 20pt/34pt”作为验收依据。

