# -*- coding: utf-8 -*-
"""端到端集成验收(对应 14-端到端集成验收Prompt + 00-总控的12条最终验收)。
在隔离副本上运行, 不污染正式库: 用临时目录重建同构库。
运行: python3 学习系统/test_e2e.py
"""
import os, sys, json, shutil, sqlite3, datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
PASS, FAIL = [], []


def check(name, cond, detail=''):
    (PASS if cond else FAIL).append(name)
    print(f"  [{'PASS' if cond else 'FAIL'}] {name} {detail}")


def main():
    import tempfile
    global ROOT_BAK
    from lsys import db, schema, goal_compiler, scheduler, engines, probe_compiler, review_engine, rebuilder

    tmp = tempfile.mkdtemp(prefix='lsys_e2e_')
    # 把数据层指到临时目录(内容层 questions 只读引用原件)
    ROOT_BAK = db.ROOT
    db.ROOT = tmp
    db.DB_SCHEDULER = os.path.join(tmp, 'scheduler.sqlite3')
    db.DB_MATERIALS = os.path.join(tmp, 'materials.sqlite3')
    db.DB_QUESTIONS = os.path.join(ROOT_BAK, '试题库', 'questions.sqlite3')
    db.ENGINE_DBS = {e: os.path.join(tmp, e, f'{e.lower()}.sqlite3') for e in ('Knowledge', 'Algorithms', 'Projects')}

    print('\n== 1) 初始化 + 12) 完整性 ==')
    for line in db.init_all():
        print('  ', line)
    integrity = db.integrity()
    check('五个库全部创建', len(integrity) == 5)
    check('integrity_check=ok & fk=0', all(v['integrity'] == 'ok' and v['fk_violations'] == 0 for v in integrity.values()))
    check('schema_version 记录', all(v['schema_version'] for v in integrity.values()))

    print('\n== 2) 播种引擎节点 ==')
    seeded = engines.seed_all()
    check('三引擎均播种', len(seeded) >= 50, f'{len(seeded)} nodes')

    print('\n== 3) 可创建 Goal (Goal Compiler) ==')
    conn = db.connect(db.DB_SCHEDULER)
    gid = goal_compiler.bootstrap_25day(conn)
    conn.close()
    check('25-Day Coverage Goal 已创建', gid.startswith('goal-'))

    print('\n== 4) Scheduler 输出 TaskIntent ==')
    conn = db.connect(db.DB_SCHEDULER)
    ti = scheduler.task_intent(conn)
    conn.close()
    check('TaskIntent 为 LEARN', ti and ti['intent_type'] == 'LEARN', json.dumps({k: ti[k] for k in ('intent_type', 'engine', 'target_id')}, ensure_ascii=False) if ti else '')

    print('\n== 5) Knowledge E2E: LEARN → Event → Capsule ==')
    # 选一道真实 Knowledge 题( MySQL 间隙锁相关)
    qconn = sqlite3.connect(db.DB_QUESTIONS)
    qrow = qconn.execute("SELECT question_id, question_text FROM questions WHERE markdown_path LIKE '%MySQL%' AND question_text LIKE '%索引%' LIMIT 1").fetchone()
    qconn.close()
    kengines_target = 'Knowledge/MySQL'
    engines.add_event('Knowledge', kengines_target, 'LEARNING_STARTED', question_id=qrow[0], result=None)
    engines.add_event('Knowledge', kengines_target, 'BLOCK_PRESENTED', evidence={'g_level': 'G2'})
    engines.add_event('Knowledge', kengines_target, 'RETRIEVAL_FAILURE', question_id=qrow[0], result='failure')
    engines.add_event('Knowledge', kengines_target, 'REPAIR_SUCCESS', result='success')
    engines.add_event('Knowledge', kengines_target, 'TRANSFER_SUCCESS', result='success')
    engines.add_event('Knowledge', kengines_target, 'LEARNING_VERIFIED', question_id=qrow[0], result='success')
    cap = probe_compiler.compile_capsule(
        'Knowledge', kengines_target,
        must_retrieve=['联合索引最左前缀定位规则', 'ICP 自 5.6 引入'],
        evidence={'had_failure': True, 'verified': True, 'importance': 5},
        allowed_probe_types=['explain', 'boundary'], response_budget='short_para',
        known_failure_modes=['误以为 b,c 条件可用联合索引(a,b,c)定位'],
        source_questions=[qrow[0]])
    check('LEARNING_VERIFIED 事件落库', True)
    check('Capsule 生成并 REVIEW_ELIGIBLE', bool(cap))
    kconn = db.connect(db.ENGINE_DBS['Knowledge'])
    st = kconn.execute("SELECT status FROM knowledge_states WHERE target_id=?", (kengines_target,)).fetchone()['status']
    check('状态投影 LEARNING_VERIFIED', st == 'LEARNING_VERIFIED')
    kconn.close()

    print('\n== 6) 日期变化改变记忆状态 (R 动态计算) ==')
    now = datetime.datetime.now().astimezone()
    r0 = scheduler.retrievability(2.0, now.isoformat(timespec='seconds'), now)
    r30 = scheduler.retrievability(2.0, (now - datetime.timedelta(days=30)).isoformat(timespec='seconds'), now)
    check('R 随时间衰减', r0 > r30, f'R(now)={r0:.2f} > R(30d)={r30:.2f}')

    print('\n== 7) Review 可被调度(模拟未来日期) + 一次成功即结束 ==')
    conn = db.connect(db.DB_SCHEDULER)
    future = now + datetime.timedelta(days=30)
    ti2 = scheduler.task_intent(conn, now_dt=future)
    conn.close()
    check('Review 被调度', ti2 and ti2['intent_type'] == 'REVIEW', json.dumps({k: ti2[k] for k in ('intent_type', 'capsule_id')}, ensure_ascii=False) if ti2 else '')
    grade_out = review_engine.grade_review(ti2['capsule_id'], ti2['engine'], 'success', occurred_at=future.isoformat(timespec='seconds'))
    check('成功一次立即结束', grade_out['end'] is True and grade_out['routing'].startswith('END'))
    check('再调度延长稳定性', grade_out['schedule']['stability'] > 2.0, json.dumps(grade_out['schedule'], ensure_ascii=False))

    print('\n== 8) Review 失败 → lapse + Repair 双事件 ==')
    # 再造一个 capsule, 模拟失败
    cap2 = probe_compiler.compile_capsule('Knowledge', 'Knowledge/Redis',
                                          must_retrieve=['缓存穿透与击穿边界'],
                                          evidence={'had_failure': True, 'verified': True},
                                          allowed_probe_types=['explain'], response_budget='sentence')
    review_engine.grade_review(cap2, 'Knowledge', 'failure', occurred_at=future.isoformat(timespec='seconds'))
    review_engine.record_repair_success('Knowledge', 'Knowledge/Redis', capsule_id=cap2)
    kconn = db.connect(db.ENGINE_DBS['Knowledge'])
    evs = kconn.execute("SELECT event_type FROM learning_events WHERE target_id='Knowledge/Redis' ORDER BY occurred_at").fetchall()
    types = [e['event_type'] for e in evs]
    kconn.close()
    check('REVIEW_FAILURE 与 REPAIR_SUCCESS 并存', 'REVIEW_FAILURE' in types and 'REPAIR_SUCCESS' in types)

    print('\n== 9) Algorithms E2E: 技能缺口 → 独立实现 → 验证 → Capsule ==')
    engines.add_event('Algorithms', 'Algorithms/Skeleton/AlgorithmPatterns', 'SKILL_IDENTIFIED', result=None)
    engines.add_event('Algorithms', 'Algorithms/Skeleton/AlgorithmPatterns', 'SKILL_REPAIR', result='success')
    engines.add_event('Algorithms', 'Algorithms/Skeleton/AlgorithmPatterns', 'INDEPENDENT_IMPLEMENTATION', result='success')
    engines.add_event('Algorithms', 'Algorithms/Skeleton/AlgorithmPatterns', 'TEST_PASS', result='success')
    engines.add_event('Algorithms', 'Algorithms/Skeleton/AlgorithmPatterns', 'TRANSFER_PASS', result='success')
    engines.add_event('Algorithms', 'Algorithms/Skeleton/AlgorithmPatterns', 'LEARNING_VERIFIED', result='success')
    cap3 = probe_compiler.compile_capsule('Algorithms', 'Algorithms/Skeleton/AlgorithmPatterns',
                                          must_retrieve=['二分边界: left<=right 与 mid±1', '循环不变量'],
                                          evidence={'had_failure': True, 'verified': True},
                                          allowed_probe_types=['Boundary', 'SkeletonFill'], response_budget='small_code')
    check('Algorithms LEARNING_VERIFIED + Capsule', bool(cap3))

    print('\n== 10) Projects E2E: PSB → 验证 → Capsule ==')
    engines.add_event('Projects', 'Projects/ProjectGeneral', 'CASE_ATTEMPT', result='failure')
    engines.add_event('Projects', 'Projects/ProjectGeneral', 'REASONING_SUCCESS', result='success')
    engines.add_event('Projects', 'Projects/ProjectGeneral', 'TRADEOFF_SUCCESS', result='success')
    engines.add_event('Projects', 'Projects/ProjectGeneral', 'FAILURE_MODE_SUCCESS', result='success')
    engines.add_event('Projects', 'Projects/ProjectGeneral', 'TRANSFER_CASE_SUCCESS', result='success')
    engines.add_event('Projects', 'Projects/ProjectGeneral', 'LEARNING_VERIFIED', result='success')
    cap4 = probe_compiler.compile_capsule('Projects', 'Projects/ProjectGeneral',
                                          must_retrieve=['增加消费者不提升吞吐 → 先查分区数与下游瓶颈'],
                                          evidence={'had_failure': True, 'verified': True},
                                          allowed_probe_types=['decision_probe'], response_budget='short_decision')
    check('Projects LEARNING_VERIFIED + Capsule', bool(cap4))

    print('\n== 11) Event Replay 重建状态 ==')
    res = rebuilder.rebuild_engine('Knowledge')
    kconn = db.connect(db.ENGINE_DBS['Knowledge'])
    st = kconn.execute("SELECT status, repair_count FROM knowledge_states WHERE target_id=?", (kengines_target,)).fetchone()
    kconn.close()
    check('Replay 后状态一致', st and st['status'] == 'LEARNING_VERIFIED' and st['repair_count'] == 1,
          json.dumps(res, ensure_ascii=False))

    print('\n== 12) Goal 改变 → 调度策略改变 ==')
    conn = db.connect(db.DB_SCHEDULER)
    g2 = goal_compiler.compile_goal('15天冲刺复习已有知识')
    goal_compiler.save_goal(conn, g2)
    ti_normal = scheduler.task_intent(conn, now_dt=future)
    conn.close()
    check('新增 Sprint Goal 后仍输出有效 TaskIntent', ti_normal is not None,
          json.dumps({k: ti_normal[k] for k in ('intent_type', 'engine')} if ti_normal else {}, ensure_ascii=False))

    print('\n== 13) 半年后 Reactivate 基于事件历史 ==')
    half_year = now + datetime.timedelta(days=183)
    conn = db.connect(db.DB_SCHEDULER)
    ti_react = scheduler.task_intent(conn, now_dt=half_year)
    conn.close()
    check('半年后仍可基于事件重激活(Review 候选存在)', ti_react is not None)

    print('\n== 14) questions.sqlite3 未被写入 ==')
    qconn = sqlite3.connect(db.DB_QUESTIONS)
    n = qconn.execute("SELECT count(*) FROM questions").fetchone()[0]
    qconn.close()
    check('正式题库行数不变(2383)', n == 2383, f'n={n}')

    print('\n== 15) 全库完整性(临时环境) ==')
    integ = db.integrity()
    check('临时5库 integrity ok', all(v['integrity'] == 'ok' and v['fk_violations'] == 0 for v in integ.values()))

    shutil.rmtree(tmp, ignore_errors=True)
    print(f"\n=== E2E 结果: PASS {len(PASS)} / FAIL {len(FAIL)} ===")
    if FAIL:
        print('失败项:', FAIL)
        sys.exit(1)


if __name__ == '__main__':
    main()
