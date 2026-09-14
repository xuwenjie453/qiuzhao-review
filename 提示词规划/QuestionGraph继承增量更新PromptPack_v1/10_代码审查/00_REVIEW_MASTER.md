# Independent Code Review Master Prompt

你现在不是实现者，而是独立 reviewer。不要因为测试全绿就假设设计正确实现。

## 审查顺序

1. 对照冻结设计与 implementation checklist。
2. 查看完整 diff，不只看新增测试。
3. 从 schema → GraphService → daemon → wire → iPad store → UI → Review integration 追踪一条 shared node 全链路。
4. 主动寻找“复制继承”“隐式 fallback”“revision 只 touch owner”“snapshot apply 误删 shared node”等错误。
5. 运行或复核关键测试。

## 输出严重度

- P0：会造成数据损坏、错误 ownership、silent divergence。
- P1：核心继承语义错误、跨端不一致、migration/recovery 缺陷。
- P2：可观测性、UX、测试缺口。

每条 finding 必须给出具体文件/函数、触发条件、后果和建议修复方向。不要只写风格建议。
