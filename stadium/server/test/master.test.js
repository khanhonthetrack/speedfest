'use strict';
const test = require('node:test');
const assert = require('node:assert');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { Store } = require('../lib/store');
const { Master } = require('../lib/master');
const { stripNick } = require('../lib/accounts');
const ladder = require('../lib/ladder');

async function start(store = new Store('')) {
  const master = new Master(store);
  const srv = http.createServer((req, res) => { if (!master.handle(req, res)) { res.writeHead(404); res.end(); } });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${srv.address().port}/api`;
  const call = async (method, p, body, token) => {
    const r = await fetch(base + p, { method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      body: body ? JSON.stringify(body) : undefined });
    return { code: r.status, body: await r.json() };
  };
  return { master, srv, call, close: () => new Promise((r) => srv.close(r)) };
}

test('register, log in, me, update, log out', async () => {
  const s = await start();
  try {
    let r = await s.call('POST', '/register', { login: 'Alice', password: 'secret-pass', nickname: '$f00Ali$fffce', zone: 'Europe|France' });
    assert.strictEqual(r.code, 200);
    assert.strictEqual(r.body.account.login, 'alice');
    assert.strictEqual(r.body.account.ladder, 1000);
    assert.strictEqual(r.body.token.length, 64);
    assert.ok(!JSON.stringify(s.master.store.data).includes('secret-pass'));
    assert.ok(!JSON.stringify(s.master.store.data).includes(r.body.token));
    r = await s.call('POST', '/register', { login: 'alice', password: 'another-pass' });
    assert.strictEqual(r.code, 400);
    assert.match(r.body.error, /taken/);
    r = await s.call('POST', '/register', { login: 'x', password: 'secret-pass' });
    assert.match(r.body.error, /login/);
    r = await s.call('POST', '/register', { login: 'bob', password: 'short' });
    assert.match(r.body.error, /password/);
    r = await s.call('POST', '/login', { login: 'alice', password: 'wrong-pass' });
    assert.strictEqual(r.code, 401);
    r = await s.call('POST', '/login', { login: 'ALICE', password: 'secret-pass' });
    assert.strictEqual(r.code, 200);
    const token = r.body.token;
    r = await s.call('GET', '/me', null, token);
    assert.strictEqual(r.body.account.nickname, '$f00Ali$fffce');
    assert.strictEqual(r.body.ranks.world, 1);
    r = await s.call('POST', '/me', { zone: 'Mars|Olympus' }, token);
    assert.strictEqual(r.code, 400);
    r = await s.call('POST', '/me', { nickname: '$o$i', zone: 'Europe' }, token);
    assert.strictEqual(r.code, 400);   // a nickname of codes only
    r = await s.call('POST', '/me', { nickname: '$0f0Alice', zone: 'Europe' }, token);
    assert.strictEqual(r.body.account.zone, 'Europe');
    await s.call('POST', '/logout', null, token);
    r = await s.call('GET', '/me', null, token);
    assert.strictEqual(r.code, 401);
  } finally { await s.close(); }
});

test('rate limit on logins', async () => {
  const s = await start();
  try {
    let last;
    for (let i = 0; i < 14; i++) last = await s.call('POST', '/login', { login: 'nobody', password: 'whatever-1' });
    assert.strictEqual(last.code, 429);
  } finally { await s.close(); }
});

test('ladder: winners gain from those behind, more against stronger players', () => {
  const acc = { a: { login: 'a', ladder: 1000 }, b: { login: 'b', ladder: 1000 }, c: { login: 'c', ladder: 1400 }, d: { login: 'd', ladder: 1000 } };
  const d = ladder.applyRound([{ login: 'b', time: 30000 }, { login: 'a', time: 25000 }, { login: 'c', time: 40000 }, { login: 'd', time: -1 }], acc);
  assert.ok(d.a > 0 && d.d < 0);
  assert.ok(d.a > d.b);
  assert.ok(Math.abs(d.a + d.b + d.c + d.d) < 0.5);       // points move, none appear
  assert.ok(d.c < 0);                                      // the strong player finished third
  assert.deepStrictEqual(ladder.applyRound([{ login: 'a', time: 1 }], acc), {});
  const r = ladder.ranking(acc);
  assert.strictEqual(r[0].login, 'c');
});

test('rankings by zone, records, the server list', async () => {
  const s = await start();
  try {
    const tok = {};
    for (const [login, zone] of [['ann', 'Europe|France'], ['ben', 'Europe|Germany'], ['cat', 'Asia|Japan']]) {
      tok[login] = (await s.call('POST', '/register', { login, password: 'password1', zone })).body.token;
    }
    const delta = s.master.rankedRound([{ login: 'cat', time: 20000 }, { login: 'ann', time: 21000 }, { login: 'ben', time: -1 }, { login: 'ghost', time: 1 }]);
    assert.ok(delta.cat > 0 && delta.ben < 0 && delta.ghost === undefined);
    let r = await s.call('GET', '/rankings?zone=Europe');
    assert.deepStrictEqual(r.body.players.map((p) => p.login), ['ann', 'ben']);
    assert.strictEqual(r.body.players[0].rank, 1);
    r = await s.call('GET', '/rankings');
    assert.strictEqual(r.body.players[0].login, 'cat');
    r = await s.call('GET', '/me', null, tok.ann);
    assert.deepStrictEqual([r.body.ranks.world, r.body.ranks.zone, r.body.ranks.continent], [2, 1, 1]);
    // records
    assert.strictEqual((await s.call('POST', '/records', { track: 'SF-SF01-abc', time: 50000 })).code, 401);
    assert.strictEqual((await s.call('POST', '/records', { track: 'SF-SF01-abc', time: 50000 }, tok.ann)).body.rank, 1);
    assert.strictEqual((await s.call('POST', '/records', { track: 'SF-SF01-abc', time: 48000 }, tok.cat)).body.rank, 1);
    r = await s.call('POST', '/records', { track: 'SF-SF01-abc', time: 52000 }, tok.ann);
    assert.deepStrictEqual([r.body.improved, r.body.time, r.body.rank], [false, 50000, 2]);
    assert.strictEqual((await s.call('POST', '/records', { track: 'bad track!', time: 5 }, tok.ann)).code, 400);
    assert.strictEqual((await s.call('POST', '/records', { track: 'SF-SF01-abc', time: -5 }, tok.ann)).code, 400);
    r = await s.call('GET', '/records?track=SF-SF01-abc&zone=Europe', null, tok.ann);
    assert.deepStrictEqual(r.body.top.map((x) => x.login), ['cat', 'ann']);
    assert.deepStrictEqual(r.body.zone_top.map((x) => x.login), ['ann']);
    assert.deepStrictEqual([r.body.mine.rank, r.body.mine.zone_rank], [2, 1]);
    // servers: official ones from this process, community ones by heartbeat
    s.master.addOfficial('ta', { listing: () => ({ name: 'Official TA', address: 'https://x/ws/ta', mode: 'TimeAttack', track: 'SF01', players: 3, max: 32 }) });
    assert.strictEqual((await s.call('POST', '/servers', { name: 'Mine', address: 'http://1.2.3.4:8090' })).code, 401);
    assert.strictEqual((await s.call('POST', '/servers', { name: 'Mine', address: 'nonsense' }, tok.ben)).code, 400);
    assert.strictEqual((await s.call('POST', '/servers', { name: 'Mine', address: 'http://1.2.3.4:8090', mode: 'Rounds' }, tok.ben)).code, 200);
    r = await s.call('GET', '/servers');
    assert.deepStrictEqual(r.body.servers.map((x) => [x.name, x.official, x.mode]), [['Official TA', true, 'TimeAttack'], ['Mine', false, 'Rounds']]);
  } finally { await s.close(); }
});

test('the store keeps everything in its file', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sf-master-'));
  const file = path.join(dir, 'master.json');
  const s = await start(new Store(file));
  try {
    await s.call('POST', '/register', { login: 'dan', password: 'password1', zone: 'Oceania|Australia' });
    s.master.store.flush();
  } finally { await s.close(); }
  const again = new Store(file);
  assert.strictEqual(again.table('accounts').dan.zone, 'Oceania|Australia');
  fs.rmSync(dir, { recursive: true });
});

test('nicknames without their codes', () => {
  assert.strictEqual(stripNick('$f00Red$zPlain$$'), 'RedPlain$');
  assert.strictEqual(stripNick('$l[http://x.y]link$l'), 'link');
  assert.strictEqual(stripNick('$o$i'), '');
});
