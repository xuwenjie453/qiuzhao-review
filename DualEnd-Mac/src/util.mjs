// DualEnd-Mac 共享常量、工具、错误码。零第三方依赖。
import { createHash, randomUUID } from 'node:crypto';

export const PROTOCOL_VERSION = 1;
export const APP_BUILD = '1.0.0';

// M-6.4 最小防护限额（可配置）
export const LIMITS = {
  nodeBodyMaxBytes: 2 * 1024 * 1024,   // node body ≤ 2 MiB
  inkSnapshotMaxBytes: 20 * 1024 * 1024, // Ink snapshot ≤ 20 MiB
  titleMin: 1,
  titleMax: 80,                        // Unicode scalar
};

export const ERR = {
  CENTER_DELETE_FORBIDDEN: 'CENTER_DELETE_FORBIDDEN',
  NODE_BODY_IMMUTABLE: 'NODE_BODY_IMMUTABLE',
  INK_REVISION_GAP: 'INK_REVISION_GAP',
  INK_REVISION_STALE: 'INK_REVISION_STALE',
  ROUND_NOT_ACTIVE: 'ROUND_NOT_ACTIVE',
  ROUND_NOT_FOUND: 'ROUND_NOT_FOUND',
  GRAPH_NOT_FOUND: 'GRAPH_NOT_FOUND',
  NODE_NOT_FOUND: 'NODE_NOT_FOUND',
  KIND_FORBIDDEN: 'KIND_FORBIDDEN',
  VALIDATION: 'VALIDATION',
  BODY_IMMUTABLE: 'BODY_IMMUTABLE',
  CAS_MISMATCH: 'CAS_MISMATCH',
  INTERNAL: 'INTERNAL',
};

export class AppError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

export const nowIso = () => new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
export const uuid = () => randomUUID();
export const sha256hex = (s) => createHash('sha256').update(s).digest('hex');
export const stableId = (key) => createHash('sha256').update(String(key)).digest('hex').slice(0, 16);
export const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
