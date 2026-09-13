#!/usr/bin/env python3
"""v3 包 09 号：离线播种 client-store —— 模拟器无 daemon/Bonjour 环境下端到端复现问题图→Reader。
用法: python3 seed_offline_store.py <输出路径/client-store.sqlite>
表结构须与 QiuZhaoReader/Store/ClientStore.swift 的 ClientStore.schema 一致。"""
import sqlite3, sys, datetime

out = sys.argv[1] if len(sys.argv) > 1 else "client-store.sqlite"
now = datetime.datetime.now().isoformat()

GRAPH_ID = "seed-graph-offline"
CENTER_ID = "seed-center"
EXPL_ID = "seed-explanation"

long_markdown = """## 离线播种 · 冒烟文档

本节点由 seed_offline_store.py 生成，用于在无 daemon 环境验证双击进 Reader、适宽缩放、纵向滚动与 Pencil 输入路径。

### 1. 单一显示变换

Canvas 是唯一滚动/缩放 owner：

```text
screen(P) = P · z − contentOffset
```

正文镜像层与 PencilKit 实时/提交渲染共享同一变换。

### 2. 长文分页压力

""" + "\n".join(
    f"第 {i} 段：两套视口基准是 hover 偏移的根因；消除双重缩放结构后，悬停预览、书写中墨迹与历史笔迹共享同一仿射。"
    for i in range(1, 91)
) + """

### 3. 列表与代码

- 列表项一：canonical 坐标永不变
- 列表项二：contentSize 使用 display 单位
- 列表项三：手指滚动，Pencil 书写

```python
def fit_width(viewport, page=595.92):
    return viewport / page
```

> 引用块：修复不做坐标补偿，不迁移历史笔迹。
"""

conn = sqlite3.connect(out)
c = conn.cursor()
c.executescript("""
CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS daemon_identity(daemon_id TEXT PRIMARY KEY, last_seen_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS graphs_cache(
  graph_id TEXT PRIMARY KEY, question_key TEXT NOT NULL, round_id TEXT,
  revision INTEGER NOT NULL, center_node_id TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS nodes_cache(
  node_id TEXT PRIMARY KEY, graph_id TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL,
  body_markdown TEXT NOT NULL, node_revision INTEGER NOT NULL,
  x_norm REAL NOT NULL, y_norm REAL NOT NULL, layout_revision INTEGER NOT NULL,
  locally_deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS ink_cache(
  node_id TEXT PRIMARY KEY, ink_revision INTEGER NOT NULL DEFAULT 0, format TEXT NOT NULL,
  blob BLOB, blob_sha256 TEXT, dirty INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS active_state(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS inbox_dedup(message_id TEXT PRIMARY KEY, kind TEXT NOT NULL, applied_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS outbox(
  outbox_id TEXT PRIMARY KEY, message_id TEXT NOT NULL UNIQUE, kind TEXT NOT NULL,
  entity_id TEXT NOT NULL, payload_json TEXT NOT NULL, created_at TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0, last_attempt_at TEXT,
  state TEXT NOT NULL DEFAULT 'PENDING');
""")
c.execute("INSERT OR REPLACE INTO graphs_cache VALUES (?,?,?,?,?,1,?)",
          (GRAPH_ID, "seed:offline-smoke", "seed-round", 1, CENTER_ID, now))
c.execute("INSERT OR REPLACE INTO nodes_cache VALUES (?,?,?,?,?,1,?,?,?,0,?)",
          (CENTER_ID, GRAPH_ID, "CENTER", "离线冒烟 · 题目中心",
           "## 冒烟探针\n\n1. 双击本节点应进入 Reader。\n2. 页面适宽、可纵向滚动。", 0.5, 0.5, 1, now))
c.execute("INSERT OR REPLACE INTO nodes_cache VALUES (?,?,?,?,?,1,?,?,?,0,?)",
          (EXPL_ID, GRAPH_ID, "EXPLANATION", "单一变换长文（多页）",
           long_markdown, 0.82, 0.46, 1, now))
conn.commit()
conn.close()
print(f"seeded: {out}")
