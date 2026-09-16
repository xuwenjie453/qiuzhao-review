// v6: NodeShape 与 NodeKind 正交 —— shape 是 canonical node metadata，渲染只读 shape。
// 覆盖: creation default、migration default 差异、SET_NODE_SHAPE、CAS、不变量、snapshot round-trip。
import { test, before, after, describe } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { StateDb } from '../src/store/state-db.mjs';
import { QuestionGraphService } from '../src/graph/question-graph-service.mjs';
import { Daemon } from '../src/daemon.mjs';
import { WsTestClient } from './ws-test-client.mjs';

let dir, store, svc;
const uid = () => crypto.randomUUID();

before(() => {
  dir = mkdtempSync(join(tmpdir(), 'dualend-shape-'));
  store = new StateDb(join(dir, 'state', 'dual-end.db'));
  svc = new QuestionGraphService(store);
});
after(() => { store.close(); rmSync(dir, { recursive: true, force: true }); });

function openGraph(tag = 'shape') {
  return svc.open({
    command_id: uid(),
    question_ref: { source: 'QUESTION_BANK', question_key: `qb:shape-${tag}`, source_id: `shape-${tag}` },
    question_body_markdown: '这是 shape 测试题面。',
    ai_title: 'Shape测试题',
  });
}
function nodeRow(nodeId) { return store.prepare('SELECT * FROM nodes WHERE node_id=?').get(nodeId); }
function layoutRow(nodeId) { return store.prepare('SELECT * FROM layouts WHERE node_id=?').get(nodeId); }

describe('node shape (v6: kind 与 shape 正交)', () => {
  test('新建 CENTER 默认为 SQUARE', () => {
    const r = openGraph('center');
    assert.equal(nodeRow(r.center_node_id).shape, 'SQUARE');
  });

  test('新建 EXPLANATION 默认为 CIRCLE；新建 TEMPORARY 默认为 CIRCLE（≠ 旧数据迁移默认）', () => {
    const r = openGraph('creation-defaults');
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION',
      ai_title: '一个解释', body_markdown: '解释正文' });
    assert.equal(nodeRow(ex.node_id).shape, 'CIRCLE');
    const tp = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'TEMPORARY',
      ai_title: '一个临时', body_markdown: '临时正文' });
    assert.equal(nodeRow(tp.node_id).shape, 'CIRCLE');
  });

  test('SET_NODE_SHAPE: shape 改变 + node_revision/graph_revision 增长，其余不变量保持', () => {
    const r = openGraph('set-shape');
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION',
      ai_title: '待改形状', body_markdown: '正文不变' });
    const before = nodeRow(ex.node_id);
    const layBefore = layoutRow(ex.node_id);
    const graphBefore = svc.graphGet(r.graph_id).graph_revision;

    const res = svc.setNodeShape({ command_id: uid(), node_id: ex.node_id, shape: 'TRIANGLE',
      base_node_revision: before.node_revision, actor: 'IPAD' });
    assert.equal(res.shape, 'TRIANGLE');
    assert.equal(res.node_revision, before.node_revision + 1);

    const after = nodeRow(ex.node_id);
    // 只允许 shape / node_revision 变
    assert.equal(after.shape, 'TRIANGLE');
    assert.equal(after.node_revision, before.node_revision + 1);
    // 不变量
    assert.equal(after.kind, before.kind);
    assert.equal(after.parent_node_id, before.parent_node_id);
    assert.equal(after.body_markdown, before.body_markdown);
    assert.equal(after.body_sha256, before.body_sha256);
    assert.equal(after.round_id, before.round_id);
    assert.equal(after.graph_id, before.graph_id);
    assert.deepEqual(layoutRow(ex.node_id), layBefore);
    assert.ok(svc.graphGet(r.graph_id).graph_revision > graphBefore);
  });

  test('CENTER 也允许改 shape（无 kind 例外）', () => {
    const r = openGraph('center-shape');
    const c = nodeRow(r.center_node_id);
    svc.setNodeShape({ command_id: uid(), node_id: r.center_node_id, shape: 'CIRCLE',
      base_node_revision: c.node_revision });
    assert.equal(nodeRow(r.center_node_id).shape, 'CIRCLE');
  });

  test('任意 kind × 任意 shape 组合都被 service 允许', () => {
    const r = openGraph('matrix');
    const combos = [
      ['EXPLANATION', 'SQUARE'], ['EXPLANATION', 'TRIANGLE'],
      ['TEMPORARY', 'SQUARE'], ['TEMPORARY', 'TRIANGLE'],
    ];
    for (const [kind, shape] of combos) {
      const n = svc.addNode({ command_id: uid(), round_id: r.round_id, kind,
        ai_title: `${kind}${shape}`, body_markdown: '组合正文' });
      svc.setNodeShape({ command_id: uid(), node_id: n.node_id, shape,
        base_node_revision: nodeRow(n.node_id).node_revision });
      assert.equal(nodeRow(n.node_id).shape, shape);
      assert.equal(nodeRow(n.node_id).kind, kind);
    }
  });

  test('非法 shape 被拒绝（VALIDATION）且不产生变更', () => {
    const r = openGraph('invalid');
    const c = nodeRow(r.center_node_id);
    assert.throws(
      () => svc.setNodeShape({ command_id: uid(), node_id: r.center_node_id, shape: 'HEXAGON',
        base_node_revision: c.node_revision }),
      (e) => e.code === 'VALIDATION'
    );
    assert.equal(nodeRow(r.center_node_id).shape, c.shape);
    assert.equal(nodeRow(r.center_node_id).node_revision, c.node_revision);
  });

  test('SET_NODE_SHAPE 遵守 CAS（陈旧 base_node_revision 被拒）', () => {
    const r = openGraph('cas');
    const c = nodeRow(r.center_node_id);
    assert.throws(
      () => svc.setNodeShape({ command_id: uid(), node_id: r.center_node_id, shape: 'TRIANGLE',
        base_node_revision: c.node_revision - 1 }),
      (e) => e.code === 'CAS_MISMATCH'
    );
  });

  test('SET_NODE_SHAPE 命令幂等（同 command_id 重放返回同一结果）', () => {
    const r = openGraph('idem');
    const c = nodeRow(r.center_node_id);
    const cmd = uid();
    const first = svc.setNodeShape({ command_id: cmd, node_id: r.center_node_id, shape: 'TRIANGLE',
      base_node_revision: c.node_revision });
    const second = svc.setNodeShape({ command_id: cmd, node_id: r.center_node_id, shape: 'TRIANGLE',
      base_node_revision: c.node_revision });
    assert.deepEqual(second, first);
    // one-effect: revision 只前进一次
    assert.equal(nodeRow(r.center_node_id).node_revision, c.node_revision + 1);
  });

  test('snapshot 携带每个节点的 shape（round-trip）', () => {
    const r = openGraph('snapshot');
    const ex = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION',
      ai_title: '快照节点', body_markdown: '快照正文' });
    svc.setNodeShape({ command_id: uid(), node_id: ex.node_id, shape: 'TRIANGLE',
      base_node_revision: nodeRow(ex.node_id).node_revision });
    const snap = svc.snapshotPayload(r.graph_id, r.round_id);
    const center = snap.nodes.find((n) => n.node_id === r.center_node_id);
    const expl = snap.nodes.find((n) => n.node_id === ex.node_id);
    assert.equal(center.shape, 'SQUARE');
    assert.equal(expl.shape, 'TRIANGLE');
    assert.equal(expl.kind, 'EXPLANATION');
  });

  test('SQLite CHECK 兜底：绕过 service 的非法 shape 写入被数据库拒绝', () => {
    const r = openGraph('dbcheck');
    assert.throws(() => {
      store.prepare('UPDATE nodes SET shape=? WHERE node_id=?').run('HEXAGON', r.center_node_id);
    }, /CHECK constraint failed/);
  });
});

// ---------- WS 端到端：iPad CLIENT_COMMAND 路径（本次 bug 的回归守卫） ----------
// 背景：runCommand 曾漏掉 SET_NODE_SHAPE case，导致 iPad 改形状收到
// UNKNOWN_COMMAND_KIND。此处锁定“iPad 命令路径”与 service 路径同等重要。
describe('SET_NODE_SHAPE over CLIENT_COMMAND (iPad 路径端到端)', () => {
  const uid2 = () => crypto.randomUUID();
  let dir2, daemon, client;
  before(async () => {
    dir2 = mkdtempSync(join(tmpdir(), 'dualend-shape-ws-'));
    daemon = new Daemon({ dataDir: join(dir2, 'data'), logger: { info() {}, warn() {}, error() {} } });
    await daemon.start();
    client = new WsTestClient();
    await client.connect(daemon.bridgePort);
  });
  after(async () => { client?.close(); await daemon?.stop(); rmSync(dir2, { recursive: true, force: true }); });

  test('iPad 发 SET_NODE_SHAPE → COMMAND_ACK + UPDATE_SHAPE patch + canonical 更新', async () => {
    const helloP = client.waitJson((m) => m.type === 'WELCOME');
    client.sendJson({ v: 4, message_id: uid2(), type: 'HELLO', session_epoch: null, sent_at: new Date().toISOString(),
      payload: { device_id: 'shape-ws-ipad', client_build: '4.0.0', supported_protocols: [4], last_server_seq: 0, cached_graph: null } });
    const w = await helloP;
    const epoch = w.payload.session_epoch;

    const snapP = client.waitJson((m) => m.type === 'GRAPH_SNAPSHOT');
    await fetch(`http://127.0.0.1:${daemon.controlPort}/command`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ command_id: uid2(), kind: 'question.open',
        question_ref: { source: 'QUESTION_BANK', question_key: 'qb:shape-ws', source_id: 'shape-ws' },
        question_body_markdown: '形状 WS 测试题干', ai_title: '形状WS' }),
    });
    const snap = await snapP;
    const graphId = snap.payload.graph_id;
    const center = snap.payload.nodes.find((n) => n.kind === 'CENTER');
    client.sendJson({ v: 4, message_id: uid2(), type: 'ACK', session_epoch: epoch,
      sent_at: new Date().toISOString(), payload: { message_id: snap.message_id } });

    const cmdId = uid2();
    const ackP = client.waitJson((m) => m.type === 'COMMAND_ACK' && m.payload.command_id === cmdId);
    const patchP = client.waitJson((m) => m.type === 'GRAPH_PATCH');
    client.sendJson({ v: 4, message_id: uid2(), type: 'CLIENT_COMMAND', session_epoch: epoch,
      sent_at: new Date().toISOString(),
      payload: { command_id: cmdId, kind: 'SET_NODE_SHAPE', graph_id: graphId,
        payload: { node_id: center.node_id, shape: 'TRIANGLE', base_node_revision: center.node_revision } } });

    const ack = await ackP;   // 若 runCommand 缺 case，这里会等到 COMMAND_REJECTED(UNKNOWN_COMMAND_KIND) 而超时失败
    assert.ok(ack, 'SET_NODE_SHAPE 必须被服务端识别');
    const patch = await patchP;
    const op = patch.payload.ops.find((o) => o.op === 'UPDATE_SHAPE');
    assert.ok(op, 'patch 必须含 UPDATE_SHAPE');
    assert.equal(op.shape, 'TRIANGLE');
    assert.equal(op.node_id, center.node_id);
    assert.equal(daemon.store.prepare('SELECT shape FROM nodes WHERE node_id=?').get(center.node_id).shape, 'TRIANGLE');
  });
});
