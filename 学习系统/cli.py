# -*- coding: utf-8 -*-
"""CLI 会话入口 — 用户只负责看/想/说/写, 系统负责判断/检索/教学/评估/记录/调度。

用法:
  python 学习系统/cli.py init                 # 初始化全部数据库
  python 学习系统/cli.py seed                 # 按试题库播种引擎节点
  python 学习系统/cli.py bootstrap            # 创建首个 Goal: 25-Day Autumn Recruitment Coverage
  python 学习系统/cli.py add-goal "自然语言"   # Goal Compiler
  python 学习系统/cli.py task [--engine X] [--now ISO]   # 下一项 TaskIntent
  python 学习系统/cli.py learn-event --engine E --target T --type TYPE [--question Q] [--result R]
  python 学习系统/cli.py learn-verify --engine E --target T --must-retrieve 要点1;要点2 [--questions Q1,Q2]
  python 学习系统/cli.py review-show [--now ISO]         # 物化 Micro Probe
  python 学习系统/cli.py review-grade --capsule C --grade success|partial|failure
  python 学习系统/cli.py repair --engine E --target T [--capsule C]
  python 学习系统/cli.py status
  python 学习系统/cli.py replay               # 事件重放重建状态
  python 学习系统/cli.py integrity            # 全库 integrity + foreign_key 检查
  python 学习系统/cli.py expand-materials [--limit N] [--verbose]
  python 学习系统/cli.py retrieve "查询词" [--level 2]
  python 学习系统/cli.py small-to-big --chunk CHUNK_ID
"""
import sys, os, json, argparse, datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lsys import db, schema, goal_compiler, scheduler, engines, probe_compiler, review_engine, rebuilder, materials_rag  # noqa: E402


def cmd_init(_):
    for line in db.init_all():
        print(line)


def cmd_seed(_):
    for nid in engines.seed_all():
        print('seeded', nid)


def cmd_bootstrap(_):
    conn = db.connect(db.DB_SCHEDULER, init=True)
    gid = goal_compiler.bootstrap_25day(conn)
    conn.close()
    print(f'Goal created: {gid} = 25-Day Autumn Recruitment Coverage (COVERAGE / COVERAGE_FIRST)')


def cmd_add_goal(a):
    g = goal_compiler.compile_goal(a.text)
    conn = db.connect(db.DB_SCHEDULER, init=True)
    gid = goal_compiler.save_goal(conn, g)
    conn.close()
    print(json.dumps({'goal_id': gid, 'goal_type': g['goal_type'], 'strategy': g['strategy'],
                      'end_date': g['end_date'], 'scopes': g['scopes']}, ensure_ascii=False, indent=1))


def cmd_task(a):
    conn = db.connect(db.DB_SCHEDULER, init=True)
    now_dt = datetime.datetime.fromisoformat(a.now) if a.now else None
    ti = scheduler.task_intent(conn, now_dt=now_dt, engine_filter=a.engine,
                               user_overrides=json.loads(a.policy_override) if a.policy_override else None)
    conn.close()
    if not ti:
        print('无活动 Goal: 先 bootstrap 或 add-goal')
        return
    print(json.dumps(ti, ensure_ascii=False, indent=1))


def cmd_learn_event(a):
    eid = engines.add_event(a.engine, a.target, a.type, question_id=a.question, result=a.result,
                            evidence=json.loads(a.evidence) if a.evidence else None,
                            occurred_at=a.at)
    print('event:', eid)


def cmd_learn_verify(a):
    """LEARNING_VERIFIED 事件 → Probe Compiler → Capsule + 最小 schedule。"""
    engines.add_event(a.engine, a.target, 'LEARNING_VERIFIED', question_id=a.question,
                      result='success', evidence=json.loads(a.evidence) if a.evidence else None,
                      occurred_at=a.at)
    must = [x for x in (a.must_retrieve or '').split(';') if x.strip()]
    if not must:
        must = ['(待由 AI 会话填写最小可检索要点)']
    probes = a.probes.split(',') if a.probes else {
        'Knowledge': ['explain', 'boundary', 'transfer'],
        'Algorithms': ['Complete', 'Boundary', 'Trace', 'SkeletonFill'],
        'Projects': ['decision_probe', 'failure_mode'],
    }[a.engine]
    budget = a.budget or {'Knowledge': 'short_para', 'Algorithms': 'small_code', 'Projects': 'short_decision'}[a.engine]
    cap = probe_compiler.compile_capsule(
        a.engine, a.target, must_retrieve=must,
        evidence=json.loads(a.evidence) if a.evidence else {'verified_by': 'session'},
        allowed_probe_types=probes, response_budget=budget,
        known_failure_modes=a.failure_modes.split(';') if a.failure_modes else [],
        source_questions=a.questions.split(',') if a.questions else [])
    print(json.dumps({'capsule_id': cap, 'status': 'REVIEW_ELIGIBLE', 'engine': a.engine,
                      'target_id': a.target, 'must_retrieve': must}, ensure_ascii=False, indent=1))


def cmd_review_show(a):
    conn = db.connect(db.DB_SCHEDULER, init=True)
    now_dt = datetime.datetime.fromisoformat(a.now) if a.now else None
    ti = scheduler.task_intent(conn, now_dt=now_dt, engine_filter=a.engine)
    conn.close()
    if not ti or ti['intent_type'] not in ('REVIEW', 'REPAIR'):
        print(json.dumps({'info': '当前无到期 Review; 调度结果为:', 'task': ti}, ensure_ascii=False, indent=1))
        return
    cap = review_engine.get_capsule(ti['capsule_id'], ti['engine'])
    probe = review_engine.materialize_probe(cap)
    review_engine.record_probe_shown(cap['capsule_id'], ti['engine'])
    print(json.dumps(probe, ensure_ascii=False, indent=1))


def cmd_review_grade(a):
    out = review_engine.grade_review(a.capsule, a.engine, a.grade,
                                     evidence=json.loads(a.evidence) if a.evidence else None,
                                     occurred_at=a.at)
    print(json.dumps(out, ensure_ascii=False, indent=1))


def cmd_repair(a):
    out = review_engine.record_repair_success(a.engine, a.target, capsule_id=a.capsule)
    print(json.dumps(out, ensure_ascii=False, indent=1))


def cmd_status(_):
    conn = db.connect(db.DB_SCHEDULER, init=True)
    print('== Goals ==')
    for g in conn.execute("SELECT goal_id,name,goal_type,strategy,start_date,end_date,status FROM goals"):
        print(' ', dict(g))
    due = conn.execute("SELECT count(*) n FROM review_schedule WHERE active=1 AND next_due_at<=?", (db.now(),)).fetchone()['n']
    caps = conn.execute("SELECT count(*) n FROM review_schedule WHERE active=1").fetchone()['n']
    print(f'== Review == capsules={caps}, due-now={due} (due 仅为候选, 非 Due Queue)')
    conn.close()
    for eng, path in db.ENGINE_DBS.items():
        c = db.connect(path)
        st, tbl = db.STATES_TABLE[eng], db.NODES_TABLE[eng]
        rows = c.execute(f"""SELECT COALESCE(s.status,'UNSEEN') st, count(*) n FROM {tbl} n
                             LEFT JOIN {st} s ON s.target_id=n.node_id GROUP BY st""").fetchall()
        caps_e = c.execute("SELECT count(*) n FROM review_capsules").fetchone()['n']
        print(f'== {eng} ==', {r['st']: r['n'] for r in rows}, f'capsules={caps_e}')
        c.close()


def cmd_replay(_):
    for r in rebuilder.rebuild_all():
        print(json.dumps(r, ensure_ascii=False))


def cmd_integrity(_):
    for k, v in db.integrity().items():
        print(f'{k}: {v}')


def cmd_expand_materials(a):
    stats = materials_rag.index_materials(limit_files=a.limit, verbose=a.verbose)
    print(json.dumps(stats, ensure_ascii=False, indent=1))


def cmd_retrieve(a):
    for r in materials_rag.retrieve(a.query, top_k=a.top_k, level=a.level):
        print(json.dumps({'chunk_id': r['chunk_id'], 'level': r['level'], 'heading_path': r['heading_path'],
                          'source': r['source'], 'score': r['score'],
                          'content': r['content'][:300]}, ensure_ascii=False))


def cmd_small_to_big(a):
    for r in materials_rag.small_to_big(a.chunk):
        print(json.dumps({'chunk_id': r['chunk_id'], 'level': r['level'], 'heading_path': r['heading_path'],
                          'source': r['source'], 'content': r['content'][:300]}, ensure_ascii=False))


def main():
    ap = argparse.ArgumentParser(description='秋招智能学习与复习体系 V1')
    sub = ap.add_subparsers(dest='cmd', required=True)

    sub.add_parser('init').set_defaults(func=cmd_init)
    sub.add_parser('seed').set_defaults(func=cmd_seed)
    sub.add_parser('bootstrap').set_defaults(func=cmd_bootstrap)
    p = sub.add_parser('add-goal'); p.add_argument('text'); p.set_defaults(func=cmd_add_goal)
    p = sub.add_parser('task'); p.add_argument('--engine'); p.add_argument('--now'); p.add_argument('--policy-override'); p.set_defaults(func=cmd_task)
    p = sub.add_parser('learn-event')
    p.add_argument('--engine', required=True); p.add_argument('--target', required=True); p.add_argument('--type', required=True)
    p.add_argument('--question'); p.add_argument('--result'); p.add_argument('--evidence'); p.add_argument('--at')
    p.set_defaults(func=cmd_learn_event)
    p = sub.add_parser('learn-verify')
    p.add_argument('--engine', required=True); p.add_argument('--target', required=True)
    p.add_argument('--must-retrieve'); p.add_argument('--probes'); p.add_argument('--budget'); p.add_argument('--failure-modes')
    p.add_argument('--questions'); p.add_argument('--question'); p.add_argument('--evidence'); p.add_argument('--at')
    p.set_defaults(func=cmd_learn_verify)
    p = sub.add_parser('review-show'); p.add_argument('--engine'); p.add_argument('--now'); p.set_defaults(func=cmd_review_show)
    p = sub.add_parser('review-grade'); p.add_argument('--capsule', required=True); p.add_argument('--engine', required=True)
    p.add_argument('--grade', required=True, choices=['success', 'partial', 'failure'])
    p.add_argument('--evidence'); p.add_argument('--at'); p.set_defaults(func=cmd_review_grade)
    p = sub.add_parser('repair'); p.add_argument('--engine', required=True); p.add_argument('--target', required=True)
    p.add_argument('--capsule'); p.set_defaults(func=cmd_repair)
    sub.add_parser('status').set_defaults(func=cmd_status)
    sub.add_parser('replay').set_defaults(func=cmd_replay)
    sub.add_parser('integrity').set_defaults(func=cmd_integrity)
    p = sub.add_parser('expand-materials'); p.add_argument('--limit', type=int); p.add_argument('--verbose', action='store_true')
    p.set_defaults(func=cmd_expand_materials)
    p = sub.add_parser('retrieve'); p.add_argument('query'); p.add_argument('--top-k', type=int, default=8); p.add_argument('--level', type=int)
    p.set_defaults(func=cmd_retrieve)
    p = sub.add_parser('small-to-big'); p.add_argument('--chunk', required=True); p.set_defaults(func=cmd_small_to_big)

    a = ap.parse_args()
    a.func(a)


if __name__ == '__main__':
    main()
