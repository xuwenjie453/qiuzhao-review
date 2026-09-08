// QuestionGraph Service —— Query/Command 分离; canonical mutation 全在此模块; 不直连 bridge/CLI。
// 规则: CENTER 不可删/唯一; EXPLANATION 永久; TEMPORARY 绑定 ACTIVE round, close 即过期且不复活;
// body immutable; 拖动=USER_PINNED; CAS 按 node/layout revision; graph_revision++ 每次 canonical change。
import { AppError, ERR, nowIso, uuid, stableId, sha256hex, clamp } from '../util.mjs';
import { LIMITS } from '../util.mjs';

const KINDS = new Set(['CENTER', 'EXPLANATION', 'TEMPORARY']);

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
  graphGet(graphId) {
    return this.store.prepare('SELECT * FROM graphs WHERE graph_id=?').get(graphId);
  }
  activeRound() {
    return this.store.prepare("SELECT * FROM rounds WHERE status='ACTIVE'").get();
  }
  nodeGet(nodeId) {
    return this.store.prepare('SELECT * FROM nodes WHERE node_id=?').get(nodeId);
  }

  /** 可见节点: 未删除且未过期。TEMPORARY 只显示当前 round 的。 */
  visibleNodes(graphId, roundId) {
    const rows = this.store.prepare(`SELECT n.*, l.x_norm, l.y_norm, l.layout_revision, l.pinned_by_user
       FROM nodes n LEFT JOIN layouts l ON l.node_id = n.node_id
       WHERE n.graph_id=? AND n.deleted_at IS NULL
         AND (n.expired_at IS NULL OR (n.kind='TEMPORARY' AND n.round_id=?))
       ORDER BY n.created_at`).all(graphId, roundId ?? null);
    return rows;
  }

  snapshotPayload(graphId, roundId) {
    const g = this.graphGet(graphId);
    if (!g) return null;
    const nodes = this.visibleNodes(graphId, roundId).map((n) => ({
      node_id: n.node_id, kind: n.kind, title: n.title,
      body_markdown: n.body_markdown, node_revision: n.node_revision,
      layout: { x: n.x_norm ?? 0.5, y: n.y_norm ?? 0.5, revision: n.layout_revision ?? 1 },
    }));
    return {
      graph_id: graphId,
      question_key: g.question_key,
      round_id: roundId ?? null,
      revision: g.graph_revision,
      center_node_id: g.center_node_id,
      nodes,
    };
  }

  // ============ Commands ============
  /** question.open: ensure graph + 新 round。全局同时仅一个 ACTIVE round。 */
  open({ command_id, actor = 'AGENT', question_ref, question_body_markdown, ai_title, agent_session_ref }) {
    assert(question_ref && ['QUESTION_BANK', 'REVIEW_CAPSULE'].includes(question_ref.source), ERR.VALIDATION, 'question_ref.source 非法');
    assert(question_ref.question_key && typeof question_ref.question_key === 'string', ERR.VALIDATION, '缺少 question_key');
    assert(typeof question_body_markdown === 'string' && question_body_markdown.length > 0, ERR.VALIDATION, 'body 为空');
    assert(titleValid(ai_title), ERR.VALIDATION, `title 须为 1..${LIMITS.titleMax} 字符`);
    assert(question_body_markdown.length <= LIMITS.nodeBodyMaxBytes, ERR.VALIDATION, 'body 超限');
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const existed = !!this.graphByKey(question_ref.question_key);
      let g = this.graphByKey(question_ref.question_key);
      const now = nowIso();
      if (!g) {
        const graphId = stableId(question_ref.question_key);
        const centerId = uuid();
        this.store.prepare(`INSERT INTO graphs(graph_id,question_key,question_source,source_id,probe_key,graph_revision,center_node_id,created_at,updated_at)
                            VALUES (?,?,?,?,?,1,?,?,?)`)
          .run(graphId, question_ref.question_key, question_ref.source, question_ref.source_id ?? '',
               question_ref.probe_key ?? null, centerId, now, now);
        this.store.prepare(`INSERT INTO nodes(node_id,graph_id,kind,title,body_markdown,body_sha256,round_id,node_revision,created_at)
                            VALUES (?,?,?,?,?,?,NULL,1,?)`)
          .run(centerId, graphId, 'CENTER', String(ai_title).trim(), question_body_markdown,
               sha256hex(question_body_markdown), now);
        this.store.prepare('INSERT INTO layouts(node_id,x_norm,y_norm,layout_revision,pinned_by_user,updated_at) VALUES (?,0.5,0.5,1,0,?)')
          .run(centerId, now);
        g = this.graphGet(graphId);
      }
      // 全局仅一个 ACTIVE round; 若已有(同图=重开讨论 / 异图=切题) → 先 INTERRUPTED, 其 temporary 过期
      const prior = this.activeRound();
      if (prior) this._closeRound(prior, 'INTERRUPTED');
      const roundId = uuid();
      this.store.prepare("INSERT INTO rounds(round_id,graph_id,status,opened_at) VALUES (?,?,?,?)")
        .run(roundId, g.graph_id, 'ACTIVE', now);
      this.store.prepare('UPDATE graphs SET updated_at=? WHERE graph_id=?').run(now, g.graph_id);
      const result = { graph_id: g.graph_id, round_id: roundId, graph_revision: g.graph_revision,
                       center_node_id: g.center_node_id, created: !existed };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  /** question.close(round_id): CLOSED + 该轮 TEMPORARY 过期(expired_at)。 */
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

  /** node.add: 仅用户显式; EXPLANATION 永久(round_id NULL), TEMPORARY 绑 round。 */
  addNode({ command_id, round_id, kind, ai_title, body_markdown, origin_turn_ref, actor = 'AGENT' }) {
    assert(kind === 'EXPLANATION' || kind === 'TEMPORARY', ERR.KIND_FORBIDDEN, '只能加 EXPLANATION/TEMPORARY');
    assert(titleValid(ai_title), ERR.VALIDATION, 'title 非法');
    assert(typeof body_markdown === 'string' && body_markdown.length > 0, ERR.VALIDATION, 'body 为空');
    assert(body_markdown.length <= LIMITS.nodeBodyMaxBytes, ERR.VALIDATION, 'body 超限');
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const round = this.store.prepare("SELECT * FROM rounds WHERE round_id=? AND status='ACTIVE'").get(round_id);
      assert(round, ERR.ROUND_NOT_ACTIVE, '需要 ACTIVE round');
      const now = nowIso();
      const nodeId = uuid();
      this.store.prepare(`INSERT INTO nodes(node_id,graph_id,kind,title,body_markdown,body_sha256,round_id,node_revision,origin_turn_ref,created_at)
                          VALUES (?,?,?,?,?,?,?,1,?,?)`)
        .run(nodeId, round.graph_id, kind, String(ai_title).trim(), body_markdown,
             sha256hex(body_markdown), kind === 'TEMPORARY' ? round.round_id : null,
             origin_turn_ref ?? null, now);
      const { x, y } = this._radialSlot(round.graph_id, kind === 'TEMPORARY' ? round.round_id : null);
      this.store.prepare('INSERT INTO layouts(node_id,x_norm,y_norm,layout_revision,pinned_by_user,updated_at) VALUES (?,?,?,1,0,?)')
        .run(nodeId, x, y, now);
      const g = this.graphGet(round.graph_id);
      this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?')
        .run(now, g.graph_id);
      const result = { graph_id: round.graph_id, round_id: round.round_id, node_id: nodeId, kind,
                       graph_revision: g.graph_revision + 1, node_revision: 1,
                       layout: { x, y, revision: 1 } };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  /** rename: CENTER/任意节点可改 title; body 不动; node_revision++ / graph_revision++。 */
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
      this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?')
        .run(now, n.graph_id);
      const g = this.graphGet(n.graph_id);
      const result = { graph_id: n.graph_id, node_id, title: String(title).trim(),
                       node_revision: n.node_revision + 1, graph_revision: g.graph_revision };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  /** move: layout CAS; clamp 0..1; pinned=1(USER_PINNED); layout_revision++ / graph_revision++。 */
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
      this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?')
        .run(now, n.graph_id);
      const g = this.graphGet(n.graph_id);
      const result = { graph_id: n.graph_id, node_id, x_norm: x, y_norm: y,
                       layout_revision: (l?.layout_revision ?? 1) + 1, graph_revision: g.graph_revision };
      this.store.dedupPut(command_id, result);
      return result;
    });
  }

  /** delete: CENTER → 拒绝; 其它 tombstone(deleted_at); graph_revision++; ink 保留为 orphaned backup。 */
  deleteNode({ command_id, node_id, base_node_revision, actor = 'IPAD' }) {
    return this.store.withTx(() => {
      const dup = this.store.dedupGet(command_id);
      if (dup) return dup;
      const n = this.nodeGet(node_id);
      if (!n) { // 已删 = 幂等成功
        const r = { deleted: true, node_id: node_id, idempotent: true };
        this.store.dedupPut(command_id, r);
        return r;
      }
      if (n.deleted_at) { const r = { deleted: true, node_id, idempotent: true }; this.store.dedupPut(command_id, r); return r; }
      if (n.kind === 'CENTER') throw new AppError(ERR.CENTER_DELETE_FORBIDDEN, 'CENTER 不可删除');
      assert(n.node_revision === base_node_revision, ERR.CAS_MISMATCH, 'node_revision CAS 冲突');
      const now = nowIso();
      this.store.prepare('UPDATE nodes SET deleted_at=? WHERE node_id=?').run(now, node_id);
      this.store.prepare('UPDATE graphs SET graph_revision=graph_revision+1, updated_at=? WHERE graph_id=?')
        .run(now, n.graph_id);
      const g = this.graphGet(n.graph_id);
      const r = { deleted: true, node_id, graph_id: n.graph_id, graph_revision: g.graph_revision };
      this.store.dedupPut(command_id, r);
      return r;
    });
  }

  /** ink.put: full PKDrawing snapshot; ink_revision 期望 = server current + 1。
      重复 revision + 同 hash = 幂等成功; 低 revision 忽略(返回 stale); 跳 revision → INK_REVISION_GAP。 */
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
    // 该轮 TEMPORARY 过期(不复活)
    const temp = this.store.prepare("SELECT node_id FROM nodes WHERE round_id=? AND kind='TEMPORARY' AND deleted_at IS NULL AND expired_at IS NULL").all(round.round_id);
    for (const t of temp) {
      this.store.prepare('UPDATE nodes SET expired_at=? WHERE node_id=?').run(now, t.node_id);
    }
    return temp;
  }

  _radialSlot(graphId, tempRoundId) {
    // 确定性 radial slot: 防重叠; 用户拖动后 pin, 不再自动重排。
    const cnt = this.store.prepare(`SELECT count(*) AS c FROM nodes n
       WHERE n.graph_id=? AND n.deleted_at IS NULL AND (n.expired_at IS NULL OR (n.kind='TEMPORARY' AND n.round_id=?))
         AND n.kind != 'CENTER'`).get(graphId, tempRoundId ?? null).c;
    const idx = cnt;
    const golden = 2.399963229728653;            // golden angle (rad)
    const ring = Math.floor(idx / 12);
    const radius = Math.min(0.18 + ring * 0.12, 0.42);
    const a = golden * idx;
    return { x: clamp(0.5 + radius * Math.cos(a), 0.05, 0.95), y: clamp(0.5 + radius * Math.sin(a), 0.08, 0.92) };
  }
}
