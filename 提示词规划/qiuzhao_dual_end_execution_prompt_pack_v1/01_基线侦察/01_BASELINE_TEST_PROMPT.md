# 基线测试 Prompt

在新增双端代码前，找到并运行当前 `qiuzhao-review` 的最低成本自动化测试/完整性检查。

至少尝试：
- Python 单元/E2E 测试（按仓库实际入口）；
- `学习系统/cli.py integrity`（若依赖本地资料缺失，记录真实原因）；
- 关键 import/syntax check。

记录：
- PASS；
- 原本就失败的测试；
- 缺少本地资产导致的 blocked。

目的：后续能判断双端更新是否引入 regression。

禁止为了“让基线绿”而重写原学习算法。
