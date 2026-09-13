# Mac 新增测试

至少新增：

1. `journalReplayable same message twice`
   - 两次返回同 server_seq。
   - 第二次 replay=true。

2. `same message_id different payload`
   - 必须失败，不能静默 ACK。

3. `CLIENT_COMMAND replay`
   - effect 只发生一次。
   - 第二次仍产生 ACK。

4. `INK_PUT replay`
   - ink effect 一次。
   - 第二次补 ACK。

5. `WELCOME 100 reconnects`
   - 无固定 ID 冲突。

6. `ACK loss simulation`
   - 第一次 server commit 后丢弃 ACK。
   - 第二次 replay 后补 ACK。
