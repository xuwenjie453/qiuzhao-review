# Commit & PR Protocol Prompt

保持提交可审查、可回退。

## 建议 commit 分层

1. `test/docs: freeze inheritance contracts and baseline`
2. `feat(mac): add v2 inheritance schema migration`
3. `feat(mac): effective view and shared revision fan-out`
4. `feat(protocol): add owner visibility and inheritance snapshot contract`
5. `feat(ipad): normalize canonical node and graph membership cache`
6. `feat(ipad): inherited node topology and shared delete UX`
7. `feat(review): persist primary source and open inherited review graph`
8. `test: add inheritance cross-layer regression coverage`
9. `docs: update runtime and release acceptance`

实际可合并相邻 commit，但不要一个巨大 commit 包含所有层。

## PR body 必须写

- Why / architecture summary；
- changed schemas + migration path；
- wire version/compatibility；
- effective view/revision fan-out；
- iPad cache normalization；
- Review primary source integration；
- test commands/results；
- true-device status；
- risks/rollback notes。

不要把“tests pass”作为唯一说明。
