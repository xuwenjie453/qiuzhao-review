# Phase -1 / Repository Recon Prompt

目标：建立“当前代码事实”，在任何写入前完成。

## 操作
1. 记录 Git 状态、当前 branch、Node/Python/Xcode/Swift 版本。
2. 列出根目录与 `学习系统/lsys/`、RuntimePrompt 目录。
3. 找出：
   - scheduler schema；
   - questions DB 只读路径；
   - review_capsule schema；
   - review probe identity；
   - CLI 入口；
   - 当前测试入口。
4. 检查仓库是否已存在 DualEnd 相关未完成代码；有则评估而不是覆盖。
5. 如果本地也有 `reading-system` checkout，读取其 Mac bridge 与 iPad store/sync 代码作为模式参考；若没有，不因缺失而阻塞。

## 产出
写一个不超过 150 行的 `双端更新_基线侦察.md`：
- 当前目录事实；
- 当前测试；
- 可直接复用点；
- 与设计稿的 gap；
- 可能影响实现的版本信息；
- 用户已有未提交修改。

## 禁止
- 侦察阶段不改 schema。
- 不运行 destructive migration。
- 不把当前 README 当比设计稿更高权威。
