# Release Checklist Update Prompt

更新根目录 `双端Release验收清单.md`，新增独立 Section：`QuestionGraph Inheritance / Shared Explanation`。

至少包含：
- Review graph can inherit Question Bank graph；
- own CENTER / inherited Explanation；
- same node_id；
- dynamic parent add；
- child own isolation；
- shared rename/layout/Ink；
- global delete warning；
- graph revision fan-out；
- membership cache recovery；
- v1→v2 migration；
- Review primary source；
- missing parent graceful degradation；
- true-device shared Ink verification。

状态必须基于测试证据。模拟器能证明的写 PASS；真机 Pencil 未跑则写 NOT_RUN；缺外部输入写 BLOCKED_BY_MISSING_INPUT。
