'use strict';
// The Community page's pass-through (lib/community.js): only the two sites' searches, previews and
// files, by GET, with CORS headers for the web build; the fixtures mode the game's tests use.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { Community, fixtureFetch } = require('../lib/community');
const { createApp } = require('../server');

test('community: only the listed paths pass, to the right site', () => {
  assert.strictEqual(Community.upstream('/api/community/tmx/api/tracks', '?name=loop&count=12'),
    'https://tmnf.exchange/api/tracks?name=loop&count=12');
  assert.strictEqual(Community.upstream('/api/community/tmx/trackshow/924307/image/0', ''), 'https://tmnf.exchange/trackshow/924307/image/0');
  assert.strictEqual(Community.upstream('/api/community/tmx/trackgbx/924307', ''), 'https://tmnf.exchange/trackgbx/924307');
  assert.strictEqual(Community.upstream('/api/community/maniapark/api/search', '?asset=1&game=0'),
    'https://maniapark.com/api/search?asset=1&game=0');
  assert.strictEqual(Community.upstream('/api/community/maniapark/image/LeaDexiKm06i9B8eeZSVhw', '?hq=false'),
    'https://maniapark.com/image/LeaDexiKm06i9B8eeZSVhw?hq=false');
  assert.strictEqual(Community.upstream('/api/community/maniapark/skin/EmhLo4LKW0CRNFjOvMCJxg/download', ''),
    'https://maniapark.com/skin/EmhLo4LKW0CRNFjOvMCJxg/download');
  for (const p of ['/api/community/tmx/api/users', '/api/community/tmx/trackgbx/12/../../x', '/api/community/evil/api/tracks',
    '/api/community/maniapark/account/login', '/api/community/tmx/trackshow/1/image/5']) {
    assert.strictEqual(Community.upstream(p, ''), '', p);
  }
});

test('community: the server passes files through with CORS, refuses the rest', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'community-'));
  fs.writeFileSync(path.join(dir, 'tmx_tracks.json'), JSON.stringify({ More: false, Results: [{ TrackId: 7, TrackName: 'Seven' }] }));
  fs.writeFileSync(path.join(dir, 'tmx_7.png'), Buffer.from([0x89, 0x50, 0x4e, 0x47]));
  fs.writeFileSync(path.join(dir, 'mp_abc.zip'), Buffer.from('PK\x03\x04zip'));
  const app = createApp({ communityFixtures: dir, servers: [{ id: 'main' }] });
  await new Promise((r) => app.listen(0, r, '127.0.0.1'));
  const base = `http://127.0.0.1:${app.httpServer.address().port}/api/community`;
  try {
    let r = await fetch(`${base}/tmx/api/tracks?name=seven`);
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.headers.get('access-control-allow-origin'), '*');
    assert.deepStrictEqual((await r.json()).Results[0], { TrackId: 7, TrackName: 'Seven' });
    r = await fetch(`${base}/tmx/trackshow/7/image/0`);
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.headers.get('content-type'), 'image/png');
    assert.match(r.headers.get('cache-control'), /max-age/);
    r = await fetch(`${base}/maniapark/model/abc/download`);
    assert.strictEqual(r.status, 200);
    assert.strictEqual(Buffer.from(await r.arrayBuffer()).toString('latin1', 0, 2), 'PK');
    r = await fetch(`${base}/tmx/trackgbx/8`);
    assert.strictEqual(r.status, 404);
    r = await fetch(`${base}/tmx/api/users`);
    assert.strictEqual(r.status, 404);
    r = await fetch(`${base}/tmx/api/tracks`, { method: 'POST', body: '{}' });
    assert.strictEqual(r.status, 404);
  } finally {
    await new Promise((r) => app.close(r));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('community: an upstream page (not JSON, an image or a file) is not passed', async () => {
  const c = new Community({ fetch: async () => ({ ok: true, status: 200, headers: new Map([['content-type', 'text/html']]),
    arrayBuffer: async () => new ArrayBuffer(4) }) });
  const out = { headers: null, code: 0, body: '' };
  const res = { headersSent: false, writeHead(code, h) { out.code = code; out.headers = h; this.headersSent = true; }, end(b) { out.body = String(b); } };
  assert.strictEqual(c.handle({ method: 'GET', url: '/api/community/tmx/api/tracks' }, res), true);
  await new Promise((r) => setTimeout(r, 20));
  assert.strictEqual(out.code, 502);
  assert.match(out.body, /unexpected text\/html/);
  assert.strictEqual(typeof fixtureFetch, 'function');
});
