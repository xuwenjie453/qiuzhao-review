// Local Control Server —— 仅绑定 127.0.0.1; Agent CLI / 本机 API 用。
// 规则: CLI 只经此 API; 禁止 CLI/WS handler 直写 DB; canonical mutation 只经 command service。
import { parseEnvelope } from '../protocol/envelope.mjs'; // 复用 schema 形状参考
import { AppError, LIMITS } from '../util.mjs';

const QUERY_ROUTES = {
  '/status': (d) => ({
    state: d.state, daemon_id: d.daemonId,
    control_port: d.controlPort, bridge_port: d.bridgePort,
    sessions: d.sessions.size,
    active_round: d.svc?.activeRound() ?? null,
  }),
  '/graph/snapshot': (d, q) => {
    const gid = q.get('graph_id');
    const g = gid ? d.svc.graphGet(gid) : null;
    if (!gid) {
      const active = d.svc.activeRound();
      return active ? d.svc.snapshotPayload(active.graph_id, active.round_id) : null;
    }
    if (!g) return { error: 'GRAPH_NOT_FOUND' };
    const round = d.svc.activeRound();
    return d.svc.snapshotPayload(gid, round?.round_id ?? null);
  },
  '/graph/get-by-question': (d, q) => d.svc.graphByKey(q.get('question_key')) ?? { error: 'GRAPH_NOT_FOUND' },
  '/graph/materials': (d, q) => {
    const graphId = q.get('graph_id');
    return graphId ? { items: d.svc.listMaterials(graphId) } : { error: 'VALIDATION', reason: '需要 graph_id' };
  },
  '/custom/list': (d, q) => ({ items: d.svc.listUserGraphs(q.get('query') ?? '') }),
  '/custom/get': (d, q) => d.svc.userGraphById(q.get('id')) ?? { error: 'USER_GRAPH_NOT_FOUND' },
};

export class LocalControl {
  constructor({ daemon, server }) {
    this.daemon = daemon;
    server.on('request', (req, res) => this.handle(req, res));
  }

  handle(req, res) {
    const url = new URL(req.url, 'http://127.0.0.1');
    res.setHeader('content-type', 'application/json; charset=utf-8');
    if (req.method === 'GET' && QUERY_ROUTES[url.pathname]) {
      try {
        const r = QUERY_ROUTES[url.pathname](this.daemon, url.searchParams);
        this.send(res, 200, r);
      } catch (e) {
        if (e instanceof AppError) this.send(res, 422, { error: e.code, reason: e.message });
        else this.send(res, 500, { error: 'INTERNAL', detail: String(e) });
      }
      return;
    }
    if (req.method === 'POST' && url.pathname === '/command') {
      let body = '';
      req.on('data', (c) => { body += c; if (body.length > LIMITS.nodeBodyMaxBytes + 128 * 1024) req.destroy(); });
      req.on('end', () => {
        try {
          const p = JSON.parse(body);
          if (!p.command_id || !p.kind) { this.send(res, 400, { error: 'VALIDATION', reason: '需要 command_id + kind' }); return; }
          if (this.daemon.state !== 'READY') {
            this.send(res, 503, { error: 'DAEMON_NOT_READY', state: this.daemon.state });
            return;
          }
          const r = this.daemon.agentCommand(p);
          if (r instanceof AppError) { this.send(res, 422, { error: r.code, reason: r.message }); return; }
          if (r?.error) { this.send(res, 422, r); return; }
          this.send(res, 200, r);
        } catch (e) {
          this.send(res, 400, { error: 'BAD_JSON', detail: String(e) });
        }
      });
      return;
    }
    this.send(res, 404, { error: 'NOT_FOUND' });
  }

  send(res, code, obj) { res.statusCode = code; res.end(JSON.stringify(obj)); }
}
