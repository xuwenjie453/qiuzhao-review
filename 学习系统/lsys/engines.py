# -*- coding: utf-8 -*-
"""三引擎公共层: 节点播种、Learning Events、状态投影(可由 Event Replay 重建)。"""
import json
from . import db

PROMPT_VERSION = 'engine-v1'

EVENTS = {
    'Knowledge': ['LEARNING_STARTED', 'BLOCK_PRESENTED', 'RETRIEVAL_SUCCESS', 'RETRIEVAL_PARTIAL',
                  'RETRIEVAL_FAILURE', 'REPAIR_SUCCESS', 'TRANSFER_SUCCESS', 'LEARNING_VERIFIED'],
    'Algorithms': ['SKILL_IDENTIFIED', 'SKILL_REPAIR', 'PATTERN_RECOGNIZED', 'INDEPENDENT_IMPLEMENTATION',
                   'TEST_PASS', 'TRANSFER_PASS', 'LEARNING_VERIFIED'],
    'Projects': ['CASE_ATTEMPT', 'REASONING_SUCCESS', 'TRADEOFF_SUCCESS', 'FAILURE_MODE_SUCCESS',
                 'TRANSFER_CASE_SUCCESS', 'LEARNING_VERIFIED'],
}


# ---------------- 播种(控制层节点, 来自试题库投影; 不写试题库) ----------------
def seed_all():
    """首次初始化: 按试题库子类播种领域级节点。G1~G6 细粒度节点由学习时动态生成。"""
    seeded = []
    kconn = db.connect(db.ENGINE_DBS['Knowledge'])
    qconn = db.connect(db.DB_QUESTIONS)

    # Knowledge: 每个子类一个 G5 Module 节点
    subs = qconn.execute("""SELECT DISTINCT substr(markdown_path, 11, instr(substr(markdown_path,11),'/')-1) AS sub,
                            round(avg(importance),2) AS imp FROM questions
                            WHERE markdown_path LIKE 'Knowledge/%' GROUP BY sub ORDER BY imp DESC""").fetchall()
    for s in subs:
        nid = f"Knowledge/{s['sub']}"
        if kconn.execute("SELECT 1 FROM knowledge_nodes WHERE node_id=?", (nid,)).fetchone():
            continue
        kconn.execute("""INSERT INTO knowledge_nodes
            (node_id,node_type,parent_id,name,engine_type,lifecycle,importance,subcategory,g_level,created_at,updated_at)
            VALUES (?,'G5',NULL,?,'Knowledge','PERSISTENT',?,?,?,?,?)""",
            (nid, f"{s['sub']} 领域模块", s['imp'], s['sub'], 'G5', db.now(), db.now()))
        seeded.append(nid)
    kconn.commit()
    kconn.close()

    # Algorithms: 稳定骨架 7 个 PERSISTENT Component + 各子类 Pattern 节点
    aconn = db.connect(db.ENGINE_DBS['Algorithms'])
    skeleton = [
        ('ProblemInterface', '输入输出与约束建模'), ('PythonTools', 'Python API 工具'),
        ('DataStructures', '数据结构选择与构造'), ('Construction', '结构构造与遍历骨架'),
        ('AlgorithmPatterns', '算法模式识别'), ('ImplementationPatterns', '实现套路与模板'),
        ('DebuggingBoundaries', '边界与调试'),
    ]
    for name, desc in skeleton:
        nid = f'Algorithms/Skeleton/{name}'
        if aconn.execute("SELECT 1 FROM skill_nodes WHERE node_id=?", (nid,)).fetchone():
            continue
        aconn.execute("""INSERT INTO skill_nodes
            (node_id,node_type,parent_id,name,engine_type,lifecycle,skill_class,importance,subcategory,created_at,updated_at)
            VALUES (?,'Component',NULL,?,'Algorithms','PERSISTENT','Component',4.5,NULL,?,?)""",
            (nid, f'{name}: {desc}', db.now(), db.now()))
        seeded.append(nid)
    asubs = qconn.execute("""SELECT DISTINCT substr(markdown_path, 12, instr(substr(markdown_path,12),'/')-1) AS sub,
                             round(avg(importance),2) AS imp FROM questions
                             WHERE markdown_path LIKE 'Algorithms/%' GROUP BY sub""").fetchall()
    for s in asubs:
        nid = f'Algorithms/Pattern/{s["sub"]}'
        if aconn.execute("SELECT 1 FROM skill_nodes WHERE node_id=?", (nid,)).fetchone():
            continue
        aconn.execute("""INSERT INTO skill_nodes
            (node_id,node_type,parent_id,name,engine_type,lifecycle,skill_class,importance,subcategory,created_at,updated_at)
            VALUES (?,'Component','Algorithms/Skeleton/AlgorithmPatterns',?,'Algorithms','PERSISTENT','Component',?,?,?,?)""",
            (nid, f'{s["sub"]} 算法模式', s['imp'], s['sub'], db.now(), db.now()))
        seeded.append(nid)
    aconn.commit()
    aconn.close()
    qconn.close()

    # Projects: 三个项目域 PSB 节点
    pconn = db.connect(db.ENGINE_DBS['Projects'])
    domains = [('ProjectGeneral', '通用工程项目追问', 4.0), ('ProjectRAG', 'RAG 项目', 4.2), ('ProjectAgent', 'Agent 项目', 4.2)]
    for sub, name, imp in domains:
        nid = f'Projects/{sub}'
        if pconn.execute("SELECT 1 FROM engineering_nodes WHERE node_id=?", (nid,)).fetchone():
            continue
        pconn.execute("""INSERT INTO engineering_nodes
            (node_id,node_type,parent_id,name,engine_type,lifecycle,importance,subcategory,created_at,updated_at)
            VALUES (?,'PSB',NULL,?,'Projects','PERSISTENT',?,?,?,?)""",
            (nid, f'{name}(Project Solution Block)', imp, sub, db.now(), db.now()))
        seeded.append(nid)
    pconn.commit()
    pconn.close()
    return seeded


# ---------------- Learning Events + 状态投影 ----------------
def add_event(engine: str, target_id: str, event_type: str, session_id: str | None = None,
              question_id: str | None = None, result: str | None = None,
              evidence: dict | None = None, occurred_at: str | None = None) -> str:
    if event_type not in EVENTS[engine]:
        raise ValueError(f'{engine} 非法事件: {event_type}')
    path = db.ENGINE_DBS[engine]
    conn = db.connect(path)
    try:
        eid = db.uid('ev')
        occurred = occurred_at or db.now()
        conn.execute("""INSERT INTO learning_events(event_id,occurred_at,session_id,target_id,event_type,question_id,result,evidence_json,prompt_version,created_at)
                        VALUES (?,?,?,?,?,?,?,?,?,?)""",
                     (eid, occurred, session_id, target_id, event_type, question_id, result,
                      json.dumps(evidence, ensure_ascii=False) if evidence else None, PROMPT_VERSION, db.now()))
        _project_state(conn, engine, target_id, event_type, result, occurred)
        conn.commit()
        return eid
    finally:
        conn.close()


def _project_state(conn, engine, target_id, event_type, result, occurred):
    """Current State = Events 的投影缓存, 可删除后由 rebuilder 重建。"""
    table = db.STATES_TABLE[engine]
    row = conn.execute(f"SELECT * FROM {table} WHERE target_id=?", (target_id,)).fetchone()
    status = row['status'] if row else 'UNSEEN'
    fc = row['failure_count'] if row else 0
    rc = row['repair_count'] if row else 0
    first = row['first_learned_at'] if row else None
    if event_type in ('LEARNING_STARTED', 'SKILL_IDENTIFIED', 'CASE_ATTEMPT', 'BLOCK_PRESENTED'):
        status = 'LEARNING' if status == 'UNSEEN' else status
    if result == 'failure':
        fc += 1
    if event_type in ('REPAIR_SUCCESS', 'SKILL_REPAIR'):
        rc += 1
    if event_type == 'LEARNING_VERIFIED':
        status = 'LEARNING_VERIFIED'
    if row:
        conn.execute(f"""UPDATE {table} SET status=?, last_event_at=?, event_count=event_count+1,
                         failure_count=?, repair_count=?, updated_at=? WHERE target_id=?""",
                     (status, occurred, fc, rc, db.now(), target_id))
    else:
        conn.execute(f"""INSERT INTO {table}(target_id,engine_type,status,first_learned_at,last_event_at,event_count,
                         failure_count,repair_count,updated_at) VALUES (?,?,?,?,?,1,?,?,?)""",
                     (target_id, engine, status, occurred, occurred, fc, rc, db.now()))


def create_dynamic_node(engine: str, name: str, node_type: str, parent_id: str | None = None,
                        subcategory: str | None = None, g_level: str | None = None,
                        lifecycle: str = 'TEMPORARY', summary: str | None = None,
                        psb: dict | None = None) -> str:
    """学习时动态生成细粒度节点(如 G1~G4 知识块 / 临时技能 / PSB 维度)。"""
    path = db.ENGINE_DBS[engine]
    conn = db.connect(path)
    try:
        table = db.NODES_TABLE[engine]
        nid = f'{engine}/{name}'
        if conn.execute(f"SELECT 1 FROM {table} WHERE node_id=?", (nid,)).fetchone():
            return nid
        cols = ['node_id', 'node_type', 'parent_id', 'name', 'engine_type', 'lifecycle',
                'importance', 'subcategory', 'created_at', 'updated_at']
        vals = [nid, node_type, parent_id, name, engine, lifecycle, 3.5, subcategory, db.now(), db.now()]
        if engine == 'Knowledge':
            cols.insert(8, 'g_level'); vals.insert(8, g_level)
        elif engine == 'Algorithms':
            cols.insert(8, 'skill_class'); vals.insert(8, 'Component')
        elif engine == 'Projects':
            cols.insert(8, 'psb_json'); vals.insert(8, json.dumps(psb, ensure_ascii=False) if psb else None)
        conn.execute(f"INSERT INTO {table}({','.join(cols)}) VALUES ({','.join('?' * len(vals))})", vals)
        conn.commit()
        return nid
    finally:
        conn.close()
