// HamJam relay: one host per room streams binary audio frames to guests;
// guests send control commands (JSON) back to the host.
import { createServer as createHttpServer } from 'node:http';
import { WebSocketServer } from 'ws';
import { createStaticHandler } from './static.js';
import { randomInt, randomBytes } from 'node:crypto';

const PORT = Number(process.env.PORT || 8080);
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no look-alikes
const KEYS = new Set(['playPause', 'next', 'previous']);
const STATIC_DIR = process.env.STATIC_DIR || '';        // built website (web/dist)
const DOWNLOADS_DIR = process.env.DOWNLOADS_DIR || '';  // folder holding APKs (fallback)
const APK_UPSTREAM = process.env.APK_UPSTREAM || '';    // URL of the newest APK, streamed by /download/latest.apk
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

const LOG_ON = process.env.LOG !== 'off';
const log = (event, fields = {}) => {
  if (LOG_ON) console.log(JSON.stringify({ t: new Date().toISOString(), event, ...fields }));
};
const STATS_EVERY_MS = Number(process.env.STATS_EVERY_MS || 5000);
const SILENCE_MS = Number(process.env.SILENCE_MS || 5000); // guests waiting longer than this for audio => `no_audio`

const send = (ws, obj) => ws && ws.readyState === ws.OPEN && ws.send(JSON.stringify(obj));
const SWAP_TIMEOUT_MS = Number(process.env.SWAP_TIMEOUT_MS || 20000);

function endRoom(room, reason = 'host_left') {
  log('room_ended', { code: room.code, reason, guests: room.guests.size, framesTotal: room.stats.framesTotal });
  clearTimeout(room.swap?.timer);
  for (const g of room.guests) { send(g, { type: 'ended' }); g.close(); }
  rooms.delete(room.code);
}

export function createServer(port = PORT) {
  // Plain HTTP serves the website, APK downloads and health checks; WebSocket upgrades go to the relay.
  const site = createStaticHandler({ staticDir: STATIC_DIR, downloadsDir: DOWNLOADS_DIR, apkUpstream: APK_UPSTREAM });
  const http = createHttpServer((req, res) => {
    if (req.url === '/healthz') {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true, rooms: rooms.size }));
    } else {
      site(req, res).catch(() => { if (!res.headersSent) res.writeHead(500); res.end(); });
    }
  });
  const wss = new WebSocketServer({ server: http, maxPayload: 256 * 1024 });
  const closeWss = wss.close.bind(wss);
  wss.close = (cb) => { clearInterval(statsTimer); closeWss(() => http.close(cb)); http.closeAllConnections?.(); };
  http.listen(port);

  // Every few seconds: log audio throughput per room, and shout when guests are waiting for audio that isn't coming.
  const statsTimer = setInterval(() => {
    const now = Date.now();
    for (const room of rooms.values()) {
      const st = room.stats;
      const guests = room.guests.size;
      if (st.frames || guests) {
        log('audio_stats', { code: room.code, framesPerSec: +(st.frames / (STATS_EVERY_MS / 1000)).toFixed(1),
          kbps: Math.round((st.bytes * 8) / STATS_EVERY_MS), dropped: st.dropped, guests, hasMeta: !!room.meta,
          hasHost: !!room.host });
      }
      const silentFor = st.lastFrameAt ? now - st.lastFrameAt : now - room.createdAt;
      if (guests && room.host && silentFor > SILENCE_MS && !st.warned) {
        st.warned = true;
        log('no_audio', { code: room.code, guests, hasMeta: !!room.meta, everSentAudio: st.framesTotal > 0, silentForMs: silentFor });
      } else if (st.warned && st.frames) {
        st.warned = false;
        log('audio_resumed', { code: room.code });
      }
      st.frames = 0; st.bytes = 0; st.dropped = 0;
    }
  }, STATS_EVERY_MS);
  statsTimer.unref();

  wss.on('connection', (ws) => {
    let room = null;
    let role = null;
    let chatWindow = { t: 0, n: 0 };

    ws.on('message', (data, isBinary) => {
      if (isBinary) {
        // audio frame: only the host's frames are relayed
        if (role !== 'host') return;
        const st = room.stats;
        st.frames++; st.framesTotal++; st.bytes += data.length; st.lastFrameAt = Date.now();
        for (const g of room.guests) {
          // drop frames for slow guests instead of buffering unbounded latency
          if (g.readyState === g.OPEN && g.bufferedAmount < 512 * 1024) g.send(data, { binary: true });
          else st.dropped++;
        }
        return;
      }
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { return; }

      if (!role) {
        if (msg.type === 'create') {
          const code = newCode();
          room = { code, host: ws, guests: new Set(), createdAt: Date.now(),
            stats: { frames: 0, framesTotal: 0, bytes: 0, dropped: 0, lastFrameAt: 0, warned: false } };
          rooms.set(code, room);
          role = 'host';
          log('room_created', { code });
          send(ws, { type: 'created', code });
        } else if (msg.type === 'claim') {
          // new host after an approved role swap: needs the one-time token from swap_go
          const r = rooms.get(String(msg.code || '').toUpperCase());
          if (!r || !r.swap || r.swap.token !== msg.token) {
            log('claim_rejected', { code: String(msg.code || '').toUpperCase() });
            return send(ws, { type: 'error', error: 'claim_rejected' });
          }
          clearTimeout(r.swap.timer);
          r.swap = null;
          r.host = ws;
          r.meta = null;
          r.playback = null;
          room = r;
          role = 'host';
          log('claim_ok', { code: r.code, guests: r.guests.size });
          r.stats.warned = false;
          send(ws, { type: 'created', code: r.code });
          send(ws, { type: 'guests', count: r.guests.size });
        } else if (msg.type === 'join') {
          const r = rooms.get(String(msg.code || '').toUpperCase());
          if (!r) {
            log('join_failed', { reason: 'room_not_found', code: String(msg.code || '').toUpperCase() });
            return send(ws, { type: 'error', error: 'room_not_found' });
          }
          room = r;
          role = 'guest';
          ws.canHost = msg.client !== 'web'; // browsers can listen but cannot share audio
          room.guests.add(ws);
          send(ws, { type: 'joined', code: room.code });
          if (room.meta) send(ws, room.meta);
          if (room.playback) send(ws, room.playback);
          send(room.host, { type: 'guests', count: room.guests.size });
          log('guest_joined', { code: room.code, client: ws.canHost ? 'app' : 'web', guests: room.guests.size,
            hasMeta: !!room.meta, framesSoFar: room.stats.framesTotal });
        }
        return;
      }

      if (msg.type === 'swap_request') {
        if (role === 'guest' && !ws.canHost) return send(ws, { type: 'swap_declined', reason: 'unsupported' });
        if (room.pending || room.swap) return send(ws, { type: 'swap_declined', reason: 'busy' });
        log('swap_request', { code: room.code, from: role });
        const out = { type: 'swap_request', from: role };
        if (role === 'guest') {
          room.pending = { requester: ws, role };
          send(room.host, out);
        } else {
          const eligible = [...room.guests].filter((g) => g.canHost);
          if (!eligible.length) return send(ws, { type: 'swap_declined', reason: 'no_guest' });
          room.pending = { requester: ws, role };
          for (const g of eligible) send(g, out);
        }
      } else if (msg.type === 'swap_response') {
        const p = room.pending;
        // only the opposite side of the requester may answer
        if (!p || p.role === role || (role === 'guest' && !ws.canHost)) return;
        room.pending = null;
        const others = p.role === 'guest' ? [] : [...room.guests].filter((g) => g !== ws);
        if (!msg.accept) {
          send(p.requester, { type: 'swap_declined', reason: 'declined' });
          if (p.role === 'host') for (const g of others) send(g, { type: 'swap_cancelled' });
          return;
        }
        const newHost = p.role === 'guest' ? p.requester : ws;
        const oldHost = room.host;
        const token = randomBytes(16).toString('hex');
        log('swap_accepted', { code: room.code });
        room.swap = { token, newHost, oldHost, timer: setTimeout(() => endRoom(room, 'swap_timeout'), SWAP_TIMEOUT_MS) };
        for (const g of others) send(g, { type: 'swap_cancelled' });
        send(newHost, { type: 'swap_go', newRole: 'host', token });
        send(oldHost, { type: 'swap_go', newRole: 'guest' });
      } else if (msg.type === 'chat') {
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
      } else if (role === 'host' && msg.type === 'playback') {
        // is the host's player playing? cached for late joiners
        room.playback = { type: 'playback', playing: !!msg.playing };
        log('playback', { code: room.code, playing: room.playback.playing });
        for (const g of room.guests) send(g, room.playback);
      } else if (role === 'host' && msg.type === 'meta') {
        // now-playing / codec config etc. cached so late joiners get it
        room.meta = msg;
        log('meta', { code: room.code, sampleRate: msg.sampleRate, channels: msg.channels, csdBytes: msg.csd ? Buffer.from(String(msg.csd), 'base64').length : 0, guests: room.guests.size });
        for (const g of room.guests) send(g, msg);
      }
    });

    ws.on('close', () => {
      if (!room) return;
      if (room.pending?.requester === ws) {
        // requester vanished: withdraw the request from whoever was asked
        room.pending = null;
        send(room.host, { type: 'swap_cancelled' });
        for (const g of room.guests) send(g, { type: 'swap_cancelled' });
      }
      if (role === 'host') {
        if (room.host !== ws) return; // already replaced by a new host
        if (room.swap && room.swap.oldHost === ws) { room.host = null; return; } // handing over, keep the room
        endRoom(room);
      } else {
        room.guests.delete(ws);
        log('guest_left', { code: room.code, guests: room.guests.size });
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
