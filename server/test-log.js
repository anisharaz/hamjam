// The relay's logs are how we find out why a jam had no audio, so test what they say (and don't say).
import assert from 'node:assert/strict';
import WebSocket from 'ws';

process.env.STATS_EVERY_MS = '150';
process.env.SILENCE_MS = '300';
const lines = [];
const realLog = console.log;
console.log = (l) => { try { lines.push(JSON.parse(l)); } catch { /* not a log line */ } };

const { createServer } = await import('./index.js');
const wss = createServer(0);
await new Promise((r) => wss.on('listening', r));
const url = `ws://127.0.0.1:${wss.address().port}`;
const open = (u) => new Promise((res) => { const w = new WebSocket(u); w.msgs = []; w.on('message', (d, b) => !b && w.msgs.push(JSON.parse(d))); w.on('open', () => res(w)); });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const ev = (name) => lines.filter((l) => l.event === name);

const host = await open(url);
host.send(JSON.stringify({ type: 'create' }));
await wait(80);
const code = host.msgs[0].code;
assert.equal(ev('room_created')[0].code, code);

// a guest joins before any codec info exists: logged as hasMeta=false
const early = await open(url);
early.send(JSON.stringify({ type: 'join', code }));
await wait(80);
assert.equal(ev('guest_joined').at(-1).hasMeta, false);

host.send(JSON.stringify({ type: 'meta', sampleRate: 48000, channels: 2, csd: Buffer.from([0x11, 0x90]).toString('base64') }));
await wait(50);
assert.deepEqual([ev('meta')[0].sampleRate, ev('meta')[0].csdBytes], [48000, 2]);

// late guest sees the cached codec info
const late = await open(url);
late.send(JSON.stringify({ type: 'join', code, client: 'web' }));
await wait(80);
assert.deepEqual([ev('guest_joined').at(-1).hasMeta, ev('guest_joined').at(-1).client], [true, 'web']);

// audio flowing: throughput is reported
for (let i = 0; i < 20; i++) { host.send(Buffer.alloc(400)); await wait(8); }
await wait(250);
const stats = ev('audio_stats').filter((s) => s.code === code && s.framesPerSec > 0);
assert.ok(stats.length >= 1, 'audio_stats with frames');
assert.equal(stats[0].guests, 2);
assert.equal(ev('no_audio').length, 0, 'no warning while audio flows');

// host goes quiet while guests wait: the watchdog warns once, then notes the recovery
await wait(700);
const warn = ev('no_audio');
assert.equal(warn.length, 1, 'exactly one no_audio warning per episode');
assert.deepEqual([warn[0].guests, warn[0].everSentAudio, warn[0].hasMeta], [2, true, true]);
host.send(Buffer.alloc(400));
await wait(300);
assert.equal(ev('audio_resumed').length, 1);

// privacy: chat text and addresses never reach the logs
host.send(JSON.stringify({ type: 'chat', text: 'super private message' }));
await wait(100);
assert.ok(!JSON.stringify(lines).includes('super private'), 'chat text must not be logged');
assert.ok(!JSON.stringify(lines).includes('127.0.0.1'), 'client addresses must not be logged');

host.close();
await wait(100);
assert.equal(ev('room_ended').at(-1).reason, 'host_left');

console.log = realLog;
console.log('log tests passed');
wss.close();
process.exit(0);
