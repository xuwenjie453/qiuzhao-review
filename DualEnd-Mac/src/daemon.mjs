// Mac 双端守护进程 —— 生命周期状态机 + 组件组装 + 单实例锁。
// STARTING → OPEN_STORE → INTEGRITY_CHECK → START_LOCAL_CONTROL → START_BRIDGE
//         → ADVERTISE_BONJOUR → READY; integrity 失败 → SAFE_MODE(只读, 不接受 mutation)。
import { EventEmitter } from 'node:events';
import { mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { createServer } from 'node:http';
import { StateDb } from './store/state-db.mjs';
import { QuestionGraphService } from './graph/question-graph-service.mjs';
import { LocalControl } from './control/local-control.mjs';
import { WsServer } from './bridge/ws-server.mjs';
import { SyncSession } from './bridge/sync-session.mjs';
import { BonjourAdvertiser } from './bridge/bonjour.mjs';
import { stableId } from './util.mjs';

const EMPTY_LOGGER = { info() {}, warn() {}, error() {} };

export class Daemon extends EventEmitter {
  constructor({ dataDir, logger }) {
    super();
    this.dataDir = dataDir;
    this.log = logger ?? EMPTY_LOGGER;
    this.state = 'STARTING';
    this.store = null;
    this.svc = null;
    this.http = null;          // localhost 控制 API(仅 127.0.0.1)
    this.bridgeHttp = null;    // WebSocket bridge(0.0.0.0, 供 iPad 局域网连接)
    this.ws = null;
    this.bonjour = null;
    this.sessions = new Set();
    this.lockPath = join(dataDir, 'runtime', 'daemon.lock');
    this.controlPort = null;
    this.bridgePort = null;
    this.daemonId = null;
  }

  // ---- 单实例锁 ----
  tryLock() {
    mkdirSync(dirname(this.lockPath), { recursive: true });
    if (existsSync(this.lockPath)) {
      const prev = JSON.parse(readFileSync(this.lockPath, 'utf-8'));
      const alive = this.pidAlive(prev.pid);
      if (alive) {
        this.log.error?.(`另一实例运行中 pid=${prev.pid}`);
        return false;
      }
      this.log.warn?.('发现过期锁, 接管');
    }
    writeFileSync(this.lockPath, JSON.stringify({ pid: process.pid, started_at: new Date().toISOString() }));
    process.on('exit', () => { try { rmSync(this.lockPath, { force: true }); } catch { /* noop */ } });
    return true;
  }
  pidAlive(pid) {
    try { process.kill(pid, 0); return true; } catch { return false; }
  }

  async start() {
    if (!this.tryLock()) return false;
    mkdirSync(join(this.dataDir, 'state'), { recursive: true });
    mkdirSync(join(this.dataDir, 'logs'), { recursive: true });
    mkdirSync(join(this.dataDir, 'runtime'), { recursive: true });
    const dbPath = join(this.dataDir, 'state', 'dual-end.db');
    this.daemonId = stableId(dbPath).slice(0, 12);
    this.store = new StateDb(dbPath);
    this.svc = new QuestionGraphService(this.store);
    this.log.info?.('store opened');
    const ic = this.store.integrity();
    if (ic.integrity !== 'ok' || ic.fk_violations > 0) {
      this.state = 'SAFE_MODE';
      this.log.error?.(`integrity 失败 → SAFE_MODE(只读) ${JSON.stringify(ic)}`);
      this.emit('state', this.state);
      this.emit('safe-mode', ic);
      return true;
    }
    // 1) localhost 控制 API —— M-6.4: 只绑定 loopback
    this.http = createServer();
    const control = new LocalControl({ daemon: this, server: this.http });
    await new Promise((resolve) => this.http.listen(0, '127.0.0.1', resolve));
    this.controlPort = this.http.address().port;
    // 2) WebSocket bridge —— 监听所有接口(局域网可达), Bonjour 注册实际端口
    this.bridgeHttp = createServer();
    // 诊断: 打印连接收到的原始字节前80(hex), 排查数据是否到达
    this.bridgeHttp.on('connection', (sock) => {
      sock.once('data', (d) => this.log.info?.('raw rx:', d.subarray(0, 80).toString('hex')));
    });
    const ws = new WsServer({ httpServer: this.bridgeHttp, path: '/bridge', logger: this.log });
    ws.on('connection', (conn) => {
      const sess = new SyncSession({ conn, daemon: this, store: this.store, svc: this.svc, logger: this.log });
      sess.on('graphChanged', ({ graphId, result }) => this.broadcastGraphChange(graphId, result));
      sess.on('closed', () => this.sessions.delete(sess));
      this.sessions.add(sess);
      this.log.info?.('ipad connected');
    });
    this.ws = ws;
    const wantBridgePort = Number(process.env.DUALEND_BRIDGE_PORT || 0);
    await new Promise((resolve) => this.bridgeHttp.listen(wantBridgePort, '0.0.0.0', resolve));
    this.bridgePort = this.bridgeHttp.address().port;
    // CLI/status 读取同一份运行时锁；端口在两个 listener 都 ready 后一次性写入，
    // 避免 CLI 打印过期或把 bridge_port 错写成 control_port。
    writeFileSync(this.lockPath, JSON.stringify({
      pid: process.pid,
      started_at: new Date().toISOString(),
      control_port: this.controlPort,
      bridge_port: this.bridgePort,
    }));
    // Bonjour 注册真实监听端口
    this.bonjour = new BonjourAdvertiser({ daemonId: this.daemonId, port: this.bridgePort, logger: this.log });
    this.bonjour.start();
    this.state = 'READY';
    this.log.info?.(`READY control=127.0.0.1:${this.controlPort} bridge=:${this.bridgePort} daemon_id=${this.daemonId}`);
    this.emit('state', this.state);
    this.emit('ready', { controlPort: this.controlPort, bridgePort: this.bridgePort, daemonId: this.daemonId });
    return true;
  }

  /** Agent/localhost 命令入口(经 command service; 禁止其它路径直写 DB) */
  agentCommand(payload) {
    const kind = payload.kind;
    const svc = this.svc;
    let result;
    switch (kind) {
      case 'question.open':
        result = svc.open(payload); break;
      case 'question.close':
        result = svc.close(payload); break;
      case 'graph.add-node':
        // 业务 kind(EXPLANATION/TEMPORARY) 放 node_kind, 避免与命令名 kind 冲突
        result = svc.addNode({ ...payload, kind: payload.node_kind }); break;
      case 'node.rename':
        result = svc.renameNode(payload); break;
      case 'node.move':
        result = svc.moveNode(payload); break;
      case 'node.delete':
        result = svc.deleteNode(payload); break;
      default:
        return { error: 'UNKNOWN_KIND' };
    }
    if (result && result.graph_id) this.broadcastGraphChange(result.graph_id, result);
    return result;
  }

  /** 对全部已连接 iPad: 由 canonical 结果生成 GRAPH_PATCH 广播 */
  broadcastGraphChange(graphId, result) {
    const round = this.svc.activeRound();
    const targetRevision = this.svc.graphGet(graphId)?.graph_revision;
    if (this.sessions.size === 0) return;
    const patch = this.buildPatch(graphId, result, targetRevision);
    if (!patch) return;
    for (const s of this.sessions) s.pushPatch(graphId, patch);
  }

  /** 把 command 结果映射为增量 patch ops (title/move/delete/add 后由 caller 用 snapshot 或 patch) */
  buildPatch(graphId, result, targetRevision) {
    if (!result) return null;
    const baseRevision = Math.max(1, (targetRevision ?? 1) - 1);
    if (result.created !== undefined) { // question.open: 整图 snapshot 更好
      const round = this.svc.activeRound();
      const snap = this.svc.snapshotPayload(graphId, round?.round_id ?? null);
      for (const s of this.sessions) s.emitGraph('snapshot', snap);
      return null;
    }
    const ops = [];
    if (result.node_id && result.node_revision !== undefined && result.kind) {
      // add-node: 需要完整 node 内容
      const n = this.svc.nodeGet(result.node_id);
      const l = this.store.prepare('SELECT * FROM layouts WHERE node_id=?').get(result.node_id);
      ops.push({ op: 'ADD_NODE', node: {
        node_id: n.node_id, kind: n.kind, title: n.title, body_markdown: n.body_markdown,
        node_revision: n.node_revision, layout: { x: l.x_norm, y: l.y_norm, revision: l.layout_revision } } });
    } else if (result.node_id && result.title !== undefined) {
      ops.push({ op: 'UPDATE_TITLE', node_id: result.node_id, title: result.title, node_revision: result.node_revision });
    } else if (result.node_id && result.x_norm !== undefined) {
      ops.push({ op: 'UPDATE_LAYOUT', node_id: result.node_id, layout: { x: result.x_norm, y: result.y_norm, revision: result.layout_revision } });
    } else if (result.deleted) {
      ops.push({ op: 'REMOVE_NODE', node_id: result.node_id });
    } else if (result.removed_temporary?.length) {
      for (const nid of result.removed_temporary) ops.push({ op: 'REMOVE_NODE', node_id: nid });
    } else {
      return null;
    }
    return { graph_id: graphId, base_revision: baseRevision, target_revision: targetRevision, ops };
  }

  async stop() {
    this.state = 'STOPPING';
    this.emit('state', this.state);
    this.bonjour?.stop();
    for (const s of this.sessions) s.close('daemon stop');
    this.ws?.close?.();
    await new Promise((r) => { try { this.http?.close?.(r); } catch { r(); } });
    await new Promise((r) => { try { this.bridgeHttp?.close?.(r); } catch { r(); } });
    this.store?.close();
    try { rmSync(this.lockPath, { force: true }); } catch { /* noop */ }
    this.state = 'STOPPED';
  }
}
