# -*- coding: utf-8 -*-
"""Temporal Scheduler: 只决定下一项 TaskIntent, 不教学。
FSRS-inspired 记忆模型(D/S/R, R 运行时计算不存储) + 统一效用函数(LEARN/REVIEW/REPAIR 竞争)。
可解释、可调参、版本化(scheduling_version)。不是 Due Queue。
"""
import json, math, datetime, sqlite3
from . import db, goal_compiler

SCHEDULING_VERSION = 'ts-v1'
FACTOR = 0.2346   # 使 R(S) = 0.9
DECAY = -0.5      # FSRS power curve; 接口不变可升级 FSRS-6
INIT_STABILITY = 2.0
INIT_DIFFICULTY = 4.0


# ---------------- 记忆模型 ----------------
def retrievability(stability: float, last_review_at: str, now_dt: datetime.datetime | None = None) -> float:
    """R = (1 + FACTOR * t/S) ^ DECAY ; t 为经过天数。运行时计算, 不存储。"""
    if not last_review_at:
        return 0.0
    last = datetime.datetime.fromisoformat(last_review_at)
    now_dt = now_dt or datetime.datetime.now().astimezone()
    t = max(0.0, (now_dt - last).total_seconds() / 86400.0)
    return (1.0 + FACTOR * t / max(0.1, stability)) ** DECAY


def next_interval(stability: float, desired_retention: float) -> float:
    """达到 desired retention 的天数。"""
    dr = min(0.99, max(0.5, desired_retention))
    return max(0.1, stability / FACTOR * (dr ** (1.0 / DECAY) - 1.0))


def update_memory(row: dict, grade: str) -> dict:
    """grade: success / partial / failure (Review 后或 Repair 后调用)。透明可解释规则, v1。"""
    d, s = row.get('difficulty', INIT_DIFFICULTY), row.get('stability', INIT_STABILITY)
    if grade == 'success':
        s = max(1.0, s * (3.0 - 0.25 * d))
        d = max(1.0, d - 0.2)
    elif grade == 'partial':
        s = max(0.8, s * 1.1)
    else:  # failure → lapse
        s = max(0.4, s * 0.4)
        d = min(10.0, d + 1.0)
    return {'stability': round(s, 3), 'difficulty': round(d, 3)}


# ---------------- 内部工具 ----------------
def _desired_retention(policy: dict, progress: float, importance: float, engine: str) -> float:
    """连续漂移: 早期→early, 后期→late; 高 importance 提前抬升。"""
    base = policy.get('desired_retention_early', 0.80) + \
        (policy.get('desired_retention_late', 0.90) - policy.get('desired_retention_early', 0.80)) * progress
    return min(0.97, base + max(0.0, importance - 4.0) * 0.01)


def _matches(pattern: str, subcategory: str | None) -> bool:
    if not pattern or pattern == '*':
        return True
    return bool(subcategory) and (subcategory == pattern or pattern in (subcategory or ''))


def _review_debt(conn) -> float:
    r = conn.execute("SELECT count(*) AS n FROM review_schedule WHERE active=1 AND next_due_at IS NOT NULL AND next_due_at <= ?",
                     (db.now(),)).fetchone()
    return float(r['n'])


def _last_subcategories(conn) -> list:
    """最近3个学习目标的子类(跨引擎库只读; ATTACH 亦可, 此处轻量直查)。"""
    out = []
    for path in db.ENGINE_DBS.values():
        try:
            c = sqlite3.connect(path)
            c.row_factory = sqlite3.Row
            for r in c.execute("SELECT target_id FROM learning_events ORDER BY occurred_at DESC LIMIT 3"):
                out.append(r['target_id'].split('/')[0])
            c.close()
        except sqlite3.OperationalError:
            continue
    return out[-3:]


def _importance_map(conn) -> dict:
    """子类重要度投影(来自试题库星级)。"""
    m = {}
    for sub, info in db.subcategory_importance(conn).items():
        m[sub] = info['importance']
    return m


# ---------------- TaskIntent ----------------
def task_intent(conn, now_dt: datetime.datetime | None = None, engine_filter: str | None = None,
                user_overrides: dict | None = None) -> dict | None:
    """输出下一项 TaskIntent。候选 = LEARN / REVIEW / REPAIR, 统一效用竞争。"""
    now_dt = now_dt or datetime.datetime.now().astimezone()
    goals = goal_compiler.active_goals(conn)
    if not goals:
        return None
    goal = goals[0]
    policy = goal_compiler.goal_policy(conn, goal['goal_id'])
    progress = goal_compiler.goal_progress(goal, now_dt.date().isoformat())
    if user_overrides:
        policy = {**policy, **user_overrides}
    debt = _review_debt(conn)
    # 25天连续漂移: 前期新学习强; 后期 Retention/Weakness 增强(结合时间进度+复习债务, 不硬切阶段)
    drift_ret = 0.6 + 1.8 * progress + min(0.6, debt / 40.0)
    drift_learn = max(0.45, 1.15 - 0.5 * progress)
    ret_w = policy.get('retention', 0.6) * drift_ret
    learn_w = max(policy.get('new_learning', 1.0) * drift_learn, 0.35 if strategy_min_learning(goal) else 0.0)
    imp_map = _importance_map(conn)
    last_subs = _last_subcategories(conn)

    # ---- REVIEW 候选: 所有引擎 active capsules ----
    best_review, best_review_u = None, 0.0
    for eng, path in db.ENGINE_DBS.items():
        if engine_filter and eng != engine_filter:
            continue
        try:
            econn = db.connect(path)
            econn.execute("ATTACH DATABASE ? AS sched", (db.DB_SCHEDULER,))  # 跨库只读统一视图
        except Exception:
            continue
        try:
            rows = econn.execute("""
                SELECT c.capsule_id, c.target_id, c.must_retrieve, c.allowed_probe_types, c.response_budget,
                       c.known_failure_modes, s.stability, s.difficulty, s.last_review_at, s.lapse_count
                FROM review_capsules c JOIN sched.review_schedule s ON s.capsule_id = c.capsule_id
                WHERE c.status='REVIEW_ELIGIBLE' AND s.active=1
                  AND (s.next_due_at IS NULL OR s.next_due_at <= ?)
            """, (now_dt.isoformat(timespec='seconds'),)).fetchall()
            for r in rows:
                R = retrievability(r['stability'], r['last_review_at'], now_dt)
                dr = _desired_retention(policy, progress, 4.0, eng)
                urgency = max(0.0, dr - R) / max(0.01, dr)           # MemoryUrgency
                lapse = min(1.0, r['lapse_count'] / 3.0)              # WeaknessFactor
                sub = r['target_id'].split('/')[0]
                importance = imp_map.get(sub, 3.0) / 5.0
                relevance = 1.0 if _goal_relevant(conn, goal['goal_id'], eng, sub) else 0.5
                div = 0.85 if sub in last_subs else 1.0               # DiversityAdjustment
                crit = 1.8 if R < dr - 0.25 else 1.0   # 临界遗忘加成
                u = (ret_w * crit * (0.45 * urgency + 0.25 * importance + 0.15 * lapse + 0.15 * relevance)) * div * 10.0
                if u > best_review_u:
                    best_review_u = u
                    best_review = {
                        'intent_type': 'REVIEW', 'engine': eng, 'target_id': r['target_id'],
                        'capsule_id': r['capsule_id'], 'reason': f"R={R:.2f} < 目标保持{dr:.2f}, 效用{u:.2f}",
                        'goal_id': goal['goal_id'],
                        'probe': {'allowed_probe_types': json.loads(r['allowed_probe_types'] or '["recall"]'),
                                  'must_retrieve': json.loads(r['must_retrieve']),
                                  'response_budget': r['response_budget'] or 'short',
                                  'known_failure_modes': json.loads(r['known_failure_modes'] or '[]')},
                        'priority_context': {'retrievability': round(R, 3), 'desired_retention': dr,
                                             'lapse_count': r['lapse_count']},
                    }
        finally:
            econn.close()

    # ---- LEARN 候选: 未学/未验证节点 (scope 匹配) ----
    best_learn, best_learn_u = None, 0.0
    for eng, path in db.ENGINE_DBS.items():
        if engine_filter and eng != engine_filter:
            continue
        econn = db.connect(path)
        try:
            table = db.NODES_TABLE[eng]
            states = db.STATES_TABLE[eng]
            rows = econn.execute(f"""
                SELECT n.node_id, n.name, n.subcategory, n.importance, n.node_type,
                       COALESCE(s.status,'UNSEEN') AS status, COALESCE(s.failure_count,0) AS fc
                FROM {table} n LEFT JOIN {states} s ON s.target_id = n.node_id
                WHERE COALESCE(s.status,'UNSEEN') IN ('UNSEEN','LEARNING','REPAIR')
            """).fetchall()
            covered = econn.execute(f"SELECT count(*) AS n FROM {states} WHERE status='LEARNING_VERIFIED'").fetchone()['n']
            total = econn.execute(f"SELECT count(*) AS n FROM {table}").fetchone()['n']
            coverage_ratio = covered / max(1, total)
            for r in rows:
                sub = r['subcategory'] or ''
                scope_ok = any(_matches(sc['target_pattern'], sub) for sc in
                               conn.execute("SELECT target_pattern FROM goal_scopes WHERE goal_id=?", (goal['goal_id'],)).fetchall())
                if not scope_ok:
                    continue
                importance = (r['importance'] or imp_map.get(sub, 3.0)) / 5.0
                novelty = 1.0 if r['status'] == 'UNSEEN' else 0.5
                weakness = min(1.0, r['fc'] / 3.0)
                div = 0.7 if (r['name'] in last_subs) else 1.0
                coverage_need = 1.0 - coverage_ratio
                u = (learn_w * (0.30 * importance + 0.25 * novelty + 0.20 * coverage_need
                                + 0.15 * policy.get('weakness', 0.6) * weakness
                                + 0.10 * policy.get('diversity', 0.5))) * div * 10.0
                if u > best_learn_u:
                    best_learn_u = u
                    best_learn = {
                        'intent_type': 'LEARN', 'engine': eng, 'target_id': r['node_id'],
                        'target_name': r['name'], 'node_type': r['node_type'],
                        'reason': f"未掌握[{r['status']}], 重要度{r['importance']}, 效用{u:.2f}",
                        'goal_id': goal['goal_id'],
                        'priority_context': {'coverage_ratio': round(coverage_ratio, 3), 'importance': r['importance']},
                    }
        finally:
            econn.close()

    # ---- REPAIR 候选: 最近 lapse 的 capsule → 回对应引擎 Repair ----
    best_repair = None
    if best_review and best_review['priority_context']['lapse_count'] > 0:
        best_repair = dict(best_review)
        best_repair['intent_type'] = 'REPAIR'
        best_repair['reason'] = '存在 lapse 记录, 先局部 Repair 再继续'

    cands = [c for c in (best_review, best_learn, best_repair) if c]
    if not cands:
        return None
    # REPAIR 优先级小幅加成; 其余按效用
    for c in cands:
        c['_u'] = best_review_u if c['intent_type'] == 'REVIEW' else (best_learn_u if c['intent_type'] == 'LEARN' else best_review_u * 1.1)
    cands.sort(key=lambda c: -c['_u'])
    top = cands[0]
    top['scheduling_version'] = SCHEDULING_VERSION
    top['as_of'] = now_dt.isoformat(timespec='seconds')
    top['policy_snapshot'] = {'retention_w': round(ret_w, 3), 'learn_w': round(learn_w, 3),
                              'review_debt': int(debt), 'goal_progress': round(progress, 3)}
    top.pop('_u', None)
    return top


def strategy_min_learning(goal) -> bool:
    """Coverage Goal: 新学习保底, 不允许 Review Debt 吞掉全部新学习。"""
    return goal['strategy'] in ('COVERAGE_FIRST', 'BALANCED')


def _goal_relevant(conn, goal_id: str, engine: str, sub: str) -> bool:
    rows = conn.execute("SELECT target_pattern FROM goal_scopes WHERE goal_id=?", (goal_id,)).fetchall()
    return any(_matches(r['target_pattern'], sub) for r in rows)


# ---------------- Review 完成后的再调度 ----------------
def reschedule_after_review(capsule_id: str, engine: str, grade: str, now_dt: datetime.datetime | None = None):
    """Review/Repair 完成后更新 review_schedule(含跨引擎时序状态)。"""
    now_dt = now_dt or datetime.datetime.now().astimezone()
    conn = db.connect(db.DB_SCHEDULER, init=False)
    try:
        row = conn.execute("SELECT * FROM review_schedule WHERE capsule_id=?", (capsule_id,)).fetchone()
        mem = update_memory(dict(row) if row else {'stability': INIT_STABILITY, 'difficulty': INIT_DIFFICULTY}, grade)
        # desired retention 用当前 active goal 的漂移值
        goals = goal_compiler.active_goals(conn)
        policy = goal_compiler.goal_policy(conn, goals[0]['goal_id']) if goals else goal_compiler.BASE_POLICY
        progress = goal_compiler.goal_progress(goals[0], now_dt.date().isoformat()) if goals else 0.5
        dr = _desired_retention(policy, progress, 4.0, engine)
        interval = next_interval(mem['stability'], dr)
        nxt = (now_dt + datetime.timedelta(days=interval)).isoformat(timespec='seconds')
        if row:
            conn.execute("""UPDATE review_schedule SET stability=?, difficulty=?, last_review_at=?, next_due_at=?,
                            last_grade=?, review_count=review_count+1,
                            lapse_count=lapse_count+?, active=1, scheduling_version=?, updated_at=? WHERE capsule_id=?""",
                         (mem['stability'], mem['difficulty'], now_dt.isoformat(timespec='seconds'), nxt, grade,
                          1 if grade == 'failure' else 0, SCHEDULING_VERSION, db.now(), capsule_id))
        else:
            conn.execute("""INSERT INTO review_schedule(capsule_id,engine_type,target_id,stability,difficulty,last_review_at,
                            next_due_at,last_grade,review_count,lapse_count,active,scheduling_version,updated_at)
                            VALUES (?,?,?,?,?,?,?,?,?,?,1,?,?)""",
                         (capsule_id, engine, '', mem['stability'], mem['difficulty'], now_dt.isoformat(timespec='seconds'),
                          nxt, grade, 1, 1 if grade == 'failure' else 0, SCHEDULING_VERSION, db.now()))
        conn.commit()
        return {'stability': mem['stability'], 'difficulty': mem['difficulty'],
                'next_due_at': nxt, 'interval_days': round(interval, 2), 'desired_retention': dr}
    finally:
        conn.close()
