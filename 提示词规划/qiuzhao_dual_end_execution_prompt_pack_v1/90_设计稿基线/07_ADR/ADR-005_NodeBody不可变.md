# ADR-005：Node Body commit 后不可变

Status: Accepted

## Decision

Center/Explanation/Temporary 的 body 在 node 创建后不允许编辑；title 独立可变。

## Rationale

用户明确正文一旦确定不变化，且整个页面可写 Ink。Body immutability 是 Ink 坐标稳定的基础，不只是权限 UI。

## Enforcement

API 不提供 update body + DB trigger 双保险。
