# -*- coding: utf-8 -*-
"""Goal Compiler: 自然语言目标 → 结构化 Goal(不排每日任务)。属 Expansion Hub。"""
import json, datetime, re, sqlite3
from . import db


INTENT_WORDS = {
    'coverage': ['覆盖', '广', '铺开', 'coverage'],
    'acquisition': ['学会', '掌握', '学', 'acquisition'],
    'sprint': ['冲刺', '快速', 'sprint', '面试前'],
    'reactivation': ['捡起', '重拾', 'reactivation', '恢复'],
    'maintenance': ['保持', '维护', 'maintenance'],
    'mastery': ['精通', '深入', 'mastery', '扎实'],
}
ENGINE_WORDS = {
    'Knowledge': ['知识', '八股', '概念', '知识点'],
    'Algorithms': ['算法', '手撕', '刷题', '编程'],
    'Projects': ['项目', '工程', '系统设计', '场景'],
}
SUBCLASS_WORDS = ['MySQL', 'Redis', 'Java', 'JVM', 'JUC', 'Spring', '操作系统', 'OperatingSystems',
                  '网络', 'ComputerNetworks', '数据结构', 'DataStructures', 'RAG', 'Agent', 'MCP',
                  'AI', 'MQ', 'Docker', 'Linux', 'Git', 'SQL', '机器学习', '深度学习']

BASE_POLICY = {  # 相对权重, 可版本化调参
    'coverage': 1.0, 'retention': 0.6, 'weakness': 0.6, 'importance': 1.0,
    'temporal_urgency': 0.8, 'diversity': 0.5, 'transfer': 0.4, 'new_learning': 1.0,
    'desired_retention_early': 0.80, 'desired_retention_late': 0.90,
}


def compile_goal(text: str, now_date: str | None = None) -> dict:
    """把自然语言目标编译为结构化 Goal(含 scopes + policy)。只编译, 不调度。"""
    today = now_date or db.today()
    low = text.lower()

    # Horizon
    m = re.search(r'(\d{1,3})\s*天', text)
    days = int(m.group(1)) if m else 25
    start = datetime.date.fromisoformat(today)
    end = (start + datetime.timedelta(days=days)).isoformat()

    # Goal type / strategy
    scores = {k: sum(w in low or w in text for w in ws) for k, ws in INTENT_WORDS.items()}
    if 'coverage' in scores and scores.get('coverage', 0) and ('coverage' in low or '覆盖' in text):
        gtype, strategy = 'COVERAGE', 'COVERAGE_FIRST'
    elif scores.get('sprint', 0):
        gtype, strategy = 'SPRINT', 'SPRINT'
    elif scores.get('reactivation', 0):
        gtype, strategy = 'REACTIVATION', 'REACTIVATION'
    elif scores.get('maintenance', 0):
        gtype, strategy = 'MAINTENANCE', 'BALANCED'
    elif scores.get('mastery', 0):
        gtype, strategy = 'MASTERY', 'MASTERY_FIRST'
    else:
        gtype, strategy = 'COVERAGE', 'COVERAGE_FIRST'

    # Scope engines
    engines = [e for e, ws in ENGINE_WORDS.items() if any(w in low or w in text for w in ws)]
    if not engines:
        engines = ['Knowledge', 'Algorithms', 'Projects']
    # Scope subclasses
    subs = [s for s in SUBCLASS_WORDS if s.lower() in low]
    norm = {'操作系统': 'OperatingSystems', '网络': 'ComputerNetworks', '数据结构': 'DataStructures',
            '机器学习': 'MachineLearning', '深度学习': 'DeepLearning'}
    subs = [norm.get(s, s) for s in subs]

    # Policy (strategy 漂移基线)
    policy = dict(BASE_POLICY)
    if strategy == 'COVERAGE_FIRST':
        policy.update(retention=0.5, new_learning=1.2, transfer=0.3, desired_retention_early=0.80)
    elif strategy == 'SPRINT':
        policy.update(retention=1.2, weakness=1.2, importance=1.2, new_learning=0.8,
                      temporal_urgency=1.2, desired_retention_early=0.90, desired_retention_late=0.93)
    elif strategy == 'MASTERY_FIRST':
        policy.update(retention=1.1, weakness=1.0, transfer=0.8, new_learning=0.7,
                      desired_retention_early=0.88, desired_retention_late=0.93)
    elif strategy == 'REACTIVATION':
        policy.update(retention=1.2, weakness=0.8, new_learning=0.4, importance=1.2)
    elif strategy == 'MAINTENANCE':
        policy.update(retention=0.9, new_learning=0.3, desired_retention_early=0.75, desired_retention_late=0.80)

    goal_id = db.uid('goal')
    return {
        'goal_id': goal_id,
        'name': text.strip()[:60] or f'{days}-Day Goal',
        'goal_type': gtype,
        'strategy': strategy,
        'intent': text.strip(),
        'start_date': start.isoformat(),
        'end_date': end,
        'priority': 5.0,
        'scopes': ([{'engine_type': e, 'target_pattern': '*', 'weight': 1.0} for e in engines]
                   + [{'engine_type': 'Knowledge', 'target_pattern': s, 'weight': 1.2} for s in subs]),
        'policy': policy,
    }


def save_goal(conn: sqlite3.Connection, g: dict) -> str:
    gid = g['goal_id']
    conn.execute(
        "INSERT INTO goals(goal_id,parent_goal_id,name,goal_type,strategy,intent,start_date,end_date,priority,status,created_at,completed_at)"
        " VALUES (?,?,?,?,?,?,?,?,?,'ACTIVE',?,NULL)",
        (gid, g.get('parent_goal_id'), g['name'], g['goal_type'], g['strategy'], g['intent'],
         g['start_date'], g['end_date'], g['priority'], db.now()))
    for sc in g['scopes']:
        conn.execute("INSERT INTO goal_scopes(scope_id,goal_id,engine_type,target_pattern,weight) VALUES (?,?,?,?,?)",
                     (db.uid('scope'), gid, sc['engine_type'], sc['target_pattern'], sc['weight']))
    conn.execute("INSERT INTO goal_policies(goal_id,policy_json) VALUES (?,?)", (gid, json.dumps(g['policy'], ensure_ascii=False)))
    conn.execute("INSERT INTO goal_events(event_id,goal_id,occurred_at,event_type,payload_json) VALUES (?,?,?,?,?)",
                 (db.uid('gev'), gid, db.now(), 'GOAL_CREATED', json.dumps({'strategy': g['strategy'], 'type': g['goal_type']}, ensure_ascii=False)))
    conn.commit()
    return gid


def active_goals(conn: sqlite3.Connection) -> list:
    return conn.execute("SELECT * FROM goals WHERE status='ACTIVE' ORDER BY priority DESC, start_date").fetchall()


def goal_policy(conn: sqlite3.Connection, goal_id: str) -> dict:
    r = conn.execute("SELECT policy_json FROM goal_policies WHERE goal_id=?", (goal_id,)).fetchone()
    return json.loads(r['policy_json']) if r else dict(BASE_POLICY)


def goal_progress(goal: dict, now_date: str | None = None) -> float:
    """时间进度 0..1, 用于策略连续漂移。"""
    end = goal['end_date'] or (datetime.date.fromisoformat(goal['start_date']) + datetime.timedelta(days=25)).isoformat()
    s = datetime.date.fromisoformat(goal['start_date']).toordinal()
    e = datetime.date.fromisoformat(end).toordinal()
    n = datetime.date.fromisoformat(now_date or db.today()).toordinal()
    return min(1.0, max(0.0, (n - s) / max(1, e - s)))


# ---------- Bootstrap: 首个正式 Goal (12号文件) ----------
BOOTSTRAP_INTENT = ("用大约25天快速建立尽可能广泛的秋招技术能力覆盖，先大量掌握陌生知识，"
                    "再逐渐提高复习、迁移和整合。Knowledge、Algorithms、Projects 都必须实际学习。")

def bootstrap_25day(conn: sqlite3.Connection) -> str:
    g = compile_goal(BOOTSTRAP_INTENT)
    g['name'] = '25-Day Autumn Recruitment Coverage'
    g['goal_type'] = 'COVERAGE'
    g['strategy'] = 'COVERAGE_FIRST'
    g['scopes'] = [
        {'engine_type': 'Knowledge', 'target_pattern': '*', 'weight': 1.0},
        {'engine_type': 'Algorithms', 'target_pattern': '*', 'weight': 1.0},
        {'engine_type': 'Projects', 'target_pattern': '*', 'weight': 0.8},
    ]
    pol = dict(g['policy'])
    pol.update(coverage=1.3, new_learning=1.3, retention=0.5, transfer=0.3,
               desired_retention_early=0.80, desired_retention_late=0.90)
    g['policy'] = pol
    return save_goal(conn, g)
