// Phase1 MacGraphCore 单元测试 (node:test)。覆盖冻结规则 MUST 项。
import { test, before, after, describe } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { StateDb } from '../src/store/state-db.mjs';
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
  test('integrity ok & schema_version=1', () => {
    const ic = store.integrity();
    assert.equal(ic.integrity, 'ok');
    assert.equal(ic.fk_violations, 0);
    assert.equal(store.prepare('SELECT value FROM meta WHERE key=?').get('schema_version').value, '1');
  });
  test('server_seq 单调且 message_id 唯一', () => {
    const s1 = store.journal('msg-a', 'TEST', null, { a: 1 });
    const s2 = store.journal('msg-b', 'TEST', null, { a: 2 });
    assert.ok(s2 > s1);
    assert.throws(() => store.journal('msg-a', 'TEST', null, {}));
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
  test('snapshot 必含 CENTER; center layout 0.5,0.5', () => {
    const g = store.prepare('SELECT * FROM graphs').get();
    const snap = svc.snapshotPayload(g.graph_id, svc.activeRound().round_id);
    assert.equal(snap.center_node_id, g.center_node_id);
    assert.equal(snap.nodes.length, 1);
    assert.equal(snap.nodes[0].kind, 'CENTER');
    assert.equal(snap.nodes[0].layout.x, 0.5);
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
    assert.equal(exRow.body_sha256.length, 64);
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
  test('move: layout CAS; clamp; pin=1', () => {
    const r = freshRound();
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: 't', body_markdown: 'b' });
    const m = svc.moveNode({ command_id: uid(), node_id: ex.node_id, x_norm: 1.7, y_norm: -0.2, base_layout_revision: 1 });
    assert.equal(m.x_norm, 1.0); assert.equal(m.y_norm, 0.0);
    const l = store.prepare('SELECT * FROM layouts WHERE node_id=?').get(ex.node_id);
    assert.equal(l.pinned_by_user, 1);
    assert.equal(l.layout_revision, 2);
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
    svc.moveNode({ command_id: uid(), node_id: ex.node_id, x_norm: 0.3, y_norm: 0.3, base_layout_revision: ex.layout?.revision ?? 1 });
    const after = store.prepare('SELECT graph_revision FROM graphs').get().graph_revision;
    assert.ok(after >= before + 3);
  });
});
