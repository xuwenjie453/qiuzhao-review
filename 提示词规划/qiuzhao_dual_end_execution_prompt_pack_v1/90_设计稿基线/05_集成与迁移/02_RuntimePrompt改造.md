# Runtime Prompt 改造设计

## 1. 新增文件

建议在现有 RuntimePrompt V1 增加：

`21_双端问题图与iPad协作协议.md`

并在入口/总控 Prompt 引用它。

## 2. 内容骨架

```text
A. Question-first 双端定义
B. 何时 open/close
C. 用户显式入图判断
D. persistent vs temporary
E. 被选解释必须原文入 body
F. title 由当前 Agent 生成
G. daemon CLI 用法
H. daemon failure 不阻断学习
I. 禁止事项
```

## 3. Agent 判断模板

接收到类似“把刚才第二个解释放进图里”时：

1. 从当前对话定位**唯一** assistant explanation span；
2. 判断用户是否要 persistent 或 temporary；
3. 生成简短 title；
4. 调用 CLI；
5. 只有 CLI 成功后，才对用户确认已加入。

如果“哪个解释”真的无法唯一定位，Agent 才应在聊天中做最小澄清；不要把两个解释都加。

## 4. 问题切换纪律

Agent 不得同时维持两个 active round。打开新问题前 daemon 会自动 interrupt 旧 round，但 Runtime 应正常显式 close，便于语义清晰。
