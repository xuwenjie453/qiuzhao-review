import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { StateDb, SCHEMA_VERSION } from '../src/store/state-db.mjs';
import { QuestionGraphService } from '../src/graph/question-graph-service.mjs';
import { ERR } from '../src/util.mjs';

const uid = () => crypto.randomUUID();

function withService(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'dualend-hierarchy-'));
  const store = new StateDb(join(dir, 'dual-end.db'));
  const svc = new QuestionGraphService(store);
  try { return fn({ store, svc }); }
  finally { store.close(); rmSync(dir, { recursive: true, force: true }); }
}

function openGraph(svc, key = 'qb:hierarchy') {
  return svc.open({
    command_id: uid(),
    question_ref: { source: 'QUESTION_BANK', question_key: key, source_id: key.slice(3) },
    question_body_markdown: '中心正文',
    ai_title: '中心节点',
  });
}

describe('schema v4 migration', () => {
  test('fresh DB exposes parent_node_id and schema v4', () => withService(({ store }) => {
    assert.equal(SCHEMA_VERSION, 4);
    assert.equal(store.prepare("SELECT value FROM meta WHERE key='schema_version'").get().value, '4');
    const cols = store.prepare('PRAGMA table_info(nodes)').all().map((r) => r.name);
    assert.ok(cols.includes('parent_node_id'));
  }));

  test('legacy v3 non-center nodes backfill to graph center', () => {
    const dir = mkdtempSync(join(tmpdir(), 'dualend-v3-'));
    const path = join(dir, 'dual-end.db');
    const db = new DatabaseSync(path);
    db.exec(`
      PRAGMA foreign_keys=OFF;
      CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
      INSERT INTO meta VALUES ('schema_version','3');
      CREATE TABLE graphs(
        graph_id TEXT PRIMARY KEY, question_key TEXT NOT NULL UNIQUE,
        question_source TEXT NOT NULL, source_id TEXT NOT NULL, probe_key TEXT,
        graph_revision INTEGER NOT NULL DEFAULT 1, center_node_id TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
      CREATE TABLE rounds(
        round_id TEXT PRIMARY KEY, graph_id TEXT NOT NULL, status TEXT NOT NULL,
        opened_at TEXT NOT NULL, closed_at TEXT);
      CREATE TABLE nodes(
        node_id TEXT PRIMARY KEY, graph_id TEXT NOT NULL, kind TEXT NOT NULL,
        title TEXT NOT NULL, body_markdown TEXT NOT NULL, body_sha256 TEXT NOT NULL,
        round_id TEXT, node_revision INTEGER NOT NULL DEFAULT 1, origin_turn_ref TEXT,
        created_at TEXT NOT NULL, deleted_at TEXT, expired_at TEXT);
      INSERT INTO graphs VALUES ('g','qb:legacy','QUESTION_BANK','legacy',NULL,1,'c','2026','2026');
      INSERT INTO nodes VALUES ('c','g','CENTER','C','body','sha',NULL,1,NULL,'2026',NULL,NULL);
      INSERT INTO nodes VALUES ('e','g','EXPLANATION','E','body','sha',NULL,1,NULL,'2026',NULL,NULL);
    `);
    db.close();
    const store = new StateDb(path);
    try {
      assert.equal(store.prepare("SELECT value FROM meta WHERE key='schema_version'").get().value, '4');
      assert.equal(store.prepare("SELECT parent_node_id FROM nodes WHERE node_id='c'").get().parent_node_id, null);
      assert.equal(store.prepare("SELECT parent_node_id FROM nodes WHERE node_id='e'").get().parent_node_id, 'c');
      assert.equal(store.integrity().fk_violations, 0);
    } finally {
      store.close(); rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe('parent_node_id canonical semantics', () => {
  test('legacy add defaults EXPLANATION parent to CENTER', () => withService(({ store, svc }) => {
    const r = openGraph(svc);
    const child = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '子节点', body_markdown: '解释' });
    assert.equal(child.parent_node_id, r.center_node_id);
    assert.equal(store.prepare('SELECT parent_node_id FROM nodes WHERE node_id=?').get(child.node_id).parent_node_id, r.center_node_id);
  }));

  test('supports CENTER -> A -> B -> C and snapshot preserves hierarchy', () => withService(({ svc }) => {
    const r = openGraph(svc);
    const a = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '节点A', body_markdown: 'A' });
    const b = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '节点B', body_markdown: 'B', parent_node_id: a.node_id });
    const c = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '节点C', body_markdown: 'C', parent_node_id: b.node_id });
    const snap = svc.snapshotPayload(r.graph_id, r.round_id);
    const byId = Object.fromEntries(snap.nodes.map((n) => [n.node_id, n]));
    assert.equal(byId[a.node_id].parent_node_id, r.center_node_id);
    assert.equal(byId[b.node_id].parent_node_id, a.node_id);
    assert.equal(byId[c.node_id].parent_node_id, b.node_id);
    assert.equal(byId[r.center_node_id].parent_node_id, null);
  }));

  test('rejects missing, deleted, temporary and other-graph parent', () => withService(({ svc }) => {
    const r1 = openGraph(svc, 'qb:g1');
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r1.round_id, kind: 'EXPLANATION', ai_title: 'X', body_markdown: 'x', parent_node_id: 'missing' }),
      (e) => e.code === ERR.NODE_NOT_FOUND);

    const deleted = svc.addNode({ command_id: uid(), round_id: r1.round_id, kind: 'EXPLANATION', ai_title: 'D', body_markdown: 'd' });
    svc.deleteNode({ command_id: uid(), node_id: deleted.node_id, base_node_revision: 1 });
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r1.round_id, kind: 'EXPLANATION', ai_title: 'X', body_markdown: 'x', parent_node_id: deleted.node_id }),
      (e) => e.code === ERR.NODE_NOT_FOUND);

    const temp = svc.addNode({ command_id: uid(), round_id: r1.round_id, kind: 'TEMPORARY', ai_title: 'T', body_markdown: 't' });
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r1.round_id, kind: 'EXPLANATION', ai_title: 'X', body_markdown: 'x', parent_node_id: temp.node_id }),
      (e) => e.code === ERR.VALIDATION);

    const r2 = openGraph(svc, 'qb:g2');
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r2.round_id, kind: 'EXPLANATION', ai_title: 'X', body_markdown: 'x', parent_node_id: r1.center_node_id }),
      (e) => e.code === ERR.VALIDATION);
  }));

  test('TEMPORARY rejects explicit parent and otherwise attaches CENTER', () => withService(({ svc }) => {
    const r = openGraph(svc);
    assert.throws(() => svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'TEMPORARY', ai_title: '临时', body_markdown: 't', parent_node_id: r.center_node_id }),
      (e) => e.code === ERR.VALIDATION);
    const temp = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'TEMPORARY', ai_title: '临时', body_markdown: 't' });
    assert.equal(temp.parent_node_id, r.center_node_id);
  }));

  test('deleting parent keeps child canonical parent for presentation fallback', () => withService(({ store, svc }) => {
    const r = openGraph(svc);
    const a = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '父节点', body_markdown: 'A' });
    const b = svc.addNode({ command_id: uid(), round_id: r.round_id, kind: 'EXPLANATION', ai_title: '子节点', body_markdown: 'B', parent_node_id: a.node_id });
    svc.deleteNode({ command_id: uid(), node_id: a.node_id, base_node_revision: 1 });
    assert.equal(store.prepare('SELECT parent_node_id FROM nodes WHERE node_id=?').get(b.node_id).parent_node_id, a.node_id);
    const snap = svc.snapshotPayload(r.graph_id, r.round_id);
    assert.ok(!snap.nodes.some((n) => n.node_id === a.node_id));
    assert.equal(snap.nodes.find((n) => n.node_id === b.node_id).parent_node_id, a.node_id);
  }));
});
