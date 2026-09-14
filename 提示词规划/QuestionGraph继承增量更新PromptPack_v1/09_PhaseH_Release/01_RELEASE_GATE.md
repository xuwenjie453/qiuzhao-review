# Release Gate Prompt

逐项给出 PASS / FAIL / BLOCKED / NOT_RUN，不允许模糊表述。

## A. Canonical
- schema v2 migration PASS；
- graph_inheritance FK/index PASS；
- owner/visibility separation PASS；
- same node identity across graphs PASS；
- dynamic parent Explanation inheritance PASS。

## B. Mutation
- rename shared write-through PASS；
- move shared write-through PASS；
- delete shared global semantics PASS；
- Ink shared node_id PASS；
- CAS/dedup old invariants PASS。

## C. Revision/Sync
- affected graph revision fan-out PASS；
- Ink no graph_revision PASS；
- patch base mismatch recovery PASS；
- reconnect snapshot membership recovery PASS；
- durable-before-ACK/emit PASS。

## D. Review lifecycle
- capsule primary source PASS；
- no `source_questions[0]` inference PASS；
- Review open inheritance PASS；
- legacy/null primary Review PASS；
- missing parent graph Review PASS。

## E. iPad
- membership normalization PASS；
- inherited UX PASS；
- shared delete warning PASS；
- Reader shared Ink PASS；
- build/unit PASS。

## F. Regression
- original Mac tests PASS；
- original Learning E2E PASS；
- old graph without inheritance unchanged PASS。
