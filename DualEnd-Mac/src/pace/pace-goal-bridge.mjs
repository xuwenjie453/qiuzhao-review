// PaceGoal 与学习系统 CLI 的窄桥接。
// Graph 仍以 dual-end.db 为唯一 canonical；步频事实写 scheduler.sqlite3，
// 由 Python 的 PaceGoalService 统一校验、投影与幂等去重。
import { spawn, spawnSync } from 'node:child_process';
import { join } from 'node:path';

const EMPTY_LOGGER = { info() {}, warn() {}, error() {} };

function cliPath(repoRoot) {
  return join(repoRoot, '学习系统', 'cli.py');
}

export class PaceGoalAutoRecorder {
  constructor({ repoRoot, logger, runSync = spawnSync }) {
    this.repoRoot = repoRoot;
    this.log = logger ?? EMPTY_LOGGER;
    this.runSync = runSync;
  }

  /** EXPLANATION 节点提交成功后触发。source_ref=node_id 使 daemon 重试仍只记一次。 */
  recordExplanationNode(node) {
    if (!node || node.kind !== 'EXPLANATION') return { skipped: true };
    const result = this.runSync('python3', [
      cliPath(this.repoRoot), 'pace-goal-record-auto',
      '--detector', 'EXPLANATION_NODE_CREATED',
      '--source-ref', node.node_id,
      '--at', node.created_at,
      '--payload', JSON.stringify({ graph_id: node.graph_id, node_id: node.node_id }),
    ], { cwd: this.repoRoot, encoding: 'utf8', timeout: 10_000 });
    if (result.error || result.status !== 0) {
      const detail = String(result.error?.message ?? result.stderr ?? result.stdout ?? 'unknown error').trim();
      this.log.warn?.(`pace auto record skipped for node=${node.node_id}: ${detail}`);
      return { ok: false, detail };
    }
    return { ok: true, output: String(result.stdout ?? '').trim() };
  }
}

export class PaceGoalNotifier {
  constructor({ repoRoot, logger, run = spawn, intervalMs = 30_000 }) {
    this.repoRoot = repoRoot;
    this.log = logger ?? EMPTY_LOGGER;
    this.run = run;
    this.intervalMs = intervalMs;
    this.timer = null;
    this.running = false;
  }

  start() {
    if (process.env.PACE_GOALS_DISABLED === '1' || this.timer) return;
    this.tick();
    this.timer = setInterval(() => this.tick(), this.intervalMs);
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  tick() {
    if (this.running) return;
    this.running = true;
    let child;
    try {
      child = this.run('python3', [cliPath(this.repoRoot), 'pace-goal-notify', '--due'], {
        cwd: this.repoRoot,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (error) {
      this.running = false;
      this.log.warn?.(`pace notifier launch failed: ${error.message}`);
      return;
    }
    let stdout = '', stderr = '';
    child.stdout?.on('data', (chunk) => { stdout += chunk; });
    child.stderr?.on('data', (chunk) => { stderr += chunk; });
    child.on('error', (error) => {
      this.running = false;
      this.log.warn?.(`pace notifier failed: ${error.message}`);
    });
    child.on('close', (code) => {
      this.running = false;
      if (code !== 0) {
        this.log.warn?.(`pace notifier exited ${code}: ${(stderr || stdout).trim()}`);
        return;
      }
      try {
        const result = JSON.parse(stdout);
        if (result.sent) this.log.info?.(`pace notification sent: ${result.slot}`);
      } catch {
        // CLI 标准输出仅用于诊断；不影响下一次定时检查。
      }
    });
  }
}
