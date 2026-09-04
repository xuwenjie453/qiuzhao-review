# -*- coding: utf-8 -*-
"""DB 连接、初始化、schema_meta、完整性检查。"""
import os, sqlite3, datetime, hashlib, json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # 复习体系/
from .schema import ALL, SCHEMA_VERSION

DB_QUESTIONS = os.path.join(ROOT, '试题库', 'questions.sqlite3')
DB_MATERIALS = os.path.join(ROOT, '资料库', 'materials.sqlite3')
ENGINE_DBS = {
    'Knowledge': os.path.join(ROOT, 'Knowledge', 'knowledge.sqlite3'),
    'Algorithms': os.path.join(ROOT, 'Algorithms', 'algorithms.sqlite3'),
    'Projects': os.path.join(ROOT, 'Projects', 'projects.sqlite3'),
}
DB_SCHEDULER = os.path.join(ROOT, 'scheduler.sqlite3')

NODES_TABLE = {'Knowledge': 'knowledge_nodes', 'Algorithms': 'skill_nodes', 'Projects': 'engineering_nodes'}
STATES_TABLE = {'Knowledge': 'knowledge_states', 'Algorithms': 'skill_states', 'Projects': 'engineering_states'}


def now() -> str:
    return datetime.datetime.now().astimezone().isoformat(timespec='seconds')


def today() -> str:
    return datetime.date.today().isoformat()


def uid(prefix: str) -> str:
    return f"{prefix}-{hashlib.sha1((now() + str(os.getpid()) + str(id({})) + os.urandom(8).hex()).encode()).hexdigest()[:12]}"


def connect(path: str, init: bool = False) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA foreign_keys = ON')
    if init:
        ddl = ALL[os.path.relpath(path, ROOT).replace(os.sep, '/')]
        conn.executescript(ddl)
        conn.execute("CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        conn.execute("INSERT OR IGNORE INTO schema_meta VALUES ('schema_version', ?)", (SCHEMA_VERSION,))
        conn.execute("INSERT OR IGNORE INTO schema_meta VALUES ('created_at', ?)", (now(),))
        conn.execute("UPDATE schema_meta SET value=? WHERE key='updated_at'", (now(),))
    conn.commit()
    return conn


def init_all() -> list:
    made = []
    for rel in ALL:
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        fresh = not os.path.exists(path)
        c = connect(path, init=True)
        c.close()
        made.append(('created ' if fresh else 'ok     ') + rel)
    return made


def integrity() -> dict:
    out = {}
    for rel in ALL:
        path = os.path.join(ROOT, rel)
        c = sqlite3.connect(path)
        ic = c.execute('PRAGMA integrity_check').fetchone()[0]
        fk = c.execute('PRAGMA foreign_key_check').fetchall()
        ver = c.execute("SELECT value FROM schema_meta WHERE key='schema_version'").fetchone()[0]
        out[rel] = {'integrity': ic, 'fk_violations': len(fk), 'schema_version': ver}
        c.close()
    return out


def attach_questions(conn: sqlite3.Connection, alias: str = 'qb'):
    if os.path.exists(DB_QUESTIONS):
        conn.execute(f"ATTACH DATABASE ? AS {alias}", (DB_QUESTIONS,))


def subcategory_importance(conn: sqlite3.Connection) -> dict:
    """从试题库投影: 各 Knowledge 子类平均星级(1..5)与题数。"""
    attach_questions(conn)
    rows = conn.execute("""
        SELECT
          CASE
            WHEN markdown_path LIKE 'Knowledge/%' THEN substr(markdown_path, 11, instr(substr(markdown_path,11), '/')-1)
            WHEN markdown_path LIKE 'Projects/%' THEN 'P:' || substr(markdown_path, 10, instr(substr(markdown_path,10), '/')-1)
            ELSE 'Algorithms:' || substr(markdown_path, 12, instr(substr(markdown_path,12), '/')-1)
          END AS sub,
          avg(importance) AS imp, count(*) AS n
        FROM qb.questions GROUP BY sub
    """).fetchall()
    return {r['sub']: {'importance': round(r['imp'], 2), 'questions': r['n']} for r in rows}
