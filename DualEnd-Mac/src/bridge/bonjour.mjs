// Bonjour Advertiser —— dns-sd 注册 `_qiuzhaoreview._tcp`, TXT 仅 proto/daemon_id/workspace/bridge(禁 secret)。
import { spawn } from 'node:child_process';
import { stableId } from '../util.mjs';

const SERVICE = '_qiuzhaoreview._tcp';

export class BonjourAdvertiser {
  constructor({ daemonId, port, workspace, logger }) {
    this.daemonId = daemonId;
    this.port = port;
    this.workspace = workspace ?? stableId('qiuzhao-review').slice(0, 8);
    this.log = logger;
    this.child = null;
  }

  start() {
    // /usr/bin/dns-sd -R <name> <type> <domain> <port> <key=val>...
    const args = [
      '-R', `qiuzao-review-${this.daemonId}`, SERVICE, 'local', String(this.port),
      `proto=1`, `daemon_id=${this.daemonId}`, `workspace=${this.workspace}`, 'bridge=ws',
    ];
    try {
      this.child = spawn('/usr/bin/dns-sd', args, { stdio: 'ignore' });
      this.child.on('error', (e) => this.log?.warn?.('bonjour spawn error', e.message));
      this.log?.info?.(`bonjour advertising ${SERVICE} :${this.port} (daemon_id=${this.daemonId})`);
    } catch (e) {
      this.log?.warn?.('bonjour unavailable', String(e));
    }
  }

  stop() {
    try { this.child?.kill(); } catch { /* noop */ }
  }
}
