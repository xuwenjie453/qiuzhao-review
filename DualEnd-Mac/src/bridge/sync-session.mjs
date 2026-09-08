// Sync Session —— 单个 iPad WebSocket 连接的协议状态机。
// durable-before-emit: 每次 server 广播(SNapshot/Patch/ACK)前先写 sync_journal。
// dedup: message_id one effect; session_epoch 隔离旧会话; ACK 携带 canonical revisions。
import { EventEmitter } from 'node:events';
import { AppError, ERR, nowIso, uuid } from '../util.mjs';
import { makeEnvelope, parseEnvelope, MSG } from '../protocol/envelope.mjs';

const MAX_BODY = 2 * 1024 * 1024;
const MAX_INK = 20 * 1024 * 1024;

export class SyncSession extends EventEmitter {
  constructor({ conn, daemon, store, svc, logger }) {
    super();
    this.conn = conn;
    this.daemon = daemon;
    this.store = store;
    this.svc = svc;
    this.log = logger;
    this.epoch = null;
    this.deviceId = null;
    this.closed = false;
    conn.on('message', (text) => this.onMessage(text));
    conn.on('close', () => { this.closed = true; this.emit('closed'); });
  }

  send(type, payload, opts = {}) {
    if (this.closed) return;
    this.conn.send(JSON.stringify(makeEnvelope(type, payload, {
      sessionEpoch: this.epoch, messageId: opts.messageId,
    })));
  }

  onMessage(raw) {
    const parsed = parseEnvelope(raw);
    if (!parsed.ok) {
      if (parsed.code === 'PROTOCOL_UNSUPPORTED') {
        this.send(MSG.COMMAND_REJECTED, { reason: 'PROTOCOL_UNSUPPORTED', supported_protocols: [1] });
        this.conn.close(1002);
      }
      return; // 未知类型/坏 JSON: 记录并忽略, 不 crash
    }
    const m = parsed.msg;
    try {
      switch (m.type) {
        case MSG.HELLO: this.onHello(m); break;
        case MSG.SNAPSHOT_REQUEST: this.onSnapshotRequest(m); break;
        case MSG.CLIENT_COMMAND: this.onClientCommand(m); break;
        case MSG.INK_PUT: this.onInkPut(m); break;
        case MSG.ACK: this.onAck(m); break;
        case MSG.PONG: this.conn.markPong(); break;
        default: this.log?.warn?.('ignore msg type', m.type);
      }
    } catch (e) {
      this.log?.error?.('onMessage error', e?.message);
    }
  }

  // ---------- 握手 ----------
  onHello(m) {
    const p = m.payload;
    if (!p.device_id || !Array.isArray(p.supported_protocols) || !p.supported_protocols.includes(1)) {
      this.send(MSG.COMMAND_REJECTED, { reason: 'PROTOCOL_UNSUPPORTED' });
      this.conn.close(1002);
      return;
    }
    this.deviceId = String(p.device_id);
    this.epoch = uuid();                       // 每次会话新 epoch
    this.store.prepare(`INSERT INTO device_state(device_id,last_seen_at,last_acked_server_seq)
                        VALUES (?,?,0) ON CONFLICT(device_id) DO UPDATE SET last_seen_at=excluded.last_seen_at`)
      .run(this.deviceId, nowIso());
    const lastSeq = this.store.prepare('SELECT COALESCE(MAX(server_seq),0) AS s FROM sync_journal').get().s;
    const active = this.svc.activeRound();
    this.send(MSG.WELCOME, {
      selected_protocol: 1,
      daemon_id: this.daemon.daemonId,
      session_epoch: this.epoch,
      server_seq: lastSeq,
      active: active ? { graph_id: active.graph_id, round_id: active.round_id } : null,
    }, { messageId: 'x' });
    this.store.journal('x', 'WELCOME', null, { device_id: this.deviceId });
    this.emit('hello');
    // 有 active round → 推 snapshot（graph push 由 daemon 统一处理 active 广播，这里主动推）
    if (active) {
      const snap = this.svc.snapshotPayload(active.graph_id, active.round_id);
      if (snap) this.emitGraph('snapshot', snap, { causal: false });
    }
  }

  // ---------- iPad 请求 snapshot ----------
  onSnapshotRequest(m) {
    const gid = m.payload?.graph_id;
    if (!gid) return;
    const g = this.svc.graphGet(gid);
    if (!g) { this.send(MSG.COMMAND_REJECTED, { reason: ERR.GRAPH_NOT_FOUND }); return; }
    const round = this.svc.activeRound();
    const snap = this.svc.snapshotPayload(gid, round?.round_id ?? null);
    this.emitGraph('snapshot', snap, { causal: false });
  }

  // ---------- CLIENT_COMMAND (rename/move/delete) ----------
  onClientCommand(m) {
    const p = m.payload;
    const cmdId = p.command_id;
    const kind = p.kind;
    const result = this.runCommand(cmdId, kind, p.graph_id, p.payload ?? {});
    if (result instanceof AppError || result?.error) {
      const code = result?.code ?? result?.error;
      this.send(MSG.COMMAND_REJECTED, { command_id: cmdId, reason: code, kind }, { messageId: m.message_id });
      return;
    }
    // 成功: durable journal 后 ACK + 广播 patch
    const seq = this.store.journal(m.message_id, kind, p.graph_id, { command_id: cmdId, result });
    this.send(MSG.COMMAND_ACK, {
      command_id: cmdId, kind,
      canonical: { graph_revision: result.graph_revision,
                   node_revision: result.node_revision,
                   layout_revision: result.layout_revision,
                   ink_revision: result.ink_revision },
      server_seq: seq,
    }, { messageId: m.message_id });
    // 广播 patch 给所有连接(含本会话其他端语义; v1 单 iPad)
    this.emit('graphChanged', { graphId: p.graph_id, actor: 'ipad', result });
  }

  runCommand(cmdId, kind, graphId, payload) {
    try {
      switch (kind) {
        case 'RENAME_NODE':
          return this.svc.renameNode({ command_id: cmdId, node_id: payload.node_id,
            title: payload.title, base_node_revision: payload.base_node_revision, actor: 'IPAD' });
        case 'MOVE_NODE':
          return this.svc.moveNode({ command_id: cmdId, node_id: payload.node_id,
            x_norm: payload.x_norm, y_norm: payload.y_norm,
            base_layout_revision: payload.base_layout_revision, actor: 'IPAD' });
        case 'DELETE_NODE':
          return this.svc.deleteNode({ command_id: cmdId, node_id: payload.node_id,
            base_node_revision: payload.base_node_revision, actor: 'IPAD' });
        default:
          return { error: 'UNKNOWN_COMMAND_KIND' };
      }
    } catch (e) {
      if (e instanceof AppError) return e;
      return { error: ERR.INTERNAL, detail: String(e?.message ?? e) };
    }
  }

  // ---------- Ink ----------
  onInkPut(m) {
    const p = m.payload;
    const blob = Buffer.from(p.blob ?? '', 'base64');
    if (blob.length > MAX_INK) { this.send(MSG.COMMAND_REJECTED, { reason: 'INK_TOO_LARGE' }); return; }
    try {
      const r = this.svc.putInk({ command_id: p.command_id, node_id: p.node_id,
        ink_revision: p.ink_revision, format: p.format ?? 'pkdrawing-v1',
        blob, blob_sha256: p.blob_sha256, actor: 'IPAD' });
      const seq = this.store.journal(m.message_id, 'INK_PUT', p.graph_id, { node_id: p.node_id, ink_revision: r.ink_revision });
      this.send(MSG.COMMAND_ACK, { command_id: p.command_id, kind: 'INK_PUT',
        canonical: { ink_revision: r.ink_revision }, server_seq: seq }, { messageId: m.message_id });
      if (r.idempotent || r.stale) return;
      this.emit('inkChanged', { nodeId: p.node_id, inkRevision: r.ink_revision }); // 其它端拉取
    } catch (e) {
      const code = e instanceof AppError ? e.code : ERR.INTERNAL;
      this.send(MSG.COMMAND_REJECTED, { command_id: p.command_id, kind: 'INK_PUT', reason: code });
    }
  }

  // ---------- iPad ACK (snapshot/patch 落盘确认) ----------
  onAck(m) {
    const p = m.payload ?? {};
    if (p.message_id) {
      const row = this.store.prepare('SELECT * FROM sync_journal WHERE message_id=?').get(p.message_id);
      if (row) {
        // 记录 device last acked seq (诊断), 不改变 canonical
        this.store.prepare('UPDATE device_state SET last_acked_server_seq=? WHERE device_id=?')
          .run(row.server_seq, this.deviceId ?? '');
      }
    }
  }

  // ---------- graph 事件推送 (canonical → iPad) ----------
  emitGraph(kind, payload, opts = {}) {
    if (kind === 'snapshot') {
      const seq = this.store.journal(uuid(), 'GRAPH_SNAPSHOT', payload.graph_id, payload);
      this.send(MSG.GRAPH_SNAPSHOT, payload);
      return seq;
    }
    if (kind === 'patch') {
      const seq = this.store.journal(uuid(), 'GRAPH_PATCH', payload.graph_id, payload);
      this.send(MSG.GRAPH_PATCH, payload);
      return seq;
    }
  }

  pushPatch(graphId, patch) {
    const seq = this.store.journal(uuid(), 'GRAPH_PATCH', graphId, patch);
    this.send(MSG.GRAPH_PATCH, patch);
    return seq;
  }
  pushActive(graphId, roundId) {
    this.send(MSG.ACTIVE_GRAPH_CHANGED, { graph_id: graphId, round_id: roundId });
  }
  close(reason) { try { this.conn.close(1000, reason); } catch { /* noop */ } }
}
