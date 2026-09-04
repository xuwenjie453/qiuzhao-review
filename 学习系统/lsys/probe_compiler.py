# -*- coding: utf-8 -*-
"""Review Probe Compiler: 把复杂学习成果压缩成长期 Review Capsule。禁止原题直接进复习队列。"""
import json
from . import db

COMPILER_VERSION = 'rpc-v1'


def worth_long_term(learned: dict) -> tuple[bool, str]:
    """值得长期复习: 从不会到会 / 发生Repair / 迁移脆弱 / 高频核心 / 强依赖。"""
    if learned.get('had_failure') and learned.get('verified'):
        return True, '从失败到验证通过(REPAIR), 属于脆弱→稳固'
    if learned.get('repair'):
        return True, '学习过程发生 Repair'
    if learned.get('transfer_failed_then_fixed'):
        return True, '迁移验证曾失败'
    if learned.get('high_frequency'):
        return True, '高频核心技能'
    if learned.get('importance', 0) >= 4.0:
        return True, f"重要度 {learned.get('importance')}"
    return (False, '常规掌握, 暂不值得长期占用复习预算')


def compile_capsule(engine: str, target_id: str, must_retrieve: list, evidence: dict,
                    allowed_probe_types: list, response_budget: str,
                    known_failure_modes: list | None = None, required_context: dict | None = None,
                    source_questions: list | None = None, status: str = 'REVIEW_ELIGIBLE') -> str:
    path = db.ENGINE_DBS[engine]
    conn = db.connect(path)
    try:
        capsule_id = db.uid('cap')
        now = db.now()
        conn.execute("""INSERT INTO review_capsules(capsule_id,target_id,engine_type,must_retrieve,known_failure_modes,
                        allowed_probe_types,required_context,response_budget,source_questions,eligibility_evidence,
                        compiler_version,status,created_at,updated_at)
                        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                     (capsule_id, target_id, engine, json.dumps(must_retrieve, ensure_ascii=False),
                      json.dumps(known_failure_modes or [], ensure_ascii=False),
                      json.dumps(allowed_probe_types, ensure_ascii=False),
                      json.dumps(required_context or {}, ensure_ascii=False),
                      response_budget, json.dumps(source_questions or [], ensure_ascii=False),
                      json.dumps(evidence, ensure_ascii=False), COMPILER_VERSION, status, now, now))
        conn.commit()
        # 在 scheduler 激活最小 schedule 状态(绝不写 questions.sqlite3)
        sched = db.connect(db.DB_SCHEDULER, init=True)
        try:
            sched.execute("""INSERT INTO review_schedule(capsule_id,engine_type,target_id,stability,difficulty,
                            last_review_at,next_due_at,last_grade,review_count,lapse_count,active,scheduling_version,updated_at)
                            VALUES (?,?,?,?,?,NULL,NULL,NULL,0,0,1,?,?)""",
                         (capsule_id, engine, target_id, 2.0, 4.0, 'ts-v1', now))
            sched.commit()
        finally:
            sched.close()
        return capsule_id
    finally:
        conn.close()
