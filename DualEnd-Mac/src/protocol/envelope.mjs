// Wire Protocol v1 —— Envelope 构造/解析/校验 + 类型常量 (M-2.1 ~ M-2.7)
import { nowIso, uuid, PROTOCOL_VERSION } from '../util.mjs';

export const MSG = {
  // Server → Client
  WELCOME: 'WELCOME',
  ACTIVE_GRAPH_CHANGED: 'ACTIVE_GRAPH_CHANGED',
  GRAPH_SNAPSHOT: 'GRAPH_SNAPSHOT',
  GRAPH_PATCH: 'GRAPH_PATCH',
  INK_SNAPSHOT: 'INK_SNAPSHOT',
  COMMAND_ACK: 'COMMAND_ACK',
  COMMAND_REJECTED: 'COMMAND_REJECTED',
  PING: 'PING',
  // Client → Server
  HELLO: 'HELLO',
  SNAPSHOT_REQUEST: 'SNAPSHOT_REQUEST',
  CLIENT_COMMAND: 'CLIENT_COMMAND',
  INK_PUT: 'INK_PUT',
  ACK: 'ACK',
  PONG: 'PONG',
};

const TYPES = new Set(Object.values(MSG));

export function makeEnvelope(type, payload, { messageId, sessionEpoch } = {}) {
  return {
    v: PROTOCOL_VERSION,
    message_id: messageId ?? uuid(),
    type,
    session_epoch: sessionEpoch ?? null,
    sent_at: nowIso(),
    payload: payload ?? {},
  };
}

/** 校验 envelope 基础形状; 返回错误码或 null。未知 type → 忽略(记录)。 */
export function parseEnvelope(raw) {
  let obj;
  try {
    obj = JSON.parse(raw);
  } catch {
    return { ok: false, code: 'JSON_PARSE_ERROR' };
  }
  if (!obj || typeof obj !== 'object') return { ok: false, code: 'NOT_OBJECT' };
  if (obj.v !== PROTOCOL_VERSION) return { ok: false, code: 'PROTOCOL_UNSUPPORTED', version: obj.v };
  if (!TYPES.has(obj.type)) return { ok: false, code: 'UNKNOWN_TYPE', type: obj.type };
  if (typeof obj.message_id !== 'string' || !obj.message_id) return { ok: false, code: 'MISSING_MESSAGE_ID' };
  if (!obj.payload || typeof obj.payload !== 'object') return { ok: false, code: 'MISSING_PAYLOAD' };
  return { ok: true, msg: obj };
}
