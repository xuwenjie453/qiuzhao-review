# -*- coding: utf-8 -*-
"""Review Engine: Review is a Probe, not a Re-learning Session。
只有 REVIEW_ELIGIBLE 的 Capsule 可被调度; 成功一次立即结束; 失败记 lapse 并给 Repair 分流。
"""
import json, sqlite3
from . import db, scheduler, engines


def get_capsule(capsule_id: str, engine: str) -> dict | None:
    conn = db.connect(db.ENGINE_DBS[engine])
    try:
        r = conn.execute("SELECT * FROM review_capsules WHERE capsule_id=?", (capsule_id,)).fetchone()
        return dict(r) if r else None
    finally:
        conn.close()


def materialize_probe(capsule: dict) -> dict:
    """动态物化最短有效 Probe(不先给资料/答案/提示)。由 AI 按类型生成具体题目, 此处给出契约。"""
    probes = json.loads(capsule['allowed_probe_types'] or '["recall"]')
    return {
        'capsule_id': capsule['capsule_id'],
        'engine': capsule['engine_type'],
        'target_id': capsule['target_id'],
        'probe_type': probes[0],
        'allowed_probe_types': probes,
        'must_retrieve': json.loads(capsule['must_retrieve'] or '[]'),
        'known_failure_modes': json.loads(capsule['known_failure_modes'] or '[]'),
        'response_budget': capsule['response_budget'] or 'short',
        'required_context': json.loads(capsule['required_context'] or '{}'),
        'rule': '冷启动作答, 无提示; 成功一次立即结束',
    }


def record_probe_shown(capsule_id: str, engine: str, session_id: str | None = None):
    conn = db.connect(db.ENGINE_DBS[engine])
    try:
        target = conn.execute("SELECT target_id FROM review_capsules WHERE capsule_id=?", (capsule_id,)).fetchone()['target_id']
        conn.execute("""INSERT INTO learning_events(event_id,occurred_at,session_id,target_id,event_type,question_id,result,evidence_json,prompt_version,created_at)
                        VALUES (?,?,?,?,?,?,?,?,?,?)""",
                     (db.uid('ev'), db.now(), session_id, target, 'REVIEW_PROBE_SHOWN', None, None, None,
                      'review-v1', db.now()))
        conn.commit()
    finally:
        conn.close()


def grade_review(capsule_id: str, engine: str, grade: str, evidence: dict | None = None,
                 session_id: str | None = None, occurred_at: str | None = None) -> dict:
    """grade: success / partial / failure。partial|failure → 建议分流 Repair/Learning。
    Repair 后成功不得覆盖初始失败: failure 与 repair_success 两条事件并存。"""
    if grade not in ('success', 'partial', 'failure'):
        raise ValueError(grade)
    conn = db.connect(db.ENGINE_DBS[engine])
    try:
        target = conn.execute("SELECT target_id FROM review_capsules WHERE capsule_id=?", (capsule_id,)).fetchone()['target_id']
        etype = {'success': 'REVIEW_SUCCESS', 'partial': 'REVIEW_PARTIAL', 'failure': 'REVIEW_FAILURE'}[grade]
        result = {'success': 'success', 'partial': 'partial', 'failure': 'failure'}[grade]
        conn.execute("""INSERT INTO learning_events(event_id,occurred_at,session_id,target_id,event_type,question_id,result,evidence_json,prompt_version,created_at)
                        VALUES (?,?,?,?,?,?,?,?,?,?)""",
                     (db.uid('ev'), occurred_at or db.now(), session_id, target, etype, None, result,
                      json.dumps(evidence, ensure_ascii=False) if evidence else None, 'review-v1', db.now()))
        conn.commit()
    finally:
        conn.close()
    sched = scheduler.reschedule_after_review(capsule_id, engine, grade,
                                              now_dt=None if not occurred_at else __import__('datetime').datetime.fromisoformat(occurred_at))
    routing = _routing(engine, grade)
    return {'grade': grade, 'routing': routing, 'schedule': sched, 'end': grade == 'success'}


def _routing(engine: str, grade: str) -> str:
    if grade == 'success':
        return 'END: 成功一次立即结束, 交回 Scheduler'
    if grade == 'partial':
        return {'Knowledge': 'Tiny Repair(局部遗漏)',
                'Algorithms': '对应 Skill Repair(API/边界/构造局部)',
                'Projects': 'PSB Repair(局部 trade-off/failure)'}[engine]
    return {'Knowledge': '核心结构丢失 → Knowledge Learning',
            'Algorithms': 'Pattern 整体丢失 → Algorithms Learning',
            'Projects': '整体工程 reasoning 丢失 → Projects Learning'}[engine]


def record_repair_success(engine: str, target_id: str, capsule_id: str | None = None,
                          session_id: str | None = None) -> dict:
    """Repair 成功: 保留原失败事实, 追加 REPAIR_SUCCESS, 并小幅重建稳定性(视为 lapse 后的一次成功)。"""
    engines.add_event(engine, target_id, 'REPAIR_SUCCESS', session_id=session_id, result='success',
                      evidence={'capsule_id': capsule_id})
    grade_sched = scheduler.reschedule_after_review(capsule_id or f'direct:{target_id}', engine, 'partial')
    return {'repair_recorded': True, 'schedule': grade_sched}
