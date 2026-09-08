// Protocol contract: 固定 JSON fixtures 同时被 Node 与 Swift 校验 (M-14.2)。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { parseEnvelope } from '../src/protocol/envelope.mjs';

const FIX = '/Users/xuwenjie/Documents/秋招/复习体系/DualEnd-common/fixtures';

for (const f of readdirSync(FIX).sort()) {
  if (!f.endsWith('.json')) continue;
  test(`fixture 解析通过: ${f}`, () => {
    const raw = readFileSync(join(FIX, f), 'utf-8');
    const r = parseEnvelope(raw);
    assert.equal(r.ok, true, `${f}: ${JSON.stringify(r)}`);
  });
}
