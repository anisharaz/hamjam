// Minimal static file + APK download handler (no dependencies).
import { createReadStream } from 'node:fs';
import { readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { Readable } from 'node:stream';

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.apk': 'application/vnd.android.package-archive',
};

const SECURITY_HEADERS = {
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'strict-origin-when-cross-origin',
  'x-frame-options': 'DENY',
  'content-security-policy':
    "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'",
};

function reply(res, status, body, headers = {}) {
  res.writeHead(status, { ...SECURITY_HEADERS, ...headers });
  res.end(body);
}

/** Resolves a URL path inside root, or null if it would escape it. */
function safeJoin(root, urlPath) {
  let decoded;
  try { decoded = decodeURIComponent(urlPath); } catch { return null; }
  if (decoded.includes('\0')) return null;
  const full = path.join(root, path.normalize(decoded));
  return full === root || full.startsWith(root + path.sep) ? full : null;
}

async function isFile(p) {
  try { return (await stat(p)).isFile(); } catch { return false; }
}

function sendFile(req, res, file, headers) {
  return stat(file).then((s) => {
    res.writeHead(200, { ...SECURITY_HEADERS, 'content-length': s.size, ...headers });
    if (req.method === 'HEAD') return res.end();
    createReadStream(file).on('error', () => res.destroy()).pipe(res);
  });
}

/**
 * Streams the APK from upstream (the newest GitHub release) so the browser stays on our
 * domain and gets a real download. Returns false if upstream is unavailable.
 */
async function proxyUpstream(req, res, url) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 8000); // only bounds the wait for headers
  let up;
  try {
    up = await fetch(url, { method: req.method, redirect: 'follow', signal: ctrl.signal });
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
  if (!up.ok) {
    up.body?.cancel();
    return false;
  }
  const len = up.headers.get('content-length');
  res.writeHead(200, {
    ...SECURITY_HEADERS,
    'content-type': TYPES['.apk'],
    'content-disposition': 'attachment; filename="HamJam.apk"',
    'cache-control': 'no-cache',
    ...(len ? { 'content-length': len } : {}),
  });
  if (req.method === 'HEAD' || !up.body) {
    up.body?.cancel();
    res.end();
    return true;
  }
  res.on('close', () => ctrl.abort()); // client left: stop pulling from upstream
  Readable.fromWeb(up.body).on('error', () => res.destroy()).pipe(res);
  return true;
}

/** Highest-numbered N.apk in dir (publish-apk.sh output), else hamjam.apk. */
async function latestApk(dir) {
  try {
    const names = await readdir(dir);
    const numbered = names.filter((n) => /^\d+\.apk$/.test(n)).sort((a, b) => parseInt(b) - parseInt(a));
    if (numbered.length) return path.join(dir, numbered[0]);
    if (names.includes('hamjam.apk')) return path.join(dir, 'hamjam.apk');
  } catch { /* directory missing */ }
  return null;
}

export function createStaticHandler({ staticDir, downloadsDir, apkUpstream }) {
  const root = staticDir ? path.resolve(staticDir) : null;
  const downloads = downloadsDir ? path.resolve(downloadsDir) : null;

  return async function handle(req, res) {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      return reply(res, 405, 'Method not allowed', { allow: 'GET, HEAD' });
    }
    const { pathname } = new URL(req.url, 'http://x');

    // ---- APK downloads ----
    if (pathname.startsWith('/download/')) {
      const name = pathname.slice('/download/'.length);
      let file = null;
      if (name === 'latest.apk' && apkUpstream && (await proxyUpstream(req, res, apkUpstream))) return;
      if (downloads && name === 'latest.apk') file = await latestApk(downloads);
      else if (downloads && /^[\w.-]+\.apk$/.test(name)) {
        const p = safeJoin(downloads, name);
        if (p && (await isFile(p))) file = p;
      }
      if (!file) return reply(res, 404, 'No APK published yet', { 'content-type': 'text/plain' });
      return sendFile(req, res, file, {
        'content-type': TYPES['.apk'],
        'content-disposition': 'attachment; filename="HamJam.apk"',
        'cache-control': 'no-cache',
      });
    }

    // ---- the website ----
    if (!root) return reply(res, 404, 'Not found', { 'content-type': 'text/plain' });
    const target = pathname === '/' ? '/index.html' : pathname;
    const file = safeJoin(root, target);
    if (!file) return reply(res, 400, 'Bad request', { 'content-type': 'text/plain' });

    if (await isFile(file)) {
      const ext = path.extname(file).toLowerCase();
      const hashed = target.startsWith('/assets/'); // vite fingerprints these
      return sendFile(req, res, file, {
        'content-type': TYPES[ext] || 'application/octet-stream',
        'cache-control': hashed ? 'public, max-age=31536000, immutable' : 'no-cache',
      });
    }
    // a missing file with an extension is a real 404; anything else falls back to the page
    if (path.extname(pathname)) return reply(res, 404, 'Not found', { 'content-type': 'text/plain' });
    return sendFile(req, res, path.join(root, 'index.html'), {
      'content-type': TYPES['.html'],
      'cache-control': 'no-cache',
    });
  };
}
