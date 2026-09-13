# True Device Acceptance Prompt

此文件只用于真实 Mac + iPad + Apple Pencil 联调。没有真机时标记 NOT_RUN，不得用 simulator 替代。

## 场景

1. 在正式题 B 打开 QuestionGraph。
2. 用户显式把解释 E1 加入图。
3. 在 iPad 打开 E1，写入一段 Pencil Ink；重命名并拖动。
4. 完成学习产生 Capsule，进入 Review A。
5. iPad 打开 A：确认 CENTER_A 与 B 不同；E1 以 inherited Explanation 出现。
6. 双击 A.E1：确认原 Ink 可见。
7. 在 A.E1 追加 Ink、重命名、拖动。
8. 回到 B：确认 title/layout/Ink 均为最新共享状态。
9. 产生第二个 Review C：确认 C 同样看到最新 E1。
10. 在 C 修改 E1，再回 A/B 验证。
11. 测试网络断开/重连后 membership 与 Ink 不丢。
12. 测试 inherited delete 警告，但除非专门验收数据库删除，不建议在主数据上确认删除。

记录每步结果、设备/OS/app commit。失败时保存 daemon log 与 iPad 状态，不要先清数据库。
