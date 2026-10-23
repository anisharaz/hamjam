import assert from 'node:assert/strict';
import WebSocket from 'ws';
import { createServer } from './index.js';

const wss = createServer(0);
await new Promise((r) => wss.on('listening', r));
const url = `ws://127.0.0.1:${wss.address().port}`;

const open = (u) => new Promise((res) => { const w = new WebSocket(u); w.msgs = []; w.on('message', (d, b) => w.msgs.push(b ? d : JSON.parse(d))); w.on('open', () => res(w)); });
const wait = (ms = 80) => new Promise((r) => setTimeout(r, ms));

const host = await open(url);
host.send(JSON.stringify({ type: 'create' }));
await wait();
const code = host.msgs[0].code;
assert.match(code, /^[A-Z2-9]{6}$/);

const bad = await open(url);
bad.send(JSON.stringify({ type: 'join', code: 'NOPE00' }));
await wait();
assert.equal(bad.msgs[0].error, 'room_not_found');

const guest = await open(url);
guest.send(JSON.stringify({ type: 'join', code: code.toLowerCase() }));
await wait();
assert.equal(guest.msgs[0].type, 'joined');
assert.deepEqual(host.msgs.at(-1), { type: 'guests', count: 1 });

host.send(Buffer.from([1, 2, 3]));
await wait();
assert.deepEqual([...guest.msgs.at(-1)], [1, 2, 3]);

guest.send(Buffer.from([9, 9])); // guests can't inject audio
guest.send(JSON.stringify({ type: 'control', key: 'next' }));
guest.send(JSON.stringify({ type: 'control', key: 'rm -rf' }));
await wait();
assert.deepEqual(host.msgs.filter((m) => m.type === 'control'), [{ type: 'control', key: 'next' }]);
assert.equal(guest.msgs.filter((m) => Buffer.isBuffer(m)).length, 1);

// chat: relayed to both sides with sender role, trimmed, empty/oversized handled, rate limited
guest.send(JSON.stringify({ type: 'chat', text: '  hi  ' }));
host.send(JSON.stringify({ type: 'chat', text: 'hello' }));
guest.send(JSON.stringify({ type: 'chat', text: '   ' }));
guest.send(JSON.stringify({ type: 'chat', text: 'x'.repeat(900) }));
await wait();
const chats = (w) => w.msgs.filter((m) => m.type === 'chat');
const got = chats(host).map((m) => `${m.from}:${m.text.length > 10 ? m.text.length : m.text}`).sort();
assert.deepEqual(got, ['guest:500', 'guest:hi', 'host:hello']);
assert.equal(chats(guest).length, 3);
for (let i = 0; i < 20; i++) guest.send(JSON.stringify({ type: 'chat', text: 'spam' + i }));
await wait();
assert.ok(chats(host).length <= 3 + 5, 'rate limit');

// a guest joining later does not receive past chat
const late = await open(url);
late.send(JSON.stringify({ type: 'join', code }));
await wait();
assert.equal(chats(late).length, 0);
late.close();

host.close();
await wait();
assert.equal(guest.msgs.at(-1).type, 'ended');
console.log('server tests passed');
wss.close();
process.exit(0);
