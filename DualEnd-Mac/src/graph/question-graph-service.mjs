// QuestionGraph Service —— Query/Command 分离; canonical mutation 全在此模块; 不直连 bridge/CLI。
// 规则: CENTER 不可删/唯一; EXPLANATION 永久; TEMPORARY 绑定 ACTIVE round, close 即过期且不复活;
// body immutable; 拖动=USER_PINNED; CAS 按 node/layout revision; graph_revision++ 每次 canonical change。
import { AppError, ERR, nowIso, uuid, stableId, sha256hex, clamp } from '../util.mjs';
import { LIMITS } from '../util.mjs';

function assert(cond, code, msg) { if (!cond) throw new AppError(code, msg); }
function titleValid(t) {
  const s = String(t ?? '').trim();
  return s.length >= LIMITS.titleMin && [...s].length <= LIMITS.titleMax;
}

export class QuestionGraphService {
  constructor(store) { this.store = store; }

  // ============ Query (无副作用) ============
  graphByKey(questionKey) {
    return this.store.prepare('SELECT * FROM graphs WHERE question_key=?').get(questionKey);
  }

  graphByQuestionRef(questionRef) {
    if (questionRef.source === 'REVIEW_CAPSULE' || questionRef.source === 'USER_AUTHORED') {
      return this.store.prepare(`SELECT * FROM graphs
        WHERE question_source=? AND source_id=?
        ORDER BY created_at ASC LIMIT 1`).get(questionRef.source, questionRef.source_id);
    }
    return this.graphByKey(questionRef.question_key);
  }

  graphIdentityKey(questionRef) {
    if (questionRef.source === 'REVIEW_CAPSULE') return `capsule:${questionRef.source_id}`;
    if (questionRef.source === 'USER_AUTHORED') return `user:${questionRef.source_id}`;
    return questionRef.question_key;
  }

  graphGet(graphId) {
    return this.store.prepare('SELECT * FROM graphs WHERE graph_id=?').get(graphId);
  }

  activeRound() {
    return this.store.prepare("SELECT * FROM rounds WHERE status='ACTIVE'").get();
  }

  nodeGet(nodeId) {
    return this.store.prepare('SELECT * FROM nodes WHERE node_id=?').get(nodeId);
  }

  userGraphById(customId) {
    return this.store.prepare(`SELECT g.graph_id, g.source_id AS custom_id, g.question_key,
      n.title, n.body_markdown, g.graph_revision, g.created_at, g.updated_at,
      (SELECT count(*) FROM nodes c WHERE c.graph_id=g.graph_id AND c.deleted_at IS NULL) AS node_count
      FROM graphs g JOIN nodes n ON n.node_id=g.center_node_id
      WHERE g.question_source='USER_AUTHORED' AND g.source_id=?`).get(customId);
  }

  listUserGraphs(query = '') {
    const needle = String(query ?? '').trim();
    const sql = `SELECT g.graph_id, g.source_id AS custom_id, g.question_key,
      n.title, n.body_markdown, g.graph_revision, g.created_at, g.updated_at,
      (SELECT count(*) FROM nodes c WHERE c.graph_id=g.graph_id AND c.deleted_at IS NULL) AS node_count
      FROM graphs g JOIN nodes n ON n.node_id=g.center_node_id
      WHERE g.question_source='USER_AUTHORED'
      ${needle ? "AND (g.source_id LIKE ? OR n.title LIKE ? OR n.body_markdown LIKE ?)" : ''}
      ORDER BY g.updated_at DESC, g.created_at DESC`;
    if (!needle) return this.store.prepare(sql).all();
    const like = `%${needle}%`;
    return this.store.prepare(sql).all(like, like, like);
  }

  parentGraphs(graphId) {
    return this.store.prepare(`SELECT g.*, i.inheritance_kind FROM graph_inheritance i JOIN graphs g ON g.graph_id=i.parent_graph_id
      WHERE i.child_graph_id=? ORDER BY g.graph_id`).all(graphId);
  }

  descendantGraphIds(graphId) {
    const rows = this.store.prepare(`WITH RECURSIVE d(graph_id) AS (
      SELECT child_graph_id FROM graph_inheritance WHERE parent_graph_id=?
      UNION
      SELECT i.child_graph_id FROM graph_inheritance i JOIN d ON i.parent_graph_id=d.graph_id
    ) SELECT graph_id FROM d ORDER BY graph_id`).all(graphId);
    return [graphId, ...rows.map((r) => r.graph_id)];
  }

  affectedGraphIds(nodeId) {
    const n = this.nodeGet(nodeId);
    return n ? this.descendantGraphIds(n.graph_id) : [];
  }

  setInheritance({ command_id, child_graph_id, parent_graph_id, inheritance_kind = 'SHARED_EXPLANATIONS' }) {
    assert(inheritance_kind === 'SHARED_EXPLANATIONS', ERR.VALIDATION, 'inheritance_kind 非法');
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id); if (dup) return dup;
      const child = this.graphGet(child_graph_id), parent = this.graphGet(parent_graph_id);
      assert(child && parent, ERR.GRAPH_NOT_FOUND, 'graph 不存在');
      assert(child.question_source === 'REVIEW_CAPSULE' && parent.question_source === 'QUESTION_BANK', ERR.VALIDATION, '继承仅允许 Review → QuestionBank');
      assert(child_graph_id !== parent_graph_id, ERR.VALIDATION, '禁止自继承');
      assert(!this.descendantGraphIds(child_graph_id).includes(parent_graph_id), ERR.VALIDATION, '继承关系会形成环');
      const now = nowIso();
      const ins = this.store.prepare(`INSERT OR IGNORE INTO graph_inheritance(child_graph_id,parent_graph_id,inheritance_kind,created_at)
        VALUES (?,?,?,?)`).run(child_graph_id, parent_graph_id, inheritance_kind, now);
      const affected = this.descendantGraphIds(child_graph_id);
      if (Number(ins.changes) === 1) {
        for (const gid of affected) {
          this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1,updated_at=? WHERE graph_id=?').run(now, gid);
        }
      }
      const g = this.graphGet(child_graph_id);
      const result = { child_graph_id, parent_graph_id, graph_id: child_graph_id, affected_graph_ids: affected, graph_revision: g.graph_revision, inherited: true };
      this.store.dedupPut(command_id, result); return result;
    });
  }

  /** 可见节点: 未删除且未过期。TEMPORARY 只显示当前 round 的。 */
  visibleNodes(graphId, roundId) {
    return this.store.prepare(`WITH RECURSIVE ancestors(graph_id) AS (
       SELECT ? UNION SELECT i.parent_graph_id FROM graph_inheritance i JOIN ancestors a ON i.child_graph_id=a.graph_id
     ), candidates AS (
       SELECT n.*, 0 AS inherited FROM nodes n WHERE n.graph_id=?
       UNION ALL
       SELECT n.*, 1 AS inherited FROM nodes n JOIN ancestors a ON a.graph_id=n.graph_id
         WHERE n.graph_id<>? AND n.kind='EXPLANATION'
     )
     SELECT c.*, l.x_norm, l.y_norm, l.layout_revision, l.pinned_by_user,
       CASE WHEN c.inherited=1 THEN 'INHERITED' ELSE 'OWN' END AS visibility,
       c.graph_id AS owner_graph_id
       FROM candidates c LEFT JOIN layouts l ON l.node_id=c.node_id
       WHERE c.deleted_at IS NULL
         AND (c.expired_at IS NULL OR (c.kind='TEMPORARY' AND c.round_id=?))
       GROUP BY c.node_id
       ORDER BY c.created_at, c.node_id`).all(graphId, graphId, graphId, roundId ?? null);
  }

  snapshotPayload(graphId, roundId) {
    const g = this.graphGet(graphId);
    if (!g) return null;
    const nodes = this.visibleNodes(graphId, roundId).map((n) => ({
      node_id: n.node_id,
      owner_graph_id: n.owner_graph_id,
      visibility: n.visibility,
      kind: n.kind,
      title: n.title,
      body_markdown: n.body_markdown,
      parent_node_id: n.parent_node_id ?? null,
      node_revision: n.node_revision,
      layout: { x: n.x_norm ?? 0.5, y: n.y_norm ?? 0.5, revision: n.layout_revision ?? 1 },
    }));
    return {
      graph_id: graphId,
      question_key: g.question_key,
      round_id: roundId ?? null,
      revision: g.graph_revision,
      center_node_id: g.center_node_id,
      parent_graphs: this.parentGraphs(graphId).map((p) => ({ graph_id: p.graph_id, inheritance_kind: p.inheritance_kind })),
      nodes,
    };
  }

  // ============ Commands ============
  open({ command_id, actor = 'AGENT', question_ref, question_body_markdown, ai_title, agent_session_ref, inherit_from }) {
    assert(question_ref && ['QUESTION_BANK', 'REVIEW_CAPSULE', 'USER_AUTHORED'].includes(question_ref.source), ERR.VALIDATION, 'question_ref.source 非法');
    assert(question_ref.question_key && typeof question_ref.question_key === 'string', ERR.VALIDATION, '缺少 question_key');
    if (question_ref.source === 'REVIEW_CAPSULE' || question_ref.source === 'USER_AUTHORED') {
      assert(question_ref.source_id && typeof question_ref.source_id === 'string', ERR.VALIDATION, '缺少 source_id');
    }
    assert(typeof question_body_markdown === 'string' && question_body_markdown.length > 0, ERR.VALIDATION, 'body 为空');
    assert(titleValid(ai_title), ERR.VALIDATION, `title 须为 1..${LIMITS.titleMax} 字符`);
    assert(question_body_markdown.length <= LIMITS.nodeBodyMaxBytes, ERR.VALIDATION, 'body 超限');
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const identityKey = this.graphIdentityKey(question_ref);
      const existed = !!this.graphByQuestionRef(question_ref);
      let g = this.graphByQuestionRef(question_ref);
      const now = nowIso();
      if (!g) {
        const graphId = stableId(identityKey);
        const centerId = uuid();
        this.store.prepare(`INSERT INTO graphs(graph_id,question_key,question_source,source_id,probe_key,graph_revision,center_node_id,created_at,updated_at)
                            VALUES (?,?,?,?,?,1,?,?,?)`)
          .run(graphId, identityKey, question_ref.source, question_ref.source_id ?? '',
               question_ref.probe_key ?? null, centerId, now, now);
        this.store.prepare(`INSERT INTO nodes(node_id,graph_id,kind,title,body_markdown,body_sha256,round_id,parent_node_id,node_revision,created_at)
                            VALUES (?,?,?,?,?,?,NULL,NULL,1,?)`)
          .run(centerId, graphId, 'CENTER', String(ai_title).trim(), question_body_markdown,
               sha256hex(question_body_markdown), now);
        this.store.prepare('INSERT INTO layouts(node_id,x_norm,y_norm,layout_revision,pinned_by_user,updated_at) VALUES (?,0.5,0.5,1,0,?)')
          .run(centerId, now);
        g = this.graphGet(graphId);
      }
      const prior = this.activeRound();
      if (prior) this._closeRound(prior, 'INTERRUPTED');
      const roundId = uuid();
      this.store.prepare("INSERT INTO rounds(round_id,graph_id,status,opened_at) VALUES (?,?,?,?)")
        .run(roundId, g.graph_id, 'ACTIVE', now);
      let parentGraphMissing = false;
      let inheritanceAffected = [g.graph_id];
      if (inherit_from && g.question_source === 'REVIEW_CAPSULE') {
        const parent = this.graphByQuestionRef(inherit_from);
        if (parent) {
          assert(inherit_from.source === 'QUESTION_BANK' && parent.question_source === 'QUESTION_BANK', ERR.VALIDATION, '继承 parent 必须为 QUESTION_BANK');
          const existingInheritance = this.store.prepare('SELECT 1 FROM graph_inheritance WHERE child_graph_id=? AND parent_graph_id=?').get(g.graph_id, parent.graph_id);
          assert(existingInheritance || !this.descendantGraphIds(g.graph_id).includes(parent.graph_id), ERR.VALIDATION, '继承关系会形成环');
          const ins = this.store.prepare(`INSERT OR IGNORE INTO graph_inheritance(child_graph_id,parent_graph_id,inheritance_kind,created_at)
            VALUES (?,?, 'SHARED_EXPLANATIONS', ?)`)
            .run(g.graph_id, parent.graph_id, now);
          if (Number(ins.changes) === 1) {
            inheritanceAffected = this.descendantGraphIds(g.graph_id);
            for (const gid of inheritanceAffected) {
              this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1,updated_at=? WHERE graph_id=?').run(now, gid);
            }
            g = this.graphGet(g.graph_id);
          }
        } else parentGraphMissing = true;
      }
      this.store.prepare('UPDATE graphs SET updated_at=? WHERE graph_id=?').run(now, g.graph_id);
      const result = { graph_id: g.graph_id, affected_graph_ids: inheritanceAffected, round_id: roundId, graph_revision: g.graph_revision,
                       center_node_id: g.center_node_id, created: !existed, parent_graph_missing: parentGraphMissing };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  close({ command_id, round_id, actor = 'AGENT' }) {
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const round = this.store.prepare('SELECT * FROM rounds WHERE round_id=?').get(round_id);
      assert(round, ERR.ROUND_NOT_FOUND, 'round 不存在');
      assert(round.status === 'ACTIVE', ERR.ROUND_NOT_ACTIVE, 'round 非 ACTIVE');
      const removed = this._closeRound(round, 'CLOSED');
      const g = this.graphGet(round.graph_id);
      this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?')
        .run(nowIso(), g.graph_id);
      const result = { graph_id: g.graph_id, round_id: round.round_id, status: 'CLOSED',
                       graph_revision: g.graph_revision + 1,
                       removed_temporary: removed.map((n) => n.node_id) };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  /** node.add: EXPLANATION 可指定 CENTER/EXPLANATION parent；TEMPORARY 固定挂 CENTER。 */
  addNode({ command_id, round_id, kind, ai_title, body_markdown, parent_node_id, origin_turn_ref, actor = 'AGENT' }) {
    assert(kind === 'EXPLANATION' || kind === 'TEMPORARY', ERR.KIND_FORBIDDEN, '只能加 EXPLANATION/TEMPORARY');
    assert(titleValid(ai_title), ERR.VALIDATION, 'title 非法');
    assert(typeof body_markdown === 'string' && body_markdown.length > 0, ERR.VALIDATION, 'body 为空');
    assert(body_markdown.length <= LIMITS.nodeBodyMaxBytes, ERR.VALIDATION, 'body 超限');
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const round = this.store.prepare("SELECT * FROM rounds WHERE round_id=? AND status='ACTIVE'").get(round_id);
      assert(round, ERR.ROUND_NOT_ACTIVE, '需要 ACTIVE round');
      const graph = this.graphGet(round.graph_id);
      let resolvedParentId = graph.center_node_id;
      if (kind === 'TEMPORARY') {
        assert(parent_node_id === undefined || parent_node_id === null, ERR.VALIDATION, 'TEMPORARY 不允许自定义 parent');
      } else if (parent_node_id !== undefined && parent_node_id !== null) {
        const parent = this.nodeGet(parent_node_id);
        assert(parent && !parent.deleted_at, ERR.NODE_NOT_FOUND, 'parent node 不存在或已删除');
        assert(parent.graph_id === round.graph_id, ERR.VALIDATION, 'parent 必须属于当前 graph');
        assert(parent.kind === 'CENTER' || parent.kind === 'EXPLANATION', ERR.VALIDATION, 'parent 只能是 CENTER/EXPLANATION');
        resolvedParentId = parent.node_id;
      }
      const now = nowIso();
      const nodeId = uuid();
      this.store.prepare(`INSERT INTO nodes(node_id,graph_id,kind,title,body_markdown,body_sha256,round_id,parent_node_id,node_revision,origin_turn_ref,created_at)
                          VALUES (?,?,?,?,?,?,?,?,1,?,?)`)
        .run(nodeId, round.graph_id, kind, String(ai_title).trim(), body_markdown,
             sha256hex(body_markdown), kind === 'TEMPORARY' ? round.round_id : null,
             resolvedParentId, origin_turn_ref ?? null, now);
      const { x, y } = this._radialSlot(round.graph_id, kind === 'TEMPORARY' ? round.round_id : null);
      this.store.prepare('INSERT INTO layouts(node_id,x_norm,y_norm,layout_revision,pinned_by_user,updated_at) VALUES (?,?,?,1,0,?)')
        .run(nodeId, x, y, now);
      const g = this.graphGet(round.graph_id);
      this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?')
        .run(now, g.graph_id);
      const affected = this.descendantGraphIds(round.graph_id);
      for (const gid of affected.slice(1)) {
        this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?').run(now, gid);
      }
      const result = {
        graph_id: round.graph_id,
        affected_graph_ids: affected,
        round_id: round.round_id,
        node_id: nodeId,
        parent_node_id: resolvedParentId,
        kind,
        graph_revision: g.graph_revision + 1,
        graph_revisions: Object.fromEntries(affected.map((id) => [id, this.graphGet(id).graph_revision])),
        node_revision: 1,
        layout: { x, y, revision: 1 },
      };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  renameNode({ command_id, node_id, title, base_node_revision, actor = 'IPAD' }) {
    assert(titleValid(title), ERR.VALIDATION, 'title 非法');
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const n = this.nodeGet(node_id);
      assert(n && !n.deleted_at, ERR.NODE_NOT_FOUND, 'node 不存在');
      assert(n.node_revision === base_node_revision, ERR.CAS_MISMATCH, 'node_revision CAS 冲突');
      const now = nowIso();
      this.store.prepare('UPDATE nodes SET title=?, node_revision=node_revision+1 WHERE node_id=?')
        .run(String(title).trim(), node_id);
      const affected = this.descendantGraphIds(n.graph_id);
      for (const gid of affected) this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?').run(now, gid);
      const result = { graph_id: n.graph_id, affected_graph_ids: affected, node_id, title: String(title).trim(),
                       node_revision: n.node_revision + 1, graph_revision: this.graphGet(n.graph_id).graph_revision,
                       graph_revisions: Object.fromEntries(affected.map((id) => [id, this.graphGet(id).graph_revision])) };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  moveNode({ command_id, node_id, x_norm, y_norm, base_layout_revision, actor = 'IPAD' }) {
    const x = clamp(Number(x_norm), 0, 1), y = clamp(Number(y_norm), 0, 1);
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const n = this.nodeGet(node_id);
      assert(n && !n.deleted_at, ERR.NODE_NOT_FOUND, 'node 不存在');
      const l = this.store.prepare('SELECT * FROM layouts WHERE node_id=?').get(node_id);
      assert((l?.layout_revision ?? 1) === base_layout_revision, ERR.CAS_MISMATCH, 'layout_revision CAS 冲突');
      const now = nowIso();
      this.store.prepare(`INSERT INTO layouts(node_id,x_norm,y_norm,layout_revision,pinned_by_user,updated_at)
                          VALUES (?,?,?,?,1,?)
                          ON CONFLICT(node_id) DO UPDATE SET x_norm=excluded.x_norm, y_norm=excluded.y_norm,
                            layout_revision=layout_revision+1, pinned_by_user=1, updated_at=excluded.updated_at`)
        .run(node_id, x, y, (l?.layout_revision ?? 1) + 1, now);
      const affected = this.descendantGraphIds(n.graph_id);
      for (const gid of affected) this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?').run(now, gid);
      const result = { graph_id: n.graph_id, affected_graph_ids: affected, node_id, x_norm: x, y_norm: y,
                       layout_revision: (l?.layout_revision ?? 1) + 1, graph_revision: this.graphGet(n.graph_id).graph_revision,
                       graph_revisions: Object.fromEntries(affected.map((id) => [id, this.graphGet(id).graph_revision])) };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  deleteNode({ command_id, node_id, base_node_revision, actor = 'IPAD' }) {
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const n = this.nodeGet(node_id);
      if (!n) {
        const r = { deleted: true, node_id, idempotent: true };
        this.store.dedupPut(command_id, r);
        return r;
      }
      if (n.deleted_at) {
        const r = { deleted: true, node_id, idempotent: true };
        this.store.dedupPut(command_id, r);
        return r;
      }
      if (n.kind === 'CENTER') throw new AppError(ERR.CENTER_DELETE_FORBIDDEN, 'CENTER 不可删除');
      assert(n.node_revision === base_node_revision, ERR.CAS_MISMATCH, 'node_revision CAS 冲突');
      const now = nowIso();
      this.store.prepare('UPDATE nodes SET deleted_at=? WHERE node_id=?').run(now, node_id);
      const affected = this.descendantGraphIds(n.graph_id);
      for (const gid of affected) this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?').run(now, gid);
      const r = { deleted: true, node_id, graph_id: n.graph_id, affected_graph_ids: affected,
                  graph_revision: this.graphGet(n.graph_id).graph_revision,
                  graph_revisions: Object.fromEntries(affected.map((id) => [id, this.graphGet(id).graph_revision])) };
      this.store.dedupPut(command_id, r);
      return r;
    });
  }

  putInk({ command_id, node_id, ink_revision, format, blob, blob_sha256, actor = 'IPAD' }) {
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const n = this.nodeGet(node_id);
      assert(n && !n.deleted_at, ERR.NODE_NOT_FOUND, 'node 不存在或已删除');
      const cur = this.store.prepare('SELECT * FROM ink WHERE node_id=?').get(node_id);
      const curRev = cur?.ink_revision ?? 0;
      const want = Number(ink_revision);
      if (want <= curRev) {
        if (want === curRev && cur && cur.blob_sha256 === blob_sha256) {
          const r = { ink_revision: curRev, idempotent: true, node_id };
          this.store.dedupPut(command_id, r);
          return r;
        }
        const r = { ink_revision: curRev, stale: true, node_id };
        this.store.dedupPut(command_id, r);
        return r;
      }
      if (want > curRev + 1) throw new AppError(ERR.INK_REVISION_GAP, `期望 revision ${curRev + 1}, 收到 ${want}`);
      const now = nowIso();
      this.store.prepare(`INSERT INTO ink(node_id,ink_revision,format,blob,blob_sha256,updated_at)
                          VALUES (?,?,?,?,?,?)
                          ON CONFLICT(node_id) DO UPDATE SET ink_revision=excluded.ink_revision, format=excluded.format,
                            blob=excluded.blob, blob_sha256=excluded.blob_sha256, updated_at=excluded.updated_at`)
        .run(node_id, want, format ?? 'pkdrawing-v1', blob, blob_sha256, now);
      const r = { ink_revision: want, node_id, committed: true };
      this.store.dedupPut(command_id, r);
      return r;
    });
  }

  // ============ 内部 ============
  _closeRound(round, status) {
    const now = nowIso();
    this.store.prepare('UPDATE rounds SET status=?, closed_at=? WHERE round_id=?').run(status, now, round.round_id);
    const temp = this.store.prepare("SELECT node_id FROM nodes WHERE round_id=? AND kind='TEMPORARY' AND deleted_at IS NULL AND expired_at IS NULL").all(round.round_id);
    for (const t of temp) this.store.prepare('UPDATE nodes SET expired_at=? WHERE node_id=?').run(now, t.node_id);
    return temp;
  }

  _radialSlot(graphId, tempRoundId) {
    const cnt = this.store.prepare(`SELECT count(*) AS c FROM nodes n
       WHERE n.graph_id=? AND n.deleted_at IS NULL AND (n.expired_at IS NULL OR (n.kind='TEMPORARY' AND n.round_id=?))
         AND n.kind != 'CENTER'`).get(graphId, tempRoundId ?? null).c;
    const idx = cnt;
    const golden = 2.399963229728653;
    const ring = Math.floor(idx / 12);
    const radius = Math.min(0.18 + ring * 0.12, 0.42);
    const a = golden * idx;
    return {
      x: clamp(0.5 + radius * Math.cos(a), 0.05, 0.95),
      y: clamp(0.5 + radius * Math.sin(a), 0.08, 0.92),
    };
  }
}
