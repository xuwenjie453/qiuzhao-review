# 权威、范围与安全提示词

请先建立本次修复的变更边界。

## 允许修改

- `DualEnd-iPad/QiuZhaoReader/Topology/`；
- `DualEnd-iPad/QiuZhaoReader/Reader/`；
- `DualEnd-iPad/QiuZhaoReader/Pencil/`；
- `DualEnd-iPad/QiuZhaoReader/App/` 中与 UI 状态和 mutation reconciliation 直接相关的代码；
- `DualEnd-iPad/QiuZhaoReader/Store/` 中与 pending move、ink layout metadata 直接相关的代码；
- 必要的 iPad 单元测试、UI 测试和开发期诊断代码；
- 若协议确实需要兼容字段，只做向后兼容的 DualEnd schema 迁移。

## 禁止修改

- `scheduler.sqlite3`、`questions.sqlite3`、Knowledge/Algorithms/Projects 学习库；
- Scheduler、Goal、Learning/Review 事件语义；
- QuestionGraph 的 node_id、CENTER/EXPLANATION/TEMPORARY 语义；
- 通过改变 Mac canonical 坐标意义来“适应”iPad；
- 删除测试 round 或正式数据；
- 把 Reader 改成可编辑正文；
- 将页面外背景误标为可写文档页面。

## 变更安全

- 不覆盖未提交的用户修改；
- 修改前建立文件级差异清单；
- 不删除旧 ink；
- 旧 `pkdrawing-v1` 必须继续可读取；
- 新布局版本必须可识别，不能静默把旧笔迹套到新坐标上；
- 所有失败都要保留诊断信息，而不是 catch 后假装成功。

