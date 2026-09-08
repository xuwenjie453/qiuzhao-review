// 测试用最小 WebSocket client（Node 测试扮演 iPad）。仅本测试使用。
import { createHash, randomUUID } from 'node:crypto';
import { connect } from 'node:net';
import { EventEmitter } from 'node:events';

const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

export class WsTestClient extends EventEmitter {
  constructor() {
    super();
    this.sock = null;
    this.open = false;
    this.buffer = Buffer.alloc(0);
  }

  connect(port, path = '/bridge') {
    return new Promise((resolve, reject) => {
      const sock = connect({ host: '127.0.0.1', port });
      this.sock = sock;
      sock.on('connect', () => {
        const key = randomUUID().replace(/-/g, '').slice(0, 24);
        sock.write(
          `GET ${path} HTTP/1.1\r\nHost: 127.0.0.1:${port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n` +
          `Sec-WebSocket-Key: ${Buffer.from(key).toString('base64')}\r\nSec-WebSocket-Version: 13\r\n\r\n`);
      });
      let handshake = '';
      sock.on('data', (d) => {
        if (!this.open) {
          handshake += d.toString('latin1');
          const idx = handshake.indexOf('\r\n\r\n');
          if (idx < 0) return;
          const head = handshake.slice(0, idx);
          if (!head.includes('101')) { reject(new Error('handshake failed: ' + head)); return; }
          this.open = true;
          this.buffer = Buffer.from(handshake.slice(idx + 4), 'latin1');
          this.emit('connected');
          this.pump();
          resolve();
          return;
        }
        this.buffer = Buffer.concat([this.buffer, d]);
        this.pump();
      });
      sock.on('error', reject);
    });
  }

  pump() {
    for (;;) {
      const b = this.buffer;
      if (b.length < 2) return;
      const fin = (b[0] & 0x80) !== 0;
      const opcode = b[0] & 0x0f;
      const masked = (b[1] & 0x80) !== 0;
      let len = b[1] & 0x7f;
      let off = 2;
      if (len === 126) { if (b.length < 4) return; len = b.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (b.length < 10) return; len = Number(b.readBigUInt64BE(2)); off = 10; }
      let maskKey = null;
      if (masked) { if (b.length < off + 4) return; maskKey = b.subarray(off, off + 4); off += 4; }
      if (b.length < off + len) return;
      let payload = b.subarray(off, off + len);
      if (maskKey) {
        payload = Buffer.from(payload);
        for (let i = 0; i < payload.length; i++) payload[i] ^= maskKey[i % 4];
      }
      this.buffer = b.subarray(off + len);
      if (opcode === 0x1) {
        const text = payload.toString('utf8');
        this.emit('message', text);
        try { this.emit('json', JSON.parse(text)); } catch { /* ignore */ }
      } else if (opcode === 0x8) { this.emit('close-frame'); this.open = false; }
      else if (opcode === 0x9) { this.sendFrame(0xA, Buffer.alloc(0)); } // pong
      if (!fin) { /* 不分片测试 */ }
    }
  }

  send(text) { this.sendFrame(0x1, Buffer.from(text, 'utf8')); }
  sendJson(obj) { this.send(JSON.stringify(obj)); }

  sendFrame(opcode, payload) {
    if (!this.sock || this.sock.destroyed) return;
    const mask = randomUUID().slice(0, 4);
    let header;
    const masked = true;
    if (payload.length < 126) {
      header = Buffer.from([0x80 | opcode, 0x80 | payload.length]);
    } else if (payload.length < 65536) {
      header = Buffer.alloc(4);
      header[0] = 0x80 | opcode; header[1] = 0x80 | 126;
      header.writeUInt16BE(payload.length, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x80 | opcode; header[1] = 0x80 | 127;
      header.writeBigUInt64BE(BigInt(payload.length), 2);
    }
    const maskedPayload = Buffer.from(payload);
    const mk = Buffer.from(mask);
    for (let i = 0; i < maskedPayload.length; i++) maskedPayload[i] ^= mk[i % 4];
    this.sock.write(Buffer.concat([header, mk, maskedPayload]));
  }

  waitJson(predicate, timeoutMs = 3000) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { cleanup(); reject(new Error('waitJson timeout')); }, timeoutMs);
      const onJson = (m) => { if (predicate(m)) { cleanup(); resolve(m); } };
      const cleanup = () => { clearTimeout(timer); this.off('json', onJson); };
      this.on('json', onJson);
    });
  }

  close() {
    try { this.sendFrame(0x8, Buffer.from('bye')); } catch { /* noop */ }
    setTimeout(() => this.sock?.destroy(), 100);
  }
}
