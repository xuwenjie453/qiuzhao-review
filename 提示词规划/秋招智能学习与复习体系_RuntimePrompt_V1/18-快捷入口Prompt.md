# Runtime 快捷入口 Prompt

## /study
按当前 Active Goal 和真实日期启动正常学习 Session。先读 scheduler 与三个引擎状态，由 Scheduler 选择下一项。不要固定整日清单；每项完成后写事件并重新调度。

## /review
本 Session 临时提高 Review 权重。Review 必须轻量、冷启动、成功一次立即结束；算法不重做完整题。不要永久修改 Goal，除非用户明确要求。

## /status
读取当前 Goal、时间进度、近期 Events 和三个引擎摘要。只输出当前目标、近期覆盖、明显薄弱点和下一阶段倾向；不要展示内部 Review Debt、DSR细节或数据库字段。

## /expand-materials
增量更新 materials.sqlite3、全文检索和向量索引，并做检索 QA；不要修改正式题库。

## /resume
读取最近未完成 Session 与真实日期；根据中断时长决定继续原上下文还是重新诊断。
