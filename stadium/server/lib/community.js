'use strict';
// The game's Community page browses TrackMania Exchange (tracks) and ManiaPark (car models and
// skins) itself, except in a browser: those sites send no CORS headers, so the web build goes
// through this read-only pass-through. Only what the page needs is passed: searches, preview
// images and the files, from the two sites, by GET.
//
//   GET /api/community/tmx/api/tracks?...                 TMNF-X track search (JSON)
//   GET /api/community/tmx/trackshow/<id>/image/<0|1>      a track's thumbnail / screenshot
//   GET /api/community/tmx/trackgbx/<id>                   a track file
//   GET /api/community/maniapark/api/search?...            ManiaPark search (JSON)
//   GET /api/community/maniapark/image/<id>                a car's preview image
//   GET /api/community/maniapark/(model|skin|mod)/<id>/download   a car pack or a texture mod

const SITES = {
  tmx: { host: 'https://tmnf.exchange', paths: [/^\/api\/tracks$/, /^\/trackshow\/\d{1,10}\/image\/[01]$/, /^\/trackgbx\/\d{1,10}$/] },
  maniapark: { host: 'https://maniapark.com',
    paths: [/^\/api\/search$/, /^\/image\/[A-Za-z0-9_-]{1,40}$/, /^\/(?:model|skin|mod)\/[A-Za-z0-9_-]{1,40}\/download$/] },
};
const MAX_BYTES = 200 * 1024 * 1024;   // texture mods ship 4K textures (ManiaPark's run to ~150 MB)
const UA = 'SpeedFestStadium-server/1.0 (+https://github.com/khanhonthetrack/speedfest)';
const PASS_TYPES = /^(application\/json|image\/(jpeg|png|webp|gif)|application\/(zip|x-zip-compressed|octet-stream))/i;

class Community {
  /** fetch: the upstream fetch (tests pass their own). */
  constructor({ fetch: fetchFn = globalThis.fetch, maxBytes = MAX_BYTES } = {}) {
    this.fetch = fetchFn;
    this.maxBytes = maxBytes;
  }

  /** The upstream URL for a request path under /api/community, or '' if it isn't one we pass. */
  static upstream(pathname, search) {
    const m = String(pathname).match(/^\/api\/community\/(tmx|maniapark)(\/.*)$/);
    if (!m) return '';
    const site = SITES[m[1]];
    if (!site.paths.some((re) => re.test(m[2]))) return '';
    return site.host + m[2] + (search || '');
  }

  /** Handles /api/community requests; false for any other path. */
  handle(req, res) {
    const url = new URL(req.url, 'http://x');
    if (!url.pathname.startsWith('/api/community/')) return false;
    const cors = { 'access-control-allow-origin': '*' };
    if (req.method === 'OPTIONS') {
      res.writeHead(204, { ...cors, 'access-control-allow-methods': 'GET', 'access-control-allow-headers': 'content-type' });
      res.end();
      return true;
    }
    const target = req.method === 'GET' ? Community.upstream(url.pathname, url.search) : '';
    if (!target) {
      res.writeHead(404, { ...cors, 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: 'not a community path' }));
      return true;
    }
    this._pass(target, res, cors).catch((e) => {
      if (!res.headersSent) res.writeHead(502, { ...cors, 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: `the community site can't be reached (${e.message})` }));
    });
    return true;
  }

  async _pass(target, res, cors) {
    const up = await this.fetch(target, { headers: { 'user-agent': UA }, redirect: 'follow' });
    const type = String(up.headers.get('content-type') || 'application/octet-stream');
    if (!up.ok || !PASS_TYPES.test(type)) {
      res.writeHead(up.ok ? 502 : up.status, { ...cors, 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: up.ok ? `unexpected ${type}` : `upstream ${up.status}` }));
      return;
    }
    const buf = Buffer.from(await up.arrayBuffer());
    if (buf.length > this.maxBytes) {
      res.writeHead(502, { ...cors, 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: 'too big' }));
      return;
    }
    const headers = { ...cors, 'content-type': type, 'content-length': buf.length,
      'cache-control': /json/i.test(type) ? 'no-store' : 'public, max-age=86400' };
    const disposition = up.headers.get('content-disposition');
    if (disposition) headers['content-disposition'] = disposition;
    res.writeHead(200, headers);
    res.end(buf);
  }
}

/** A fetch over local files standing in for the two sites (the game's tests: --community-fixtures=dir):
 *  tmx_tracks.json, tmx_<id>.jpg|png (both images), tmx_<id>.Challenge.Gbx, mp_search_<asset>.json,
 *  mp_img_<id>.webp|png, mp_<id>.zip. */
function fixtureFetch(dir) {
  const fs = require('fs');
  const path = require('path');
  const types = { '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp',
    '.gbx': 'application/octet-stream', '.zip': 'application/zip' };
  const pick = (...names) => names.map((n) => path.join(dir, n)).find((f) => fs.existsSync(f));
  return async (url) => {
    const u = new URL(url);
    let m;
    let file;
    if (u.host === 'tmnf.exchange') {
      if (u.pathname === '/api/tracks') file = pick('tmx_tracks.json');
      else if ((m = u.pathname.match(/^\/trackshow\/(\d+)\/image\/\d$/))) file = pick(`tmx_${m[1]}.jpg`, `tmx_${m[1]}.png`);
      else if ((m = u.pathname.match(/^\/trackgbx\/(\d+)$/))) file = pick(`tmx_${m[1]}.Challenge.Gbx`);
    } else if (u.host === 'maniapark.com') {
      if (u.pathname === '/api/search') file = pick(`mp_search_${u.searchParams.get('asset')}.json`);
      else if ((m = u.pathname.match(/^\/image\/([\w-]+)$/))) file = pick(`mp_img_${m[1]}.webp`, `mp_img_${m[1]}.png`);
      else if ((m = u.pathname.match(/^\/(?:model|skin|mod)\/([\w-]+)\/download$/))) file = pick(`mp_${m[1]}.zip`);
    }
    const body = file ? fs.readFileSync(file) : null;
    const type = file ? (types[path.extname(file).toLowerCase()] || 'application/octet-stream') : 'text/html';
    return { ok: !!body, status: body ? 200 : 404, headers: new Map([['content-type', type]]),
      arrayBuffer: async () => (body ? body.buffer.slice(body.byteOffset, body.byteOffset + body.length) : new ArrayBuffer(0)) };
  };
}

module.exports = { Community, SITES, fixtureFetch };
