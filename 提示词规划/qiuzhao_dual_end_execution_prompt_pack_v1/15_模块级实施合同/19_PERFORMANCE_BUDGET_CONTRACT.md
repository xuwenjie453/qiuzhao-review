# 性能预算与度量合同

不是绝对毫秒 SLA，但必须以“无边记类直接手写体验”为优化方向。

关键路径：
- Pencil 落笔：PencilKit 直接渲染，不等待 save/network。
- drag：本地 UI 直接动，网络延后。
- App cold start：先 cache，不等待 Bonjour。
- snapshot apply：transaction 后一次更新 UI，避免逐 node 抖动。
- Markdown：避免每次 Ink change 重排正文。
- Ink debounce：300–500ms 仅 I/O。

测量/观察：
- 2 分钟连续书写；
- 长页滚动；
- 50 次 Reader reopen；
- outbox 100 条恢复；
- 100+ nodes（即使典型更少）基本交互不崩。
