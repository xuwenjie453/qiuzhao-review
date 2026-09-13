# Topology Inherited Node UX Prompt

修改 Topology 时保持现有 Question-first 视觉体系。

## 展示

Inherited Explanation：
- `kind == EXPLANATION`；
- 圆形保持不变；
- 可通过小型链路/继承 badge 区分 `visibility == INHERITED`；
- 不把 owner graph CENTER 画进 child graph；
- 低强调连接线连向当前 child CENTER，仅表示“当前图可访问”。

## 拖动

拖动 inherited E1：
- 本地 optimistic layout 修改 canonical E1；
- outbox payload 带当前 view graph A；
- server 成功后 parent/sibling snapshot 都应看到相同 layout。

不要实现 child-local position override。

## Rename

管理 sheet 可重命名 inherited node，仍使用 canonical node_revision CAS。可以显示“共享节点”说明，但不需要复制节点。

## 状态恢复

若 server 返回 CAS mismatch 或 command reject：
- 不吞错误；
- 请求/采用 canonical state；
- 保留必要用户草稿；
- 不创建临时 copy 规避冲突。
