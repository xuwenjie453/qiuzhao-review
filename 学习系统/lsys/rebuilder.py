# -*- coding: utf-8 -*-
"""State Rebuilder: events → replay → current state。Current State 可删除重建。"""
from . import db

REBUILD_SQL = {
    'Knowledge': ('knowledge_states', 'Knowledge'),
    'Algorithms': ('skill_states', 'Algorithms'),
    'Projects': ('engineering_states', 'Projects'),
}


def rebuild_engine(engine: str) -> dict:
    states_table, _ = REBUILD_SQL[engine]
    path = db.ENGINE_DBS[engine]
    conn = db.connect(path)
    try:
        conn.execute(f"DELETE FROM {states_table}")
        rows = conn.execute("""SELECT target_id, occurred_at, event_type, result FROM learning_events
                               ORDER BY occurred_at, rowid""").fetchall()
        n = 0
        for r in rows:
            status = None
            fc_add = 1 if r['result'] == 'failure' else 0
            rep_add = 1 if r['event_type'] in ('REPAIR_SUCCESS', 'SKILL_REPAIR') else 0
            if r['event_type'] in ('LEARNING_STARTED', 'SKILL_IDENTIFIED', 'CASE_ATTEMPT', 'BLOCK_PRESENTED'):
                status = 'LEARNING'
            elif r['event_type'] == 'LEARNING_VERIFIED':
                status = 'LEARNING_VERIFIED'
            cur = conn.execute(f"SELECT * FROM {states_table} WHERE target_id=?", (r['target_id'],)).fetchone()
            if cur:
                new_status = status or cur['status']
                if status == 'LEARNING' and cur['status'] == 'LEARNING_VERIFIED':
                    new_status = cur['status']  # 已验证不被后续 started 降级
                conn.execute(f"""UPDATE {states_table} SET status=?, last_event_at=?, event_count=event_count+1,
                                 failure_count=failure_count+?, repair_count=repair_count+?, updated_at=? WHERE target_id=?""",
                             (new_status, r['occurred_at'], fc_add, rep_add, db.now(), r['target_id']))
            else:
                st = status or 'LEARNING'
                conn.execute(f"""INSERT INTO {states_table}(target_id,engine_type,status,first_learned_at,last_event_at,
                                 event_count,failure_count,repair_count,updated_at) VALUES (?,?,?,?,?,1,?,?,?)""",
                             (r['target_id'], engine, st, r['occurred_at'], r['occurred_at'], fc_add, rep_add, db.now()))
            n += 1
        conn.commit()
        total = conn.execute(f"SELECT count(*) AS n FROM {states_table}").fetchone()['n']
        verified = conn.execute(f"SELECT count(*) AS n FROM {states_table} WHERE status='LEARNING_VERIFIED'").fetchone()['n']
        return {'engine': engine, 'events_replayed': n, 'states': total, 'verified': verified}
    finally:
        conn.close()


def rebuild_all() -> list:
    return [rebuild_engine(e) for e in ('Knowledge', 'Algorithms', 'Projects')]
