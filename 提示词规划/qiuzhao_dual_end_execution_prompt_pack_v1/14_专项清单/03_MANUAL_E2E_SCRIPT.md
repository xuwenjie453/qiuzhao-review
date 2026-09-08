# 手工端到端验收脚本

1. Mac 启动原学习会话和 DualEnd daemon。
2. iPad App 冷启动，同 LAN，无任何 IP/验证码操作。
3. iPad 自动进入 Connected。
4. Agent 打开正式试题 → iPad 自动出现 CENTER。
5. Agent 给普通解释 → 图不变化。
6. 用户明确“把刚才这段加入问题图” → 圆形节点出现，body 原文。
7. 用户明确“这段临时放进去” → 三角节点出现。
8. iPad 单击圆节点改标题。
9. 长按拖动，重启 App 后位置存在。
10. 双击进入 Reader。
11. Pencil 书写，滚动长页，笔迹对齐。
12. 支持型号 Pencil 双击 → eraser，再双击回 ink。
13. 断 Wi-Fi，继续改标题/写字。
14. 恢复 Wi-Fi，自动重连并同步。
15. Agent close 当前问题，再重开同一问题：
    - 圆节点仍在；
    - 上一轮三角节点不在；
    - 圆节点笔迹仍在。
16. CENTER 尝试删除：
    - UI 无入口；
    - 构造协议命令 server 也拒绝。
17. 退出/kill iPad App，重开：
    - cache 与 Ink 保留。
