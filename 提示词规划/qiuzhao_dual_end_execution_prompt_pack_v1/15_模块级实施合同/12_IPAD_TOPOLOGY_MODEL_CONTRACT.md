# QuestionGraphModel / Topology 合同

数据：
- current snapshot；
- node selection；
- transient drag position；
- pinned persisted layout。

布局：
- center (0.5,0.5)；
- golden-angle deterministic slots；
- persisted x/y normalized；
- user drag completion 后 local durable + outbox；
- drag 过程中可本地 60fps，不要求每帧发网络。

手势：
- single → manage sheet；
- double → Reader；
- long press then drag → move；
- drag 不触发 navigation。

UI：
- CENTER square；
- EXPLANATION circle；
- TEMPORARY triangle；
- title above；
- center delete action absent。
