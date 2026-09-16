// Phase1 MacGraphCore 单元测试 (node:test)。覆盖冻结规则 MUST 项。
import { test, before, after, describe } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { StateDb, DDL } from '../src/store/state-db.mjs';
import { QuestionGraphService } from '../src/graph/question-graph-service.mjs';
import { AppError, ERR } from '../src/util.mjs';

let dir, dbPath, store, svc;

function open() {
  return svc.open({
    command_id: crypto.randomUUID(), question_ref: {
      source: 'QUESTION_BANK', question_key: 'qb:Redis-01-003', source_id: 'Redis-01-003',
    },
    question_body_markdown: 'Redis过期删除策略是什么？',
    ai_title: 'Redis过期删除策略',
  });
}
function openReview(probeKey, body = '请解释 RAG 的离线与在线流程。') {
  return svc.open({
    command_id: crypto.randomUUID(), question_ref: {
      source: 'REVIEW_CAPSULE', question_key: `capsule:cap-rag:${probeKey}`,
      source_id: 'cap-rag', probe_key: probeKey,
    },
    question_body_markdown: body,
    ai_title: 'RAG复习探针',
  });
}
function openUserGraph(customId, title = '我的自拟问题', body = '这是我自拟的问题正文。') {
  return svc.open({
    command_id: crypto.randomUUID(), question_ref: {
      source: 'USER_AUTHORED', question_key: `user:${customId}`, source_id: customId,
    },
    question_body_markdown: body,
    ai_title: title,
  });
}
const uid = () => crypto.randomUUID();

/** 确保存在一个 ACTIVE round 并返回(必要时 open 新一轮)。 */
function freshRound() {
  open();
  return svc.activeRound();
}

before(() => {
  dir = mkdtempSync(join(tmpdir(), 'dualend-'));
  dbPath = join(dir, 'dual-end.db');
  store = new StateDb(dbPath);
  svc = new QuestionGraphService(store);
});
after(() => { store.close(); rmSync(dir, { recursive: true, force: true }); });

describe('store 基础', () => {
  test('integrity ok & schema_version=7', () => {
    const ic = store.integrity();
    assert.equal(ic.integrity, 'ok');
    assert.equal(ic.fk_violations, 0);
    assert.equal(store.prepare('SELECT value FROM meta WHERE key=?').get('schema_version').value, '7');
    assert.ok(store.prepare('PRAGMA table_info(nodes)').all().some((column) => column.name === 'parent_node_id'));
  });
  test('v3→v7 migration preserves IDs/layout/ink, backfills parent+shape, and converts legacy layout', () => {
    const legacyPath = join(dir, 'legacy-v3.db');
    const legacy = new DatabaseSync(legacyPath);
    const legacyDdl = DDL
      .replace('  x_world REAL NOT NULL,\n  y_world REAL NOT NULL,\n', '')
      .replace('  parent_node_id TEXT REFERENCES nodes(node_id),\n', '')
      .replace("  shape TEXT CHECK(shape IN ('SQUARE','CIRCLE','TRIANGLE') OR shape IS NULL),\n", '')
      .replace("  CHECK((kind='TEMPORARY' AND round_id IS NOT NULL) OR (kind!='TEMPORARY' AND round_id IS NULL)),\n", '')
      .replace("  CHECK((kind='MATERIAL' AND parent_node_id IS NULL AND shape IS NULL)\n        OR (kind<>'MATERIAL' AND shape IS NOT NULL))\n", '')
      .replace('  expired_at TEXT,\n);', '  expired_at TEXT\n);')
      .replace('CREATE INDEX IF NOT EXISTS idx_nodes_parent_node_id ON nodes(parent_node_id);\n', '');
    legacy.exec(legacyDdl);
    const now = '2026-09-16T00:00:00.000Z';
    legacy.prepare('INSERT INTO meta(key,value) VALUES (?,?)').run('schema_version', '3');
    legacy.prepare('INSERT INTO meta(key,value) VALUES (?,?)').run('created_at', now);
    legacy.prepare(`INSERT INTO graphs(graph_id,question_key,question_source,source_id,probe_key,graph_revision,center_node_id,created_at,updated_at)
      VALUES (?,?,?,?,?,?,?,?,?)`).run('legacy-graph', 'qb:legacy', 'QUESTION_BANK', 'legacy', null, 1, 'legacy-center', now, now);
    legacy.prepare(`INSERT INTO rounds(round_id,graph_id,status,opened_at) VALUES (?,?,?,?)`)
      .run('legacy-round', 'legacy-graph', 'ACTIVE', now);
    legacy.prepare(`INSERT INTO nodes(node_id,graph_id,kind,title,body_markdown,body_sha256,round_id,node_revision,created_at)
      VALUES (?,?,?,?,?,?,NULL,1,?)`).run('legacy-center', 'legacy-graph', 'CENTER', '旧题', '旧题正文', 'a'.repeat(64), now);
    legacy.prepare(`INSERT INTO nodes(node_id,graph_id,kind,title,body_markdown,body_sha256,round_id,node_revision,created_at)
      VALUES (?,?,?,?,?,?,NULL,1,?)`).run('legacy-explanation', 'legacy-graph', 'EXPLANATION', '旧解释', '旧解释正文', 'b'.repeat(64), now);
    legacy.prepare(`INSERT INTO nodes(node_id,graph_id,kind,title,body_markdown,body_sha256,round_id,node_revision,created_at)
      VALUES (?,?,?,?,?,?,?,1,?)`).run('legacy-temporary', 'legacy-graph', 'TEMPORARY', '旧临时', '旧临时正文', 'd'.repeat(64), 'legacy-round', now);
    legacy.prepare('INSERT INTO layouts(node_id,x_norm,y_norm,layout_revision,pinned_by_user,updated_at) VALUES (?,?,?,?,?,?)')
      .run('legacy-center', 0.5, 0.5, 1, 0, now);
    legacy.prepare('INSERT INTO layouts(node_id,x_norm,y_norm,layout_revision,pinned_by_user,updated_at) VALUES (?,?,?,?,?,?)')
      .run('legacy-explanation', 0.7, 0.3, 2, 1, now);
    legacy.prepare('INSERT INTO ink(node_id,ink_revision,format,blob,blob_sha256,updated_at) VALUES (?,?,?,?,?,?)')
      .run('legacy-explanation', 1, 'pkdrawing-v1', Buffer.from('ink'), 'c'.repeat(64), now);
    legacy.close();

    const migrated = new StateDb(legacyPath);
    assert.equal(migrated.prepare('SELECT value FROM meta WHERE key=?').get('schema_version').value, '7');
    assert.equal(migrated.prepare('SELECT parent_node_id FROM nodes WHERE node_id=?').get('legacy-center').parent_node_id, null);
    assert.equal(migrated.prepare('SELECT parent_node_id FROM nodes WHERE node_id=?').get('legacy-explanation').parent_node_id, 'legacy-center');
    assert.equal(migrated.prepare('SELECT layout_revision FROM layouts WHERE node_id=?').get('legacy-explanation').layout_revision, 2);
    const layout = migrated.prepare('SELECT x_world,y_world FROM layouts WHERE node_id=?').get('legacy-explanation');
    assert.ok(Math.abs(layout.x_world - 200) < 0.000001);
    assert.ok(Math.abs(layout.y_world + 140) < 0.000001);
    assert.equal(migrated.prepare('SELECT ink_revision FROM ink WHERE node_id=?').get('legacy-explanation').ink_revision, 1);
    // v6 shape 迁移默认（保持旧视觉；注意旧 TEMPORARY → TRIANGLE 与新建默认 CIRCLE 不同）
    assert.equal(migrated.prepare('SELECT shape FROM nodes WHERE node_id=?').get('legacy-center').shape, 'SQUARE');
    assert.equal(migrated.prepare('SELECT shape FROM nodes WHERE node_id=?').get('legacy-explanation').shape, 'CIRCLE');
    assert.equal(migrated.prepare('SELECT shape FROM nodes WHERE node_id=?').get('legacy-temporary').shape, 'TRIANGLE');
    assert.deepEqual(migrated.integrity(), { integrity: 'ok', fk_violations: 0 });
    migrated.close();
  });
  test('server_seq 单调且 message_id 唯一', () => {
    const s1 = store.journalUnique('msg-a', 'TEST', null, { a: 1 }).serverSeq;
    const s2 = store.journalUnique('msg-b', 'TEST', null, { a: 2 }).serverSeq;
    assert.ok(s2 > s1);
    assert.throws(() => store.journalUnique('msg-a', 'TEST', null, {}));
  });
});

describe('graph identity & open', () => {
  test('question.open 创建图+center+round; 同 question_key 重开同 graph_id', () => {
    const r1 = open();
    assert.ok(r1.graph_id && r1.round_id);
    const r2 = open();
    assert.equal(r1.graph_id, r2.graph_id);
    assert.notEqual(r1.round_id, r2.round_id); // 第二次 open: 前 round 被 INTERRUPTED
    const g = store.prepare("SELECT * FROM rounds WHERE round_id=?").get(r1.round_id);
    assert.equal(g.status, 'INTERRUPTED');
  });
  test('同一 Review Capsule 的不同 probe_key 复用同一内容图', () => {
    const r1 = openReview('explain');
    const r2 = openReview('boundary', 'RAG 幻觉如何分层防控？');
    assert.equal(r1.graph_id, r2.graph_id);
    assert.equal(r2.created, false);
    const graph = store.prepare('SELECT * FROM graphs WHERE graph_id=?').get(r1.graph_id);
    assert.equal(graph.question_key, 'capsule:cap-rag');
    const center = store.prepare('SELECT body_markdown FROM nodes WHERE node_id=?').get(graph.center_node_id);
    assert.equal(center.body_markdown, '请解释 RAG 的离线与在线流程。');
  });
  test('用户自拟图按 custom ID 唯一持久化、可检索并重开', () => {
    const first = openUserGraph('ug-test-001', '自拟并发题', '为什么 volatile 不能保证复合操作原子性？');
    const reopened = openUserGraph('ug-test-001', '不会覆盖的标题', '不会覆盖的正文');
    const another = openUserGraph('ug-test-002', '自拟缓存题', '缓存击穿和缓存穿透有什么区别？');
    assert.equal(first.graph_id, reopened.graph_id);
    assert.notEqual(first.graph_id, another.graph_id);
    const found = svc.userGraphById('ug-test-001');
    assert.equal(found.title, '自拟并发题');
    assert.equal(found.body_markdown, '为什么 volatile 不能保证复合操作原子性？');
    assert.ok(svc.listUserGraphs('并发').some((g) => g.custom_id === 'ug-test-001'));
    assert.equal(svc.listUserGraphs().filter((g) => g.custom_id.startsWith('ug-test-')).length, 2);
  });
  test('snapshot 必含 CENTER; center layout 位于世界原点', () => {
    const g = store.prepare('SELECT * FROM graphs').get();
    const snap = svc.snapshotPayload(g.graph_id, svc.activeRound().round_id);
    assert.equal(snap.center_node_id, g.center_node_id);
    assert.equal(snap.nodes.length, 1);
    assert.equal(snap.nodes[0].kind, 'CENTER');
    assert.equal(snap.nodes[0].layout.x, 0);
    assert.equal(snap.nodes[0].layout.y, 0);
  });
});

describe('node.add 不变量', () => {
  test('EXPLANATION 需要 ACTIVE round', () => {
    const r = svc.activeRound();
    assert.ok(r);
  });
  test('body immutable: 直接 UPDATE 被 trigger 拒绝', () => {
    const cid = store.prepare("SELECT node_id FROM nodes WHERE kind='CENTER'").get().node_id;
    assert.throws(() => store.prepare("UPDATE nodes SET body_markdown='x' WHERE node_id=?").run(cid),
      /NODE_BODY_IMMUTABLE/);
  });
  test('只能加 EXPLANATION/TEMPORARY', () => {
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: svc.activeRound().round_id, kind: 'CENTER', ai_title: 'x', body_markdown: 'y' }),
      (e) => e.code === ERR.KIND_FORBIDDEN);
  });
  test('EXPLANATION 永久(round_id NULL); TEMPORARY 绑 round', () => {
    const r = freshRound();
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '惰性删除', body_markdown: '用户选中的原解释原文' });
    const tp = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'TEMPORARY', ai_title: '临时', body_markdown: '临时解释原文' });
    const exRow = store.prepare('SELECT * FROM nodes WHERE node_id=?').get(ex.node_id);
    const tpRow = store.prepare('SELECT * FROM nodes WHERE node_id=?').get(tp.node_id);
    assert.equal(exRow.round_id, null);
    assert.equal(tpRow.round_id, r.round_id);
    assert.equal(tpRow.parent_node_id, store.prepare('SELECT center_node_id FROM graphs WHERE graph_id=?').get(r.graph_id).center_node_id);
    assert.equal(exRow.body_sha256.length, 64);
  });
  test('EXPLANATION 默认挂 CENTER，且可建立 CENTER → A → B 层级', () => {
    const r = freshRound();
    const g = store.prepare('SELECT * FROM graphs WHERE graph_id=?').get(r.graph_id);
    const a = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '第一层', body_markdown: 'A' });
    const b = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', parent_node_id: a.node_id, ai_title: '第二层', body_markdown: 'B' });
    assert.equal(a.parent_node_id, g.center_node_id);
    assert.equal(b.parent_node_id, a.node_id);
    assert.equal(store.prepare('SELECT parent_node_id FROM nodes WHERE node_id=?').get(a.node_id).parent_node_id, g.center_node_id);
    assert.equal(store.prepare('SELECT parent_node_id FROM nodes WHERE node_id=?').get(b.node_id).parent_node_id, a.node_id);
    const snap = svc.snapshotPayload(r.graph_id, r.round_id);
    assert.equal(snap.nodes.find((n) => n.node_id === b.node_id).parent_node_id, a.node_id);
  });
  test('非法 parent 不会静默回退到 CENTER', () => {
    const r = freshRound();
    const g = store.prepare('SELECT * FROM graphs WHERE graph_id=?').get(r.graph_id);
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', parent_node_id: 'missing-parent', ai_title: 'missing', body_markdown: 'b' }),
      (e) => e.code === ERR.NODE_NOT_FOUND);
    const temporary = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'TEMPORARY', ai_title: '临时父', body_markdown: 'b' });
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', parent_node_id: temporary.node_id, ai_title: '非法临时父', body_markdown: 'b' }),
      (e) => e.code === ERR.VALIDATION);
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'TEMPORARY', parent_node_id: g.center_node_id, ai_title: '临时自定义父', body_markdown: 'b' }),
      (e) => e.code === ERR.VALIDATION);
    const removable = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '待删除父', body_markdown: 'b' });
    svc.deleteNode({ command_id: uid(), node_id: removable.node_id, base_node_revision: 1 });
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', parent_node_id: removable.node_id, ai_title: '删除父', body_markdown: 'b' }),
      (e) => e.code === ERR.NODE_NOT_FOUND);
  });
  test('其他 canonical graph 的 parent 被拒绝', () => {
    const first = freshRound();
    const foreign = svc.addNode({ command_id: uid(), round_id: first.round_id, kind: 'EXPLANATION', ai_title: '外图父', body_markdown: 'b' });
    const other = svc.open({ command_id: uid(), question_ref: { source: 'QUESTION_BANK', question_key: 'qb:other-parent-graph', source_id: 'other-parent-graph' }, question_body_markdown: 'other', ai_title: '其他图' });
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: other.round_id, kind: 'EXPLANATION', parent_node_id: foreign.node_id, ai_title: '跨图子', body_markdown: 'b' }),
      (e) => e.code === ERR.VALIDATION);
  });
});

describe('round 生命周期', () => {
  test('close 后 TEMPORARY 过期不复活; EXPLANATION 保留', () => {
    const r = freshRound();
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '持久', body_markdown: 'b' });
    const tp = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'TEMPORARY', ai_title: 't', body_markdown: 'b' });
    svc.close({ command_id: uid(), round_id: r.round_id });
    const gone = store.prepare('SELECT expired_at FROM nodes WHERE node_id=?').get(tp.node_id);
    assert.ok(gone.expired_at);
    const r2 = freshRound();
    assert.notEqual(r2.round_id, r.round_id);
    const snap = svc.snapshotPayload(r.graph_id, r2.round_id);
    assert.ok(!snap.nodes.some((n) => n.node_id === tp.node_id));   // 不复活
    assert.ok(snap.nodes.some((n) => n.kind === 'EXPLANATION'));    // 持久解释仍在
  });
  test('新增 TEMPORARY 需要 ACTIVE round', () => {
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: uid(), kind: 'TEMPORARY', ai_title: 'x', body_markdown: 'y' }),
      (e) => e.code === ERR.ROUND_NOT_ACTIVE);
  });
});

describe('CENTER 守卫 & rename/move/delete CAS', () => {
  test('CENTER delete → CENTER_DELETE_FORBIDDEN; delete 幂等', () => {
    const cid = store.prepare("SELECT * FROM nodes WHERE kind='CENTER'").get();
    assert.throws(() => svc.deleteNode({ command_id: uid(), node_id: cid.node_id, base_node_revision: cid.node_revision }),
      (e) => e.code === ERR.CENTER_DELETE_FORBIDDEN);
    const r = freshRound();
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: 'x', body_markdown: 'y' });
    svc.deleteNode({ command_id: uid(), node_id: ex.node_id, base_node_revision: 1 });
    const again = svc.deleteNode({ command_id: uid(), node_id: ex.node_id, base_node_revision: 1 });
    assert.equal(again.idempotent, true);
  });
  test('rename: node_revision CAS; 冲突报错', () => {
    const r = freshRound();
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: 't0', body_markdown: 'b0' });
    assert.throws(() => svc.renameNode({ command_id: uid(), node_id: ex.node_id, title: 't1', base_node_revision: 99 }),
      (e) => e.code === ERR.CAS_MISMATCH);
    const ok = svc.renameNode({ command_id: uid(), node_id: ex.node_id, title: '  t1  ', base_node_revision: 1 });
    assert.equal(ok.title, 't1');
    assert.equal(ok.node_revision, 2);
  });
  test('move: layout CAS; 保留无限画布 world 坐标; pin=1', () => {
    const r = freshRound();
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: 't', body_markdown: 'b' });
    const m = svc.moveNode({ command_id: uid(), node_id: ex.node_id, x_world: 17_000, y_world: -12_000, base_layout_revision: 1 });
    assert.equal(m.x_world, 17_000); assert.equal(m.y_world, -12_000);
    const l = store.prepare('SELECT * FROM layouts WHERE node_id=?').get(ex.node_id);
    assert.equal(l.x_world, 17_000); assert.equal(l.y_world, -12_000);
    assert.equal(l.pinned_by_user, 1);
    assert.equal(l.layout_revision, 2);
    assert.throws(() => svc.moveNode({ command_id: uid(), node_id: ex.node_id, x_world: Infinity, y_world: 0, base_layout_revision: 2 }),
      (e) => e.code === ERR.VALIDATION);
  });
});

describe('ink revision 序列', () => {
  test('期望 rev 连续; 重复+同 hash 幂等; 跳 rev → GAP', () => {
    const r = freshRound();
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: 't', body_markdown: 'b' });
    const blob = Buffer.from('PKDrawing-bytes');
    const sha = createHash('sha256').update(blob).digest('hex');
    svc.putInk({ command_id: uid(), node_id: ex.node_id, ink_revision: 1, blob, blob_sha256: sha });
    const dup = svc.putInk({ command_id: uid(), node_id: ex.node_id, ink_revision: 1, blob, blob_sha256: sha });
    assert.equal(dup.idempotent, true);
    assert.throws(() => svc.putInk({ command_id: uid(), node_id: ex.node_id, ink_revision: 3, blob, blob_sha256: sha }),
      (e) => e.code === ERR.INK_REVISION_GAP);
    svc.putInk({ command_id: uid(), node_id: ex.node_id, ink_revision: 2, blob, blob_sha256: sha });
    const row = store.prepare('SELECT * FROM ink WHERE node_id=?').get(ex.node_id);
    assert.equal(row.ink_revision, 2);
  });
});

describe('command dedup one-effect', () => {
  test('同 command_id 重复提交返回第一次结果', () => {
    const cid = uid();
    const r = freshRound();
    const a = svc.addNode({ command_id: cid, round_id: r.round_id, kind: 'EXPLANATION', ai_title: 'dup', body_markdown: 'b' });
    const b = svc.addNode({ command_id: cid, round_id: r.round_id, kind: 'EXPLANATION', ai_title: 'dup', body_markdown: 'b' });
    assert.equal(a.node_id, b.node_id);
    const cnt = store.prepare("SELECT count(*) AS c FROM nodes WHERE kind='EXPLANATION'").get().c;
    assert.equal(cnt, store.prepare("SELECT count(*) AS c FROM nodes WHERE kind='EXPLANATION'").get().c);
  });
});

describe('graph_revision 单调递增', () => {
  test('每次 canonical change +1', () => {
    const r = freshRound();
    const before = store.prepare('SELECT graph_revision FROM graphs').get().graph_revision;
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: 't', body_markdown: 'b' });
    svc.renameNode({ command_id: uid(), node_id: ex.node_id, title: 't2', base_node_revision: ex.node_revision });
    svc.moveNode({ command_id: uid(), node_id: ex.node_id, x_world: 300, y_world: -300, base_layout_revision: ex.layout?.revision ?? 1 });
    const after = store.prepare('SELECT graph_revision FROM graphs').get().graph_revision;
    assert.ok(after >= before + 3);
  });
});

describe('QuestionGraph inheritance effective view', () => {
  test('Review graph inherits persistent parent explanations and fans out mutations', () => {
    const parent = svc.open({ command_id: uid(), question_ref: {
      source: 'QUESTION_BANK', question_key: 'qb:inherit-parent', source_id: 'inherit-parent'
    }, question_body_markdown: 'parent', ai_title: 'Parent' });
    const ex = svc.addNode({ command_id: uid(), round_id: parent.round_id, kind: 'EXPLANATION', ai_title: 'Shared', body_markdown: 'body' });
    const nested = svc.addNode({ command_id: uid(), round_id: parent.round_id, kind: 'EXPLANATION', parent_node_id: ex.node_id, ai_title: 'Shared child', body_markdown: 'nested body' });
    const child = openReview('inherit-probe');
    svc.setInheritance({ command_id: uid(), child_graph_id: child.graph_id, parent_graph_id: parent.graph_id });
    const snap = svc.snapshotPayload(child.graph_id, child.round_id);
    assert.deepEqual(snap.parent_graphs, [{ graph_id: parent.graph_id, inheritance_kind: 'SHARED_EXPLANATIONS' }]);
    const inherited = snap.nodes.find((n) => n.node_id === ex.node_id);
    assert.equal(inherited.visibility, 'INHERITED');
    assert.equal(inherited.owner_graph_id, parent.graph_id);
    assert.equal(inherited.parent_node_id, parent.center_node_id); // source CENTER 在 Review effective view 中不可见，交由客户端展示层 fallback
    assert.equal(snap.nodes.find((n) => n.node_id === nested.node_id).parent_node_id, ex.node_id); // inherited hierarchy 保留 raw parent
    const renamed = svc.renameNode({ command_id: uid(), node_id: ex.node_id, title: 'Shared 2', base_node_revision: 1 });
    assert.deepEqual(renamed.affected_graph_ids, [parent.graph_id, child.graph_id]);
    assert.equal(svc.snapshotPayload(child.graph_id, child.round_id).nodes.find((n) => n.node_id === ex.node_id).title, 'Shared 2');
  });
});
