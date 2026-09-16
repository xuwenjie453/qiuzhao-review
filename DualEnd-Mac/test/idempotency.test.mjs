// 幂等重放测试 (dual_end_repair_prompt_pack 02_MAC_FIX/03_MAC_TESTS)。
// 覆盖: 同消息重放复用 seq / 语义冲突拒绝 / CLIENT_COMMAND 与 INK_PUT 重放
// one-effect + 补 ACK / WELCOME 多会话唯一 / ACK 丢失自愈 / 存量行兼容。
// 注意: WsTestClient 无消息缓冲, 所有 waitJson 必须先注册再触发。
import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Daemon } from '../src/daemon.mjs';
import { StateDb } from '../src/store/state-db.mjs';
import { WsTestClient } from './ws-test-client.mjs';

const NOLOG = { info() {}, warn() {}, error() {} };
const uid = () => crypto.randomUUID();
const envelope = (type, sessionEpoch, payload, messageId = uid()) => ({
  v: 4, message_id: messageId, type, session_epoch: sessionEpoch,
  sent_at: new Date().toISOString(), payload,
});
const HELLO_PAYLOAD = (device) => ({
  device_id: device, client_build: '4.0.0', supported_protocols: [4], last_server_seq: 0, cached_graph: null,
});

// ---------- Store 层 ----------
describe('StateDb journalReplayable / journalUnique', () => {
  let dir, store;
  before(() => {
    dir = mkdtempSync(join(tmpdir(), 'dualend-idem-'));
    store = new StateDb(join(dir, 'state', 'dual-end.db'));
  });
  after(() => { store.close(); rmSync(dir, { recursive: true, force: true }); });

  test('1. 同一消息两次 journalReplayable → 同 server_seq, 第二次 replay=true', () => {
    const first = store.journalReplayable('m1', 'CLIENT_COMMAND', 'g1', { command_id: 'c1', result: { v: 1 } });
    const second = store.journalReplayable('m1', 'CLIENT_COMMAND', 'g1', { command_id: 'c1', result: { v: 1 } });
    assert.equal(first.replay, false);
    assert.equal(second.replay, true);
    assert.equal(second.serverSeq, first.serverSeq);
  });

  test('2. 同 message_id 不同语义 → MESSAGE_ID_REUSE_CONFLICT, 不得静默 ACK', () => {
    store.journalReplayable('m2', 'CLIENT_COMMAND', 'g1', { command_id: 'c2', result: { v: 1 } });
    assert.throws(
      () => store.journalReplayable('m2', 'CLIENT_COMMAND', 'g1', { command_id: 'c2', result: { v: 999 } }),
      (e) => e.code === 'MESSAGE_ID_REUSE_CONFLICT'
    );
    assert.throws(
      () => store.journalReplayable('m2', 'INK_PUT', 'g1', { command_id: 'c2', result: { v: 1 } }),
      (e) => e.code === 'MESSAGE_ID_REUSE_CONFLICT'
    );
  });

  test('2b. 存量插入序 JSON 行兼容: 解析后语义一致即视为重放', () => {
    store.prepare(
      'INSERT INTO sync_journal(message_id, kind, graph_id, payload_json, committed_at) VALUES (?,?,?,?,?)'
    ).run('legacy-1', 'INK_PUT', 'g1', JSON.stringify({ node_id: 'n1', ink_revision: 3 }), '2026-09-13T00:00:00Z');
    const r = store.journalReplayable('legacy-1', 'INK_PUT', 'g1', { ink_revision: 3, node_id: 'n1' });
    assert.equal(r.replay, true);
  });

  test('journalUnique 重复仍抛错(服务端自产事件重复=bug)', () => {
    store.journalUnique('u1', 'GRAPH_PATCH', 'g1', { p: 1 });
    assert.throws(() => store.journalUnique('u1', 'GRAPH_PATCH', 'g1', { p: 1 }));
  });
});

// ---------- 会话层(E2E: 真实 daemon + WS 客户端) ----------
let dir, daemon, controlPort, bridgePort, client;

before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'dualend-idem-e2e-'));
  daemon = new Daemon({ dataDir: join(dir, 'data'), logger: NOLOG });
  await daemon.start();
  controlPort = daemon.controlPort;
  bridgePort = daemon.bridgePort;
  client = new WsTestClient();
  await client.connect(bridgePort);
});

after(async () => {
  client?.close();
  await daemon?.stop();
  rmSync(dir, { recursive: true, force: true });
});

async function openQuestionAndAwaitSnapshot(epoch, qk = 'qb:MySQL-01-001') {
  const snapP = client.waitJson((m) => m.type === 'GRAPH_SNAPSHOT');
  const res = await fetch(`http://127.0.0.1:${controlPort}/command`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ command_id: uid(), kind: 'question.open',
      question_ref: { source: 'QUESTION_BANK', question_key: qk, source_id: qk.replace('qb:', '') },
      question_body_markdown: '什么是间隙锁？', ai_title: '幂等测试' }),
  });
  assert.equal(res.status, 200);
  const snap = await snapP;
  // snapshot 的 ACK(客户端 durable 确认)
  client.sendJson(envelope('ACK', epoch, { message_id: snap.message_id }));
  return snap;
}

test('5. WELCOME 连续 100 次会话无 UNIQUE 冲突且 message_id 唯一', async () => {
  const seen = new Set();
  for (let i = 0; i < 100; i++) {
    const c = new WsTestClient();
    await c.connect(bridgePort);
    c.sendJson(envelope('HELLO', null, HELLO_PAYLOAD(`dev-${i}`)));
    const w = await c.waitJson((m) => m.type === 'WELCOME');
    assert.ok(w.message_id && w.message_id !== 'x', `第${i}次 WELCOME message_id 必须非 'x'`);
    assert.ok(!seen.has(w.message_id), 'WELCOME message_id 必须唯一');
    seen.add(w.message_id);
    c.close();
  }
});

test('3+6. CLIENT_COMMAND 重放: effect 一次, 第二次补 ACK(ACK 丢失自愈)', async () => {
  const wP = client.waitJson((m) => m.type === 'WELCOME');
  client.sendJson(envelope('HELLO', null, HELLO_PAYLOAD('idem-test-ipad')));
  const w = await wP;
  const epoch = w.payload.session_epoch;

  const snap = await openQuestionAndAwaitSnapshot(epoch);
  const graphId = snap.payload.graph_id;
  const center = snap.payload.nodes.find((n) => n.kind === 'CENTER');

  const cmdMessageId = uid();
  const cmd = envelope('CLIENT_COMMAND', epoch, {
    command_id: 'cmd-idem-1', kind: 'RENAME_NODE', graph_id: graphId,
    payload: { node_id: center.node_id, title: '幂等重命名', base_node_revision: center.node_revision },
  }, cmdMessageId);
  // 先注册两个等待器再触发(daemon 同 tick 连发 ACK+PATCH)
  const ack1P = client.waitJson((m) => m.type === 'COMMAND_ACK' && m.payload.command_id === 'cmd-idem-1');
  const patch1P = client.waitJson((m) => m.type === 'GRAPH_PATCH');
  client.sendJson(cmd);
  const ack1 = await ack1P;
  const patch1 = await patch1P;
  client.sendJson(envelope('ACK', epoch, { message_id: patch1.message_id }));
  const titleAfterFirst = daemon.svc.nodeGet(center.node_id).title;
  assert.equal(titleAfterFirst, '幂等重命名');

  // ACK 丢失自愈: 完全相同的 envelope 再发一次(客户端 outbox 重放语义)
  const ack2P = client.waitJson((m) => m.type === 'COMMAND_ACK' && m.payload.command_id === 'cmd-idem-1');
  client.sendJson(cmd);
  const ack2 = await ack2P;
  assert.equal(ack2.payload.server_seq, ack1.payload.server_seq, '重放必须复用原 server_seq');
  const titleAfterSecond = daemon.svc.nodeGet(center.node_id).title;
  assert.equal(titleAfterSecond, titleAfterFirst, '业务效果只能发生一次');
});

test('4. INK_PUT 重放: ink effect 一次, 第二次补 ACK', async () => {
  const wP = client.waitJson((m) => m.type === 'WELCOME');
  client.sendJson(envelope('HELLO', null, HELLO_PAYLOAD('idem-test-ipad')));
  const w = await wP;
  const epoch = w.payload.session_epoch;

  const snap = await openQuestionAndAwaitSnapshot(epoch, 'qb:Redis-01-003');
  const center = snap.payload.nodes.find((n) => n.kind === 'CENTER');

  const inkMessageId = uid();
  const blob = Buffer.from('fake-ink-blob-v1').toString('base64');
  const inkMsg = envelope('INK_PUT', epoch, {
    command_id: 'ink-idem-1', node_id: center.node_id, ink_revision: 1,
    format: 'pkdrawing-v1', blob, blob_sha256: 'sha256:fake', graph_id: snap.payload.graph_id,
  }, inkMessageId);
  const ack1P = client.waitJson((m) => m.type === 'COMMAND_ACK' && m.payload.command_id === 'ink-idem-1');
  client.sendJson(inkMsg);
  await ack1P;
  // 重放同一 envelope → 补 ACK, 复用原 seq
  const ack2P = client.waitJson((m) => m.type === 'COMMAND_ACK' && m.payload.command_id === 'ink-idem-1');
  client.sendJson(inkMsg);
  const ack2 = await ack2P;
  const ack1 = await ack1P;
  assert.equal(ack2.payload.server_seq, ack1.payload.server_seq, 'ink 重放必须复用原 server_seq');
  const inkRow = daemon.store.prepare('SELECT ink_revision FROM ink WHERE node_id=?').get(center.node_id);
  assert.equal(inkRow.ink_revision, 1, 'ink effect 只发生一次');
});

test('语义冲突的 message_id 重放 → COMMAND_REJECTED(MESSAGE_ID_REUSE_CONFLICT)', async () => {
  const wP = client.waitJson((m) => m.type === 'WELCOME');
  client.sendJson(envelope('HELLO', null, HELLO_PAYLOAD('idem-test-ipad')));
  const w = await wP;
  const epoch = w.payload.session_epoch;

  const snap = await openQuestionAndAwaitSnapshot(epoch, 'qb:JUC-01-001');
  const graphId = snap.payload.graph_id;
  const center = snap.payload.nodes.find((n) => n.kind === 'CENTER');

  const mid = uid();
  const ack1P = client.waitJson((m) => m.type === 'COMMAND_ACK' && m.payload.command_id === 'cmd-conflict-1');
  const patchP = client.waitJson((m) => m.type === 'GRAPH_PATCH');
  client.sendJson(envelope('CLIENT_COMMAND', epoch, {
    command_id: 'cmd-conflict-1', kind: 'RENAME_NODE', graph_id: graphId,
    payload: { node_id: center.node_id, title: '冲突测试A', base_node_revision: 1 },
  }, mid));
  await ack1P;
  const patch = await patchP;
  client.sendJson(envelope('ACK', epoch, { message_id: patch.message_id }));

  // 同 message_id 但不同 command_id/语义 → 必须被拒绝
  const rejP = client.waitJson((m) => m.type === 'COMMAND_REJECTED' && m.payload.command_id === 'cmd-conflict-2');
  client.sendJson(envelope('CLIENT_COMMAND', epoch, {
    command_id: 'cmd-conflict-2', kind: 'RENAME_NODE', graph_id: graphId,
    payload: { node_id: center.node_id, title: '冲突测试B', base_node_revision: 1 },
  }, mid));
  const rej = await rejP;
  assert.equal(rej.payload.reason, 'MESSAGE_ID_REUSE_CONFLICT');
});
