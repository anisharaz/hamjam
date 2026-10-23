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

// playback state: relayed to guests and replayed to late joiners
host.send(JSON.stringify({ type: 'playback', playing: true }));
await wait();
assert.deepEqual(guest.msgs.at(-1), { type: 'playback', playing: true });
const joiner = await open(url);
joiner.send(JSON.stringify({ type: 'join', code }));
await wait();
assert.deepEqual(joiner.msgs.find((m) => m.type === 'playback'), { type: 'playback', playing: true });
joiner.close();

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

// ---- role swap: guest asks to host, host approves
const last = (w, t) => w.msgs.filter((m) => m.type === t).at(-1);
guest.send(JSON.stringify({ type: 'swap_request' }));
await wait();
assert.deepEqual(last(host, 'swap_request'), { type: 'swap_request', from: 'guest' });
host.send(JSON.stringify({ type: 'swap_response', accept: false }));
await wait();
assert.equal(last(guest, 'swap_declined').reason, 'declined');

guest.send(JSON.stringify({ type: 'swap_request' }));
guest.send(JSON.stringify({ type: 'swap_response', accept: true })); // requester can't approve own request
await wait();
assert.equal(last(guest, 'swap_go'), undefined);
host.send(JSON.stringify({ type: 'swap_response', accept: true }));
await wait();
const goNew = last(guest, 'swap_go');
assert.equal(goNew.newRole, 'host');
assert.equal(last(host, 'swap_go').newRole, 'guest');

// old host leaves; room must survive. wrong token is rejected, right token claims host.
host.close();
await wait();
const impostor = await open(url);
impostor.send(JSON.stringify({ type: 'claim', code, token: 'nope' }));
await wait();
assert.equal(impostor.msgs[0].error, 'claim_rejected');
const newHost = await open(url);
newHost.send(JSON.stringify({ type: 'claim', code, token: goNew.token }));
guest.close(); // new host's old listener connection goes away
await wait();
assert.deepEqual(newHost.msgs.map((m) => m.type).slice(0, 2), ['created', 'guests']);
const oldHost = await open(url);
oldHost.send(JSON.stringify({ type: 'join', code }));
await wait();
assert.equal(oldHost.msgs[0].type, 'joined');
assert.deepEqual(last(newHost, 'guests'), { type: 'guests', count: 1 });
newHost.send(Buffer.from([7]));
await wait();
assert.deepEqual([...oldHost.msgs.at(-1)], [7]);

// host-initiated handover, declined path and no-guest path
newHost.send(JSON.stringify({ type: 'swap_request' }));
await wait();
assert.deepEqual(last(oldHost, 'swap_request'), { type: 'swap_request', from: 'host' });
oldHost.send(JSON.stringify({ type: 'swap_response', accept: false }));
await wait();
assert.equal(last(newHost, 'swap_declined').reason, 'declined');

newHost.close();
await wait();
assert.equal(oldHost.msgs.at(-1).type, 'ended');
console.log('server tests passed');
wss.close();
process.exit(0);
