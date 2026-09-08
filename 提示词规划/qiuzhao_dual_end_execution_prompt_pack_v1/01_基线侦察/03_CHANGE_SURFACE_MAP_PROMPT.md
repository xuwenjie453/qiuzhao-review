# Change Surface Map Prompt

根据实际仓库生成最终改造映射，至少覆盖：

- 根 AGENTS.md
- 根 README.md
- RuntimePrompt V1
- 可选 Python `dual_end_adapter.py`
- DualEnd-Mac/
- DualEnd-iPad/
- 系统数据/dual-end/ runtime path
- .gitignore
- tests / fixtures / scripts

为每个目标文件标：
- CREATE / MODIFY / NO_CHANGE
- owner module
- Phase
- 对应设计稿章节
- 测试覆盖

如果建议文件名与实际仓库惯例冲突，可以改名，但逻辑边界不能混。
