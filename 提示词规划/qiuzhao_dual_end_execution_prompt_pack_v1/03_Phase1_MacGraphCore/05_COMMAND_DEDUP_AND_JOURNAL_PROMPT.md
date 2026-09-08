# Command Dedup + Sync Journal

## 任务目标
建立 at-least-once 语义所需的服务端幂等与 server_seq。

## 必读设计稿
- `90_设计稿基线/02_Mac端/04_存储与数据库.md`
- `90_设计稿基线/03_协议与同步/02_WebSocket协议总则.md`

## 必须满足
- command_id unique。
- 重复 command 返回第一次 canonical result。
- journal 与 mutation 同 transaction。
- server_seq monotonic。

## 实施步骤
1. 封装 executeCommand transaction。
2. 记录 result_json。
3. 设计 journal event payload 可供 bridge replay。

## 测试要求
- duplicate add one node
- duplicate delete one effect
- server_seq monotonic
- rollback 不留 dedup 半记录

## 完成报告
完成后在实施状态中记录：
- 修改/新增文件；
- 执行的测试命令；
- PASS / FAIL / BLOCKED；
- 任何偏离建议文件名但不偏离契约的实现映射；
- 尚未解决但不阻塞下一任务的问题。
