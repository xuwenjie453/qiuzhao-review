#!/usr/bin/env node
// qreview-dual —— daemon 启动/停止/状态 + Agent 双端命令 CLI。
// CLI 永远走 localhost LocalControl API, 禁止直写 SQLite。
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Daemon } from '../src/daemon.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
// bin/ -> DualEnd-Mac/ -> 仓库根目录；不要再向上跳到“秋招”父目录，
// 否则 daemon 与仓库内 README/AGENTS 约定的系统数据会分裂成两份。
const REPO_ROOT = join(__dirname, '..', '..');
const DATA_DIR = join(REPO_ROOT, '系统数据', 'dual-end');

const LOGGER = {
  info: (...a) => console.log('[daemon]', ...a),
  warn: (...a) => console.warn('[daemon:warn]', ...a),
  error: (...a) => console.error('[daemon:error]', ...a),
};

async function requestControl(method, path, body) {
  const port = readPort();
  const url = `http://127.0.0.1:${port}${path}`;
  const res = await fetch(url, {
    method,
    headers: { 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json };
}

function readPort() {
  try {
    const lock = JSON.parse(readFileSync(join(DATA_DIR, 'runtime', 'daemon.lock'), 'utf-8'));
    return lock.control_port;
  } catch {
    console.error('daemon 未运行或锁缺失');
    process.exit(1);
  }
}

function loadJson(path) {
  return JSON.parse(readFileSync(path, 'utf-8'));
}

async function main() {
  const [cmd, sub, ...rest] = process.argv.slice(2);
  if (!cmd) { usage(); return; }
  const flag = (name, def) => {
    const i = rest.indexOf(name);
    return i >= 0 ? rest[i + 1] : def;
  };
  switch (cmd) {
    case 'daemon': {
      if (sub === 'start') {
        const daemon = new Daemon({ dataDir: DATA_DIR, logger: LOGGER });
        daemon.on('ready', ({ controlPort, bridgePort, daemonId }) => {
          console.log(`READY daemon_id=${daemonId} control_port=${controlPort} bridge_port=${bridgePort}`);
        });
        const ok = await daemon.start();
        if (!ok) process.exit(1);
        daemon.on('safe-mode', (ic) => { console.error('SAFE_MODE(只读):', JSON.stringify(ic)); process.exit(2); });
        // daemon 主进程驻留
        const shutdown = async () => { await daemon.stop(); process.exit(0); };
        process.on('SIGINT', shutdown);
        process.on('SIGTERM', shutdown);
      } else if (sub === 'status') {
        const r = await requestControl('GET', '/status');
        console.log(JSON.stringify(r.json, null, 2));
      }
      return;
    }
    case 'question': {
      if (sub === 'open') {
        const req = loadJson(flag('--json', ''));
        const r = await requestControl('POST', '/command', {
          command_id: crypto.randomUUID(), kind: 'question.open',
          ...req,
        });
        console.log(JSON.stringify(r.json, null, 2));
      } else if (sub === 'close') {
        const r = await requestControl('POST', '/command', {
          command_id: crypto.randomUUID(), kind: 'question.close',
          round_id: flag('--round', ''),
        });
        console.log(JSON.stringify(r.json, null, 2));
      }
      return;
    }
    case 'graph': {
      if (sub === 'add-node') {
        const req = loadJson(flag('--json', ''));
        const r = await requestControl('POST', '/command', {
          command_id: crypto.randomUUID(), kind: 'graph.add-node', ...req,
        });
        console.log(JSON.stringify(r.json, null, 2));
      } else if (sub === 'snapshot') {
        const q = flag('--graph', '') ? `?graph_id=${flag('--graph', '')}` : '';
        const r = await requestControl('GET', `/graph/snapshot${q}`);
        console.log(JSON.stringify(r.json, null, 2));
      }
      return;
    }
    default:
      usage();
  }
}

function usage() {
  console.log(`qreview-dual 用法:
  node DualEnd-Mac/bin/qreview-dual.mjs daemon start
  node DualEnd-Mac/bin/qreview-dual.mjs daemon status
  node DualEnd-Mac/bin/qreview-dual.mjs question open --json request.json
  node DualEnd-Mac/bin/qreview-dual.mjs question close --round <round_id>
  node DualEnd-Mac/bin/qreview-dual.mjs graph add-node --json request.json
  node DualEnd-Mac/bin/qreview-dual.mjs graph snapshot [--graph <graph_id>]`);
}

main().catch((e) => { console.error(e); process.exit(1); });
