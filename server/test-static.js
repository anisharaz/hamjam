import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const tmp = mkdtempSync(path.join(tmpdir(), 'hamjam-'));
const site = path.join(tmp, 'site');
const dl = path.join(tmp, 'dl');
mkdirSync(path.join(site, 'assets'), { recursive: true });
mkdirSync(dl);
writeFileSync(path.join(site, 'index.html'), '<h1>home</h1>');
writeFileSync(path.join(site, 'assets', 'app-abc.js'), 'console.log(1)');
writeFileSync(path.join(tmp, 'secret.txt'), 'top secret');
for (const n of ['2.apk', '10.apk', '9.apk']) writeFileSync(path.join(dl, n), `apk ${n}`);

process.env.STATIC_DIR = site;
process.env.DOWNLOADS_DIR = dl;
const { createServer } = await import('./index.js');
const wss = createServer(0);
await new Promise((r) => wss.on('listening', r));
const base = `http://127.0.0.1:${wss.address().port}`;
const get = (p, opts) => fetch(base + p, opts);

let r = await get('/');
assert.equal(r.status, 200);
assert.match(r.headers.get('content-type'), /text\/html/);
assert.equal(r.headers.get('cache-control'), 'no-cache');
assert.equal(r.headers.get('x-content-type-options'), 'nosniff');
assert.equal(await r.text(), '<h1>home</h1>');

r = await get('/assets/app-abc.js');
assert.match(r.headers.get('content-type'), /javascript/);
assert.match(r.headers.get('cache-control'), /immutable/);

r = await get('/some/page'); // no extension: falls back to the app shell
assert.equal(await r.text(), '<h1>home</h1>');
assert.equal((await get('/missing.png')).status, 404);

// path traversal must never reach files outside the site folder
for (const p of ['/..%2fsecret.txt', '/%2e%2e/secret.txt', '/assets/..%2f..%2fsecret.txt', '/%00', '/%zz']) {
  r = await get(p);
  assert.ok(r.status === 400 || r.status === 404 || (await r.text()) === '<h1>home</h1>', `traversal ${p}`);
}
assert.notEqual(await (await get('/..%2fsecret.txt')).text(), 'top secret');

// APK downloads: latest picks the highest number, not the lexicographic one
r = await get('/download/latest.apk');
assert.equal(r.status, 200);
assert.equal(r.headers.get('content-type'), 'application/vnd.android.package-archive');
assert.match(r.headers.get('content-disposition'), /attachment/);
assert.equal(await r.text(), 'apk 10.apk');
assert.equal(await (await get('/download/2.apk')).text(), 'apk 2.apk');
assert.equal((await get('/download/..%2fsecret.txt')).status, 404);
assert.equal((await get('/download/nothing.apk')).status, 404);

assert.equal((await get('/', { method: 'POST' })).status, 405);
assert.equal((await get('/healthz')).status, 200);
const head = await get('/download/latest.apk', { method: 'HEAD' });
assert.equal(head.status, 200);
assert.equal(await head.text(), '');

console.log('static tests passed');
wss.close();
process.exit(0);
