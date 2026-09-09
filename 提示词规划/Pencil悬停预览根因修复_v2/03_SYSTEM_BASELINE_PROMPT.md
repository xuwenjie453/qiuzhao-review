# 双端系统基线勘察提示词

在实现前画出系统边界，确认问题是否真的属于 Reader。

## Mac → iPad 数据路径

说明以下链路中每一层的职责，并确认没有屏幕坐标写入协议：

```text
Agent/CLI
→ LocalControl
→ Daemon
→ QuestionGraphService
→ canonical SQLite
→ SyncSession/WebSocket
→ SyncEngine
→ ClientStore cache/outbox
→ AppSessionModel
→ ReaderHostView
```

确认：

- 节点布局只使用 `x_norm/y_norm`；
- Reader 不使用问题图节点布局坐标；
- `PKDrawing` 只按 `node_id` 绑定并以 blob 传输；
- 网络重放不会修改 stroke 点。

## Reader 视图树

输出实际层级：

```text
ReaderHostVC
└─ AnnotatedReaderView
   └─ outer UIScrollView
      └─ contentView (A4 canonical)
         ├─ ReaderPageView / text
         └─ PageCanvasView / PKCanvasView
```

回答：

1. 有几个 `UIScrollView`？
2. 谁负责滚动？谁负责缩放？
3. `contentView`、page、canvas 是否共享 canonical 原点？
4. Canvas 的 `frame/bounds/contentSize/contentOffset/zoomScale` 谁在何时设置？
5. 新节点首次 configure、首次 layout、异步 drawing load 的先后关系是什么？

## 基线输出格式

| 层 | 事实 | 是否涉及屏幕坐标 | 是否可能影响 hover | 证据 |
|---|---|---:|---:|---|

没有运行时数据的项目标记“待验证”，不要把代码意图当成实际状态。
