// Phase2 Bridge E2E —— Node 模拟 iPad 走完 9 步 (M-14.3)。
// 覆盖: 自动连接/HELLO-WELCOME/新 epoch/question.open→snapshot/add→patch/
// CLIENT_COMMAND→ACK+patch/重复消息 one-effect/重连新 epoch/revision mismatch→snapshot。
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Daemon } from '../src/daemon.mjs';
import { WsTestClient } from './ws-test-client.mjs';

const NOLOG = { info() {}, warn() {}, error() {} };
let dir, daemon, port, client;
const uid = () => crypto.randomUUID();

async function localCommand(payload) {
  const res = await fetch(`http://127.0.0.1:${port}/command`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return res.json();
}
const openQuestion = (qk = 'qb:Redis-01-003') => localCommand({
  command_id: uid(), kind: 'question.open',
  question_ref: { source: 'QUESTION_BANK', question_key: qk, source_id: 'Redis-01-003' },
  question_body_markdown: 'Redis过期删除策略是什么？', ai_title: 'Redis过期删除策略',
});

before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'dualend-e2e-'));
  daemon = new Daemon({ dataDir: join(dir, 'data'), logger: NOLOG });
  await daemon.start();
  port = daemon.controlPort;
  client = new WsTestClient();
  await client.connect(port);
});

after(async () => {
  client?.close();
  await daemon?.stop();
  rmSync(dir, { recursive: true, force: true });
});

test('1-2. connect + HELLO → WELCOME(新 session_epoch)', async () => {
  client.sendJson({
    v: 1, message_id: uid(), type: 'HELLO', session_epoch: null, sent_at: new Date().toISOString(),
    payload: { device_id: 'test-ipad-A', client_build: '1.0.0', supported_protocols: [1], last_server_seq: 0, cached_graph: null },
  });
  const w = await client.waitJson((m) => m.type === 'WELCOME');
  assert.equal(w.payload.selected_protocol, 1);
  assert.ok(w.payload.session_epoch);
  firstEpoch = w.payload.session_epoch;
  assert.equal(w.payload.daemon_id, daemon.daemonId);
});

let firstEpoch = null;
test('3-4. question.open → iPad 收到 GRAPH_SNAPSHOT(含 CENTER)', async () => {
  const snapP = client.waitJson((m) => m.type === 'GRAPH_SNAPSHOT');
  const r = await openQuestion();
  assert.ok(r.round_id);
  const snap = await snapP;
  assert.equal(snap.payload.question_key, 'qb:Redis-01-003');
  assert.equal(snap.payload.nodes.find((n) => n.kind === 'CENTER').body_markdown, 'Redis过期删除策略是什么？');
});

test('5. graph.add-node(EXPLANATION) → GRAPH_PATCH ADD_NODE', async () => {
  const r = await openQuestion();
  const patch = client.waitJson((m) => m.type === 'GRAPH_PATCH');
  const addRes = await localCommand({ command_id: uid(), kind: 'graph.add-node', round_id: r.round_id, node_kind: 'EXPLANATION', ai_title: '惰性与定期删除', body_markdown: '惰性删除每次取时检查过期; 定期删除周期扫库' });
  assert.ok(addRes.node_id);
  const p = await patch;
  assert.ok(p.payload.ops.some((o) => o.op === 'ADD_NODE' && o.node.kind === 'EXPLANATION'));
});

test('6. CLIENT_COMMAND move → COMMAND_ACK(canonical) + patch', async () => {
  await openQuestion();
  const snapRes = await fetch(`http://127.0.0.1:${port}/graph/snapshot`).then((r) => r.json());
  const center = snapRes.nodes.find((n) => n.kind === 'CENTER');
  const ackP = client.waitJson((m) => m.type === 'COMMAND_ACK');
  client.sendJson({
    v: 1, message_id: uid(), type: 'CLIENT_COMMAND', session_epoch: null, sent_at: new Date().toISOString(),
    payload: { command_id: uid(), kind: 'MOVE_NODE', graph_id: snapRes.graph_id, payload: { node_id: center.node_id, x_norm: 0.8, y_norm: 0.2, base_layout_revision: center.layout.revision } },
  });
  const ack = await ackP;
  assert.ok(ack.payload.canonical.layout_revision >= 2);
});

test('7. 重复 command → one effect', async () => {
  const snapRes = await fetch(`http://127.0.0.1:${port}/graph/snapshot`).then((r) => r.json());
  const center = snapRes.nodes.find((n) => n.kind === 'CENTER');
  const cmdId = uid();
  const curRev = center.node_revision;
  const ack1 = client.waitJson((m) => m.type === 'COMMAND_ACK' && m.payload.command_id === cmdId);
  const payload = { command_id: cmdId, kind: 'RENAME_NODE', graph_id: snapRes.graph_id, payload: { node_id: center.node_id, title: '题目改一次', base_node_revision: curRev } };
  client.sendJson({ v: 1, message_id: uid(), type: 'CLIENT_COMMAND', session_epoch: null, sent_at: new Date().toISOString(), payload });
  client.sendJson({ v: 1, message_id: uid(), type: 'CLIENT_COMMAND', session_epoch: null, sent_at: new Date().toISOString(), payload }); // 重复
  const ack = await ack1;
  const row = daemon.store.prepare('SELECT title FROM nodes WHERE node_id=?').get(center.node_id);
  assert.equal(row.title, '题目改一次');
  const titles = daemon.store.prepare('SELECT count(*) c FROM nodes WHERE title=?').get('题目改一次');
  assert.equal(titles.c, 1);
});

test('8. 重连 → 新 session_epoch 隔离', async () => {
  client.close();
  await new Promise((r) => setTimeout(r, 150));
  const c2 = new WsTestClient();
  await c2.connect(port);
  c2.sendJson({ v: 1, message_id: uid(), type: 'HELLO', session_epoch: null, sent_at: new Date().toISOString(), payload: { device_id: 'test-ipad-A', client_build: '1.0.0', supported_protocols: [1], last_server_seq: 0, cached_graph: { graph_id: 'g', revision: 0 } } });
  const w = await c2.waitJson((m) => m.type === 'WELCOME');
  assert.ok(w.payload.session_epoch);
  assert.notEqual(w.payload.session_epoch, firstEpoch);   // 新 epoch 隔离旧会话
  client = c2;
});

test('9. revision mismatch → 请求 snapshot 恢复', async () => {
  // 用过期 layout_revision 发 move → COMMAND_REJECTED CAS_MISMATCH
  const snap = await fetch(`http://127.0.0.1:${port}/graph/snapshot`).then((r) => r.json());
  const node = snap.nodes.find((n) => n.kind !== 'CENTER') ?? snap.nodes.find((n) => n.kind === 'CENTER');
  const rejP = client.waitJson((m) => m.type === 'COMMAND_REJECTED');
  client.sendJson({
    v: 1, message_id: uid(), type: 'CLIENT_COMMAND', session_epoch: null, sent_at: new Date().toISOString(),
    payload: { command_id: uid(), kind: 'MOVE_NODE', graph_id: snap.graph_id, payload: { node_id: node.node_id, x_norm: 0.1, y_norm: 0.1, base_layout_revision: 999 } },
  });
  const rej = await rejP;
  assert.equal(rej.payload.reason, 'CAS_MISMATCH');
  // snapshot 请求恢复
  const snapP = client.waitJson((m) => m.type === 'GRAPH_SNAPSHOT');
  client.sendJson({ v: 1, message_id: uid(), type: 'SNAPSHOT_REQUEST', session_epoch: null, sent_at: new Date().toISOString(), payload: { graph_id: snap.graph_id } });
  const s2 = await snapP;
  assert.equal(s2.payload.graph_id, snap.graph_id);
  assert.ok(s2.payload.revision >= 1);
});
