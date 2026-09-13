# 执行 AI 工作规则

1. 每次修改前先读完整相关文件，不要只按提示词盲改。
2. 如源码已变化，以当前源码为准。
3. 每次只解决一个阶段目标。
4. 测试失败时不要通过放宽断言掩盖。
5. 不删除真实用户数据。
6. 不使用 kill -9 作为正常 daemon 重启手段。
7. 每个新 watchdog 必须说明 owner、取消条件、epoch 归属。
8. 所有 callback 必须检查对象 identity 或 epoch。
9. 所有 duplicate message 处理必须证明 exactly-once effect。
10. 最终报告区分 FACT / INFERENCE / UNKNOWN。
