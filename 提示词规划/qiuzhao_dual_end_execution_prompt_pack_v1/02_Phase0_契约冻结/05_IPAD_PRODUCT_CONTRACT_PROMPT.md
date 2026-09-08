# iPad App 产品契约冻结

## 任务目标
在创建 Xcode 工程前固定 iPad 是 Reader、不是第二聊天端。

## 必读设计稿
- `90_设计稿基线/04_iPad端/01_iPad应用架构.md`
- `90_设计稿基线/04_iPad端/02_问题图Topology设计.md`
- `90_设计稿基线/04_iPad端/03_Markdown阅读器.md`
- `90_设计稿基线/04_iPad端/05_ApplePencil与Ink.md`

## 必须满足
- 必须是独立完整 iPadOS app。
- 两层 UI：Topology → Reader。
- 正文只读；title/layout/delete/ink 为用户可变域。
- 缓存优先；Mac 离线不空白。
- 无正常流程 pairing/IP UI。

## 实施步骤
1. 写 app module map 和 navigation contract。
2. 冻结最低部署目标：以当前 Xcode/SDK 与仓库兼容性为准，不凭空锁过新版本；记录实际值。
3. 冻结 bundle/product 名称为工程内部可改项，不把命名争论阻塞功能。
4. 列出真机 Gate 与 Simulator 可测范围。

## 测试要求
- Xcode project 可打开；真实 Reader/Pencil path 不得用静态 mock 代替

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
