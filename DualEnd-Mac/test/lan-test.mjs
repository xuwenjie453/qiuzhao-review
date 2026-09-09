// 局域网 bridge 可达性测试(模拟 iPad): 1) loopback 2) 局域网 IP
import { WsTestClient } from './ws-test-client.mjs';

async function handshake(port, host) {
  const client = new WsTestClient();
  await client.connect(port, '/bridge');
  client.sendJson({ v: 1, message_id: crypto.randomUUID(), type: 'HELLO', session_epoch: null, sent_at: new Date().toISOString(),
    payload: { device_id: 'lan-test', client_build: '1.0.0', supported_protocols: [1], last_server_seq: 0, cached_graph: null } });
  const w = await client.waitJson((m) => m.type === 'WELCOME', 4000);
  console.log(`OK ${host}:${port} → welcome epoch ${w.payload.session_epoch.slice(0, 8)}`);
  client.close();
}
// ws-test-client 固定连 127.0.0.1; 局域网测试需 host 参数 — 直接改造调用
import { connect } from 'node:net';
// 复用 client 类但需支持 host。快速手测: 用原始 socket 检查 TCP 可达 + HTTP upgrade
import { createHash, randomUUID } from 'node:crypto';
const key = randomUUID().replace(/-/g, '').slice(0, 24);
const sock = connect({ host: '192.168.1.200', port: 65158 });
sock.setTimeout(5000);
sock.on('connect', () => {
  console.log('TCP 192.168.1.200:65158 可达');
  sock.write('GET /bridge HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
    `Sec-WebSocket-Key: ${Buffer.from(key).toString('base64')}\r\nSec-WebSocket-Version: 13\r\n\r\n`);
});
let buf = '';
sock.on('data', (d) => { buf += d.toString(); if (buf.includes('101')) { console.log('WS 升级成功:', buf.split('\r\n')[0]); sock.destroy(); process.exit(0); } });
sock.on('timeout', () => { console.log('超时: 无响应'); sock.destroy(); process.exit(1); });
sock.on('error', (e) => { console.log('连接失败:', e.code || e.message); process.exit(1); });
