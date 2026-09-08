# Protocol mismatch

不要“兼容到能跑”为目标而吞字段。

步骤：
- 对照 Phase0 fixtures；
- 对照 Node encoder/decoder；
- 对照 Swift encoder/decoder；
- 检查 version/session_epoch/revisions；
- 新 optional field可以兼容；
- 改语义/删除字段必须 bump version。

先修契约或实现的一端，不让双端各自加特殊 case。
