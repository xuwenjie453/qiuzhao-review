import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { PaceGoalAutoRecorder, PaceGoalNotifier } from '../src/pace/pace-goal-bridge.mjs';

describe('PaceGoal daemon bridge', () => {
  test('only a committed EXPLANATION node is forwarded to the idempotent AUTO detector', () => {
    const calls = [];
    const recorder = new PaceGoalAutoRecorder({
      repoRoot: '/workspace',
      runSync: (command, args, options) => {
        calls.push({ command, args, options });
        return { status: 0, stdout: '{"items":[]}', stderr: '' };
      },
    });
    assert.deepEqual(recorder.recordExplanationNode({ kind: 'MATERIAL', node_id: 'm-1' }), { skipped: true });
    const recorded = recorder.recordExplanationNode({
      kind: 'EXPLANATION', node_id: 'n-1', graph_id: 'g-1', created_at: '2026-09-16T10:00:00.000Z',
    });
    assert.equal(recorded.ok, true);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].command, 'python3');
    assert.deepEqual(calls[0].args.slice(1, 6), [
      'pace-goal-record-auto', '--detector', 'EXPLANATION_NODE_CREATED', '--source-ref', 'n-1',
    ]);
    assert.equal(calls[0].options.cwd, '/workspace');
  });

  test('notifier serializes ticks and reports only an actual sent aggregate', async () => {
    const logs = [];
    const logger = { info: (line) => logs.push(line), warn: (line) => logs.push(line), error() {} };
    const notifier = new PaceGoalNotifier({
      repoRoot: '/workspace', logger,
      run: () => {
        const child = new EventEmitter();
        child.stdout = new EventEmitter();
        child.stderr = new EventEmitter();
        queueMicrotask(() => {
          child.stdout.emit('data', Buffer.from('{"sent":true,"slot":"MORNING"}'));
          child.emit('close', 0);
        });
        return child;
      },
    });
    notifier.tick();
    notifier.tick(); // 前一轮还未结束，不能发起第二个子进程。
    await new Promise((resolve) => setImmediate(resolve));
    assert.deepEqual(logs, ['pace notification sent: MORNING']);
    assert.equal(notifier.running, false);
  });
});
