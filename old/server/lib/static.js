'use strict';
// Static file server for the exported Godot web build.
// - correct MIME types (application/wasm matters for streaming compilation)
// - COOP/COEP headers (needed by threaded Godot builds, harmless otherwise)
// - gzip + brotli, compressed once per file version and kept in memory (the .wasm is ~35 MB raw)
// - ETag + no-cache so a re-export is picked up on reload without stale caches
// - path-traversal safe, dotfiles hidden

const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const zlib = require('node:zlib');
const { promisify } = require('node:util');
const { log, warn } = require('./log');

const gzip = promisify(zlib.gzip);
const brotli = promisify(zlib.brotliCompress);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.htm': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.css': 'text/css; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ogg': 'audio/ogg',
  '.wav': 'audio/wav',
  '.mp3': 'audio/mpeg',
};
const COMPRESSIBLE = new Set(['.html', '.htm', '.js', '.mjs', '.wasm', '.pck', '.json', '.webmanifest', '.css', '.txt', '.map', '.svg']);
const MIN_COMPRESS_BYTES = 1024;
const MAX_CACHED_BYTES = 256 * 1024 * 1024; // larger files are streamed from disk uncompressed

const SECURITY_HEADERS = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Resource-Policy': 'same-origin',
  'X-Content-Type-Options': 'nosniff',
};

/** "gzip, deflate, br;q=0.8, zstd;q=0" -> Set {gzip, deflate, br} (q=0 means refused). */
function parseAcceptEncoding(header) {
  const out = new Set();
  for (const item of String(header || '').split(',')) {
    const [name, ...params] = item.trim().toLowerCase().split(';');
    if (!name) continue;
    let q = 1;
    for (const p of params) {
      const m = /^\s*q\s*=\s*([\d.]+)\s*$/.exec(p);
      if (m) q = parseFloat(m[1]);
    }
    if (q > 0) out.add(name);
  }
  return out;
}

function missingBuildPage() {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SpeedFest server</title>
<style>
  body{margin:0;min-height:100vh;display:grid;place-items:center;background:#070b1a;color:#dfe8ff;
       font:16px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
  main{max-width:560px;padding:32px;border:1px solid #1f6fff55;border-radius:14px;
       background:linear-gradient(160deg,#0d1430,#0a0f22);box-shadow:0 0 40px #00e5ff22}
  h1{margin:0 0 8px;font-size:28px;letter-spacing:.06em;color:#00e5ff;text-shadow:0 0 12px #00e5ff88}
  code{background:#ffffff14;padding:2px 6px;border-radius:6px}
  a{color:#ff6a00}
</style></head>
<body><main>
  <h1>SPEEDFEST</h1>
  <p>The server is running, but the <b>web build is missing</b>.</p>
  <p>Export it with <code>tools/export_web.sh</code> (writes <code>server/public/</code>),
     or start the server with <code>PUBLIC_DIR=/path/to/export npm start</code>.</p>
  <p>Server status: <a href="/health">/health</a></p>
</main></body></html>`;
}

class StaticFiles {
  /**
   * @param {string} publicDir absolute directory to serve
   * @param {object} [o]
   * @param {boolean} [o.brotli=true] also precompute brotli
   * @param {number} [o.brotliQuality=5]
   * @param {number} [o.gzipLevel=8]
   */
  constructor(publicDir, o = {}) {
    this.root = path.resolve(publicDir);
    this.useBrotli = o.brotli ?? true;
    this.brotliQuality = o.brotliQuality ?? 5;
    this.gzipLevel = o.gzipLevel ?? 8;
    this.cache = new Map(); // abs path -> entry
  }

  hasBuild() {
    try {
      return fs.statSync(path.join(this.root, 'index.html')).isFile();
    } catch {
      return false;
    }
  }

  /** Load + compress every servable file in the background so the first visitor gets gzip/br. */
  async warm() {
    if (!this.hasBuild()) {
      warn(`web build not found in ${this.root} (serving a placeholder page)`);
      return;
    }
    const files = [];
    const walk = async (dir, depth) => {
      if (depth > 4) return;
      let entries;
      try {
        entries = await fsp.readdir(dir, { withFileTypes: true });
      } catch {
        return;
      }
      for (const e of entries) {
        if (e.name.startsWith('.')) continue;
        const abs = path.join(dir, e.name);
        if (e.isDirectory()) await walk(abs, depth + 1);
        else if (e.isFile()) files.push(abs);
      }
    };
    await walk(this.root, 0);
    const t0 = Date.now();
    for (const abs of files) {
      try {
        const st = await fsp.stat(abs);
        const entry = this._entry(await fsp.realpath(abs), st);
        await entry.ready;
      } catch (err) {
        warn(`warm ${abs}: ${err.message}`);
      }
    }
    log(`static: ${files.length} file(s) from ${this.root} ready in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  }

  _entry(abs, st) {
    const version = `${st.size}-${Math.floor(st.mtimeMs)}`;
    const cached = this.cache.get(abs);
    if (cached && cached.version === version) return cached;
    const ext = path.extname(abs).toLowerCase();
    const entry = {
      version,
      size: st.size,
      etag: `W/"${st.size.toString(16)}-${Math.floor(st.mtimeMs).toString(16)}"`,
      mime: MIME[ext] || 'application/octet-stream',
      raw: null,
      gzip: null,
      br: null,
      ready: null,
    };
    this.cache.set(abs, entry);
    if (st.size > MAX_CACHED_BYTES) {
      entry.ready = Promise.resolve();
      return entry;
    }
    entry.ready = (async () => {
      const raw = await fsp.readFile(abs);
      entry.raw = raw;
      if (!COMPRESSIBLE.has(ext) || raw.length < MIN_COMPRESS_BYTES) return;
      const t0 = Date.now();
      const gz = await gzip(raw, { level: this.gzipLevel });
      if (gz.length < raw.length * 0.95) entry.gzip = gz;
      if (this.useBrotli) {
        const br = await brotli(raw, {
          params: {
            [zlib.constants.BROTLI_PARAM_QUALITY]: this.brotliQuality,
            [zlib.constants.BROTLI_PARAM_SIZE_HINT]: raw.length,
          },
        });
        if (br.length < raw.length * 0.95) entry.br = br;
      }
      if (raw.length > 512 * 1024) {
        const mb = (n) => (n / 1048576).toFixed(1);
        log(
          `static: ${path.basename(abs)} ${mb(raw.length)} MB -> gzip ${entry.gzip ? mb(entry.gzip.length) : '-'} MB` +
            `, br ${entry.br ? mb(entry.br.length) : '-'} MB (${((Date.now() - t0) / 1000).toFixed(1)}s)`
        );
      }
    })().catch((err) => {
      warn(`static: could not load ${abs}: ${err.message}`);
      this.cache.delete(abs);
    });
    return entry;
  }

  _resolve(urlPath) {
    let pathname;
    try {
      pathname = decodeURIComponent(urlPath.split('?')[0].split('#')[0]);
    } catch {
      return { status: 400 };
    }
    if (pathname.includes('\0') || pathname.includes('\\')) return { status: 400 };
    const parts = pathname.split('/').filter((s) => s.length > 0);
    for (const part of parts) {
      if (part === '..' || part.startsWith('.')) return { status: 404 };
    }
    let rel = parts.join(path.sep);
    if (pathname.endsWith('/') || rel === '') rel = path.join(rel, 'index.html');
    const abs = path.resolve(this.root, rel);
    if (abs !== this.root && !abs.startsWith(this.root + path.sep)) return { status: 404 };
    return { abs, isIndex: path.basename(abs) === 'index.html' };
  }

  /** Serve a GET/HEAD request. Always ends the response. */
  async handle(req, res) {
    const send = (status, body, headers = {}) => {
      res.writeHead(status, { ...SECURITY_HEADERS, 'Content-Type': 'text/plain; charset=utf-8', ...headers });
      res.end(req.method === 'HEAD' ? undefined : body);
    };
    if (req.method !== 'GET' && req.method !== 'HEAD') return send(405, 'Method Not Allowed', { Allow: 'GET, HEAD' });

    const r = this._resolve(req.url || '/');
    if (r.status) return send(r.status, r.status === 400 ? 'Bad Request' : 'Not Found');
    let abs = r.abs;
    let st;
    try {
      st = await fsp.stat(abs);
      if (st.isDirectory()) {
        abs = path.join(abs, 'index.html');
        st = await fsp.stat(abs);
      }
      if (!st.isFile()) throw new Error('not a file');
    } catch {
      if (r.isIndex && path.dirname(abs) === this.root) {
        return send(200, missingBuildPage(), { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      }
      return send(404, 'Not Found');
    }

    // Key the cache on the on-disk path: on case-insensitive hosts (Windows/macOS) /INDEX.wasm and
    // /index.wasm are the same file and must share one cached copy (the .wasm is ~35 MB).
    let real;
    try {
      real = await fsp.realpath(abs);
    } catch {
      return send(404, 'Not Found');
    }
    const entry = this._entry(real, st);
    if (entry.raw === null && st.size <= MAX_CACHED_BYTES) {
      // First request for this file version: wait for the raw bytes (compression may finish later).
      await Promise.race([entry.ready, new Promise((resolve) => setTimeout(resolve, 150))]);
    }

    const headers = {
      ...SECURITY_HEADERS,
      'Content-Type': entry.mime,
      'Cache-Control': 'no-cache',
      ETag: entry.etag,
      Vary: 'Accept-Encoding',
    };
    if (req.headers['if-none-match'] === entry.etag) {
      res.writeHead(304, headers);
      return res.end();
    }

    const accepted = parseAcceptEncoding(req.headers['accept-encoding']);
    let body = entry.raw;
    if (entry.br && accepted.has('br')) {
      body = entry.br;
      headers['Content-Encoding'] = 'br';
    } else if (entry.gzip && accepted.has('gzip')) {
      body = entry.gzip;
      headers['Content-Encoding'] = 'gzip';
    }

    if (body === null) {
      // Not cached (huge file or still loading): stream from disk uncompressed.
      headers['Content-Length'] = st.size;
      res.writeHead(200, headers);
      if (req.method === 'HEAD') return res.end();
      const stream = fs.createReadStream(abs);
      stream.on('error', () => res.destroy());
      stream.pipe(res);
      return;
    }
    headers['Content-Length'] = body.length;
    res.writeHead(200, headers);
    res.end(req.method === 'HEAD' ? undefined : body);
  }
}

module.exports = { StaticFiles, MIME, SECURITY_HEADERS };
