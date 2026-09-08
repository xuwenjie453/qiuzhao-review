# Git / Worktree 安全提示词

实施前：
- `git status --short`
- `git branch --show-current`
- `git log -5 --oneline`
- 记录已有未提交修改。

规则：
- 不覆盖用户已有修改。
- 不执行 `git reset --hard`。
- 不执行无筛选 `git clean -fd/-fdx`。
- 不用大范围 formatter 改无关文件。
- 变更尽量按 Phase 划分。
- 如果需要改 `.gitignore`，只加入运行时生成目录、构建产物、用户本地数据，不误忽略源码/Xcode project。
- 不提交 SQLite 运行库，除非设计明确要求 fixture DB。
- 不提交真实 Pencil/用户隐私内容、局域网设备标识、日志正文。
