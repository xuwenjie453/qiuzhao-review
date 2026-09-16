// v7 MATERIAL —— 自制问题图的原始 Markdown 资料：同一 canonical store，非拓扑投影。
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { StateDb } from '../src/store/state-db.mjs';
import { QuestionGraphService } from '../src/graph/question-graph-service.mjs';
import { Daemon } from '../src/daemon.mjs';
import { ERR } from '../src/util.mjs';

const uid = () => crypto.randomUUID();
let dir, store, svc;

function openUser(customId) {
  return svc.open({
    command_id: uid(),
    question_ref: { source: 'USER_AUTHORED', question_key: `user:${customId}`, source_id: customId },
    question_body_markdown: '用户自制问题图的中心问题。',
    ai_title: `自制图 ${customId}`,
  });
}
function openQuestionBank(tag) {
  return svc.open({
    command_id: uid(),
    question_ref: { source: 'QUESTION_BANK', question_key: `qb:${tag}`, source_id: tag },
    question_body_markdown: '正式题干。', ai_title: `正式题 ${tag}`,
  });
}
function addMaterial(roundId, title = 'RAG 原始资料', body = '# RAG\n\n原始 Markdown，不能被自动改写。') {
  return svc.addNode({ command_id: uid(), round_id: roundId, kind: 'MATERIAL', ai_title: title, body_markdown: body });
}

before(() => {
  dir = mkdtempSync(join(tmpdir(), 'dualend-material-'));
  store = new StateDb(join(dir, 'state', 'dual-end.db'));
  svc = new QuestionGraphService(store);
});
after(() => { store.close(); rmSync(dir, { recursive: true, force: true }); });

describe('MATERIAL v7 domain invariants', () => {
  test('schema_version=7 and a material has no parent, shape, or layout', () => {
    assert.equal(store.prepare("SELECT value FROM meta WHERE key='schema_version'").get().value, '7');
    const graph = openUser('material-structure');
    const added = addMaterial(graph.round_id);
    const row = svc.nodeGet(added.node_id);
    assert.equal(row.kind, 'MATERIAL');
    assert.equal(row.parent_node_id, null);
    assert.equal(row.shape, null);
    assert.equal(row.round_id, null);
    assert.equal(store.prepare('SELECT * FROM layouts WHERE node_id=?').get(added.node_id), undefined);

    const snapshot = svc.snapshotPayload(graph.graph_id, graph.round_id);
    const node = snapshot.nodes.find((n) => n.node_id === added.node_id);
    assert.equal(node.layout, null);
    assert.equal(node.parent_node_id, null);
    assert.equal(node.shape, null);
  });

  test('only USER_AUTHORED graph may create MATERIAL, and parent input is forbidden', () => {
    const formal = openQuestionBank('material-forbidden');
    assert.throws(() => addMaterial(formal.round_id), (error) => error.code === ERR.KIND_FORBIDDEN);

    const user = openUser('material-parent');
    assert.throws(() => svc.addNode({
      command_id: uid(), round_id: user.round_id, kind: 'MATERIAL',
      parent_node_id: user.center_node_id, ai_title: '非法父级', body_markdown: '资料正文',
    }), (error) => error.code === ERR.VALIDATION);
  });

  test('list/read/rename/delete reuse canonical node semantics and keep body immutable', () => {
    const graph = openUser('material-lifecycle');
    const first = addMaterial(graph.round_id, '第一份资料', '第一份原文');
    const second = addMaterial(graph.round_id, '第二份资料', '第二份原文');
    assert.deepEqual(svc.listMaterials(graph.graph_id).map((node) => node.title).sort(), ['第一份资料', '第二份资料']);

    const renamed = svc.renameNode({ command_id: uid(), node_id: first.node_id, title: '第一份资料（改名）', base_node_revision: 1 });
    assert.equal(renamed.title, '第一份资料（改名）');
    assert.equal(svc.listMaterials(graph.graph_id).find((node) => node.node_id === first.node_id).body_markdown, '第一份原文');
    assert.throws(() => store.prepare('UPDATE nodes SET body_markdown=? WHERE node_id=?').run('篡改正文', first.node_id),
      /NODE_BODY_IMMUTABLE/);

    const deleted = svc.deleteNode({ command_id: uid(), node_id: second.node_id, base_node_revision: 1 });
    assert.equal(deleted.deleted, true);
    assert.deepEqual(svc.listMaterials(graph.graph_id).map((node) => node.node_id), [first.node_id]);
  });

  test('MATERIAL rejects topology mutation but supports the shared Ink store', () => {
    const graph = openUser('material-topology');
    const material = addMaterial(graph.round_id);
    assert.throws(() => svc.setNodeShape({ command_id: uid(), node_id: material.node_id, shape: 'CIRCLE', base_node_revision: 1 }),
      (error) => error.code === ERR.KIND_FORBIDDEN);
    assert.throws(() => svc.moveNode({ command_id: uid(), node_id: material.node_id, x_world: 1, y_world: 2, base_layout_revision: 1 }),
      (error) => error.code === ERR.KIND_FORBIDDEN);

    const blob = Buffer.from('material ink');
    const sha = createHash('sha256').update(blob).digest('hex');
    svc.putInk({ command_id: uid(), node_id: material.node_id, ink_revision: 1, blob, blob_sha256: sha });
    assert.equal(store.prepare('SELECT ink_revision FROM ink WHERE node_id=?').get(material.node_id).ink_revision, 1);
  });

  test('ADD_NODE patch preserves MATERIAL as a shape/layout-free sidebar projection', () => {
    const graph = openUser('material-patch');
    const material = addMaterial(graph.round_id);
    const patch = Daemon.prototype.buildPatch.call(
      { svc, store }, graph.graph_id, material, svc.graphGet(graph.graph_id).graph_revision,
    );
    const op = patch.ops.find((candidate) => candidate.op === 'ADD_NODE');
    assert.equal(op.node.kind, 'MATERIAL');
    assert.equal(op.node.shape, null);
    assert.equal(op.node.layout, null);
    assert.equal(op.node.parent_node_id, null);
  });

  test('materials remain graph-scoped and do not enter another graph snapshot', () => {
    const a = openUser('material-scope-a');
    const material = addMaterial(a.round_id, '仅图 A 可见');
    const b = openUser('material-scope-b');
    assert.equal(svc.listMaterials(b.graph_id).length, 0);
    assert.ok(svc.snapshotPayload(a.graph_id, null).nodes.some((node) => node.node_id === material.node_id));
    assert.ok(!svc.snapshotPayload(b.graph_id, b.round_id).nodes.some((node) => node.node_id === material.node_id));
  });
});
