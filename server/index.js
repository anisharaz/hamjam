// HamJam relay: one host per room streams binary audio frames to guests;
// guests send control commands (JSON) back to the host.
import { WebSocketServer } from 'ws';
import { randomInt } from 'node:crypto';

const PORT = Number(process.env.PORT || 8080);
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no look-alikes
const KEYS = new Set(['playPause', 'next', 'previous']);
const MAX_CHAT = 500;
const CHAT_BURST = 5; // messages per second per connection

const rooms = new Map(); // code -> { host: ws, guests: Set<ws> }

function newCode() {
  for (;;) {
    let c = '';
    for (let i = 0; i < 6; i++) c += ALPHABET[randomInt(ALPHABET.length)];
    if (!rooms.has(c)) return c;
  }
}

const send = (ws, obj) => ws.readyState === ws.OPEN && ws.send(JSON.stringify(obj));

export function createServer(port = PORT) {
  const wss = new WebSocketServer({ port, maxPayload: 256 * 1024 });

  wss.on('connection', (ws) => {
    let room = null;
    let role = null;
    let chatWindow = { t: 0, n: 0 };

    ws.on('message', (data, isBinary) => {
      if (isBinary) {
        // audio frame: only the host's frames are relayed
        if (role !== 'host') return;
        for (const g of room.guests) {
          // drop frames for slow guests instead of buffering unbounded latency
          if (g.readyState === g.OPEN && g.bufferedAmount < 512 * 1024) g.send(data, { binary: true });
        }
        return;
      }
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { return; }

      if (!role) {
        if (msg.type === 'create') {
          const code = newCode();
          room = { code, host: ws, guests: new Set() };
          rooms.set(code, room);
          role = 'host';
          send(ws, { type: 'created', code });
        } else if (msg.type === 'join') {
          const r = rooms.get(String(msg.code || '').toUpperCase());
          if (!r) return send(ws, { type: 'error', error: 'room_not_found' });
          room = r;
          role = 'guest';
          room.guests.add(ws);
          send(ws, { type: 'joined', code: room.code });
          if (room.meta) send(ws, room.meta);
          send(room.host, { type: 'guests', count: room.guests.size });
        }
        return;
      }

      if (msg.type === 'chat') {
        // ephemeral: relayed to everyone in the room, never stored
        const text = typeof msg.text === 'string' ? msg.text.trim().slice(0, MAX_CHAT) : '';
        const now = Date.now();
        if (now - chatWindow.t > 1000) chatWindow = { t: now, n: 0 };
        if (!text || ++chatWindow.n > CHAT_BURST) return;
        const out = { type: 'chat', from: role, text, ts: now };
        send(room.host, out);
        for (const g of room.guests) send(g, out);
      } else if (role === 'guest' && msg.type === 'control' && KEYS.has(msg.key)) {
        send(room.host, { type: 'control', key: msg.key });
      } else if (role === 'host' && msg.type === 'meta') {
        // now-playing / codec config etc. cached so late joiners get it
        room.meta = msg;
        for (const g of room.guests) send(g, msg);
      }
    });

    ws.on('close', () => {
      if (!room) return;
      if (role === 'host') {
        for (const g of room.guests) { send(g, { type: 'ended' }); g.close(); }
        rooms.delete(room.code);
      } else {
        room.guests.delete(ws);
        send(room.host, { type: 'guests', count: room.guests.size });
      }
    });
  });

  return wss;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  createServer();
  console.log(`HamJam relay listening on :${PORT}`);
}
