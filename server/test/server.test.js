'use strict';
// End-to-end tests: real server on an ephemeral port, several real WebSocket clients.
// Run: cd server && npm test

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');
const crypto = require('node:crypto');
const { createServer } = require('../server');
const { TestClient, request, sleep } = require('./helpers');

const COUNTDOWN_MS = 300;
const GRACE_MS = 300;
const RESULTS_MS = 900;

function makePublicDir() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'speedfest-public-'));
  fs.writeFileSync(path.join(dir, 'index.html'), '<!doctype html><title>SpeedFest</title>' + '<p>hello</p>'.repeat(200));
  // compressible pseudo-wasm: repeated random blocks
  const block = crypto.randomBytes(4096);
  fs.writeFileSync(path.join(dir, 'index.wasm'), Buffer.concat(Array.from({ length: 64 }, () => block)));
  fs.writeFileSync(path.join(dir, 'index.pck'), Buffer.concat(Array.from({ length: 16 }, () => block)));
  fs.writeFileSync(path.join(dir, 'index.js'), 'console.log("engine");\n'.repeat(500));
  fs.writeFileSync(path.join(dir, 'index.png'), crypto.randomBytes(2000));
  fs.writeFileSync(path.join(dir, 'index.icon.svg'), '<svg xmlns="http://www.w3.org/2000/svg"></svg>');
  fs.writeFileSync(path.join(dir, 'favicon.ico'), crypto.randomBytes(300));
  fs.writeFileSync(path.join(dir, 'data.json'), JSON.stringify({ a: 1 }));
  fs.writeFileSync(path.join(dir, '.secret'), 'nope');
  return dir;
}

describe('speedfest server', () => {
  let srv;
  let port;
  let url;
  let publicDir;
  const open = [];
  const client = async (name) => {
    const c = await TestClient.open(url);
    open.push(c);
    if (name) await c.hello(name);
    return c;
  };

  before(async () => {
    publicDir = makePublicDir();
    srv = createServer({
      port: 0,
      host: '127.0.0.1',
      publicDir,
      countdownMs: COUNTDOWN_MS,
      resultsMs: RESULTS_MS,
      finishGraceMs: GRACE_MS,
      heartbeatMs: 150,
      helloTimeoutMs: 5000,
      quiet: true,
      warm: true,
    });
    port = await srv.start();
    url = `ws://127.0.0.1:${port}/ws`;
    await srv.files.warm();
  });

  after(async () => {
    for (const c of open) c.ws.terminate();
    await srv.close();
    fs.rmSync(publicDir, { recursive: true, force: true });
  });

  test('hello -> welcome, ping -> pong, hello required', async () => {
    const c = await client();
    c.send({ type: 'list_rooms' });
    const err = await c.next('error');
    assert.equal(err.code, 'no_hello');
    const t0 = Date.now();
    const w = await c.hello('Alice');
    assert.ok(Number.isInteger(w.id) && w.id > 0);
    assert.equal(w.version, 1);
    assert.ok(Math.abs(w.server_t - t0) < 1000);
    const p = await c.ping();
    assert.ok(typeof p.server_t === 'number');
    c.send({ type: 'ping', t: 'nope' });
    const p2 = await c.next('pong');
    assert.equal(p2.t, 0);
    await c.close();
  });

  test('full room + round flow with 3 clients', async () => {
    const A = await client('Alice');
    const B = await client('Bob');
    const C = await client('Carol');

    // --- create / list / join ------------------------------------------------------------------
    A.send({ type: 'create_room', name: 'Game Night' });
    let room = await A.room();
    assert.match(room.code, /^[ABCDEFGHJKMNPQRSTUVWXYZ]{4}$/);
    assert.equal(room.host, A.id);
    assert.equal(room.name, 'Game Night');
    assert.equal(room.phase, 'lobby');
    assert.equal(room.players.length, 1);
    const code = room.code;

    B.send({ type: 'list_rooms' });
    const list = await B.next('rooms');
    const entry = list.rooms.find((r) => r.code === code);
    assert.ok(entry, 'room listed');
    assert.equal(entry.players, 1);
    assert.equal(entry.phase, 'lobby');
    assert.equal(entry.name, 'Game Night');
    assert.equal(typeof entry.track, 'string');

    B.send({ type: 'join_room', code: 'IIII' });
    assert.equal((await B.next('error')).code, 'no_such_room');
    B.send({ type: 'join_room', code: 42 });
    assert.equal((await B.next('error')).code, 'bad_code');

    B.send({ type: 'join_room', code });
    room = await B.room((r) => r.players.length === 2);
    assert.equal(room.code, code);
    await A.room((r) => r.players.length === 2);
    C.send({ type: 'join_room', code: code.toLowerCase() });
    await C.room((r) => r.players.length === 3);
    await A.room((r) => r.players.length === 3);
    await B.room((r) => r.players.length === 3);

    // --- profile / ready / settings ------------------------------------------------------------
    B.send({ type: 'profile', name: 'Bobby-The-Very-Long-Name-Racer', car: { car: 'brute', tuning: {}, style: { paint: '#ff0000' } } });
    room = await A.room((r) => r.players.some((p) => p.id === B.id && p.car.car === 'brute'));
    const bp = room.players.find((p) => p.id === B.id);
    assert.equal(bp.name.length, 16, 'name capped to 16 chars');
    assert.equal(bp.car.style.paint, '#ff0000');
    B.send({ type: 'profile', car: { car: 'kaze', junk: 'x'.repeat(3000) } });
    assert.equal((await B.next('error')).code, 'bad_car');

    C.send({ type: 'ready', ready: true });
    await A.room((r) => r.players.find((p) => p.id === C.id).ready === true);
    C.send({ type: 'ready', ready: 'yes' });
    assert.equal((await C.next('error')).code, 'bad_value');

    // host-only enforcement
    B.send({ type: 'settings', track: 'coast', duration_s: 2 });
    assert.equal((await B.next('error')).code, 'not_host');
    B.send({ type: 'start' });
    assert.equal((await B.next('error')).code, 'not_host');
    A.send({ type: 'settings', track: '../../etc', duration_s: 2 });
    assert.equal((await A.next('error')).code, 'bad_value');
    A.send({ type: 'settings', track: 'coast', duration_s: 2 });
    room = await C.room((r) => r.settings.track === 'coast');
    assert.equal(room.settings.duration_s, 2);
    assert.equal(room.settings.weather, 'dry', 'weather defaults to dry');
    A.send({ type: 'settings', weather: 'monsoon' });
    assert.equal((await A.next('error')).code, 'bad_value');
    A.send({ type: 'settings', weather: 'Storm' });
    room = await C.room((r) => r.settings.weather === 'storm');
    assert.equal(room.settings.track, 'coast', 'weather change keeps the track');
    A.send({ type: 'settings', weather: 'rain' });
    room = await C.room((r) => r.settings.weather === 'rain');

    // chat
    B.send({ type: 'chat', text: '  gl\u0000 hf  ' + 'x'.repeat(400) });
    const chatA = await A.next('chat');
    assert.equal(chatA.id, B.id);
    assert.ok(chatA.text.startsWith('gl hf'));
    assert.ok(chatA.text.length <= 200);
    await B.next('chat'); // sender also sees it (for the log)

    // --- round ------------------------------------------------------------------------------------
    A.drain();
    B.drain();
    C.drain();
    A.send({ type: 'start' });
    const starts = await Promise.all([A, B, C].map((c) => c.next('round_start')));
    for (const st of starts) assert.equal(st.weather, 'rain', 'round_start carries the weather');
    for (const s of starts) {
      assert.equal(s.round_id, starts[0].round_id);
      assert.equal(s.track, 'coast');
      assert.equal(s.duration_s, 2);
      assert.equal(s.end_at - s.start_at, 2000);
      const lead = s.start_at - s.server_t;
      assert.ok(lead > COUNTDOWN_MS - 100 && lead <= COUNTDOWN_MS, `countdown lead ${lead}`);
    }
    const roundId = starts[0].round_id;
    const startAt = starts[0].start_at;
    room = await A.room((r) => r.phase === 'countdown');
    assert.equal(room.round.round_id, roundId);
    A.send({ type: 'start' });
    assert.equal((await A.next('error')).code, 'bad_phase');

    // finishing during the countdown is impossible
    B.send({ type: 'finish', round_id: roundId, ms: 500 });
    assert.equal((await B.next('finish_ack')).ok, false);

    room = await A.room((r) => r.phase === 'racing', 2000);
    assert.ok(Date.now() >= startAt - 50, 'racing phase begins at start_at');

    // state relay: to the others, never echoed
    const snap = { type: 'state', t: 1234, p: [1, 2, 3], q: [0, 0, 0, 1], v: [0, 0, -30], st: 0.2, rpm: 0.7, fl: 16 };
    A.send(snap);
    const sb = await B.next('state');
    const sc = await C.next('state');
    for (const s of [sb, sc]) {
      assert.equal(s.id, A.id);
      assert.deepEqual(s.p, [1, 2, 3]);
      assert.equal(s.t, 1234);
      assert.equal(s.fl, 16);
    }
    A.send({ type: 'state', p: ['x', 2, 3] }); // invalid: dropped
    A.send({ type: 'state', t: 5, q: [0, 0, 0, 1] }); // no position: dropped
    await sleep(80);
    assert.equal(A.count('state'), 0, 'state is not echoed to the sender');
    assert.equal(B.count('state'), 1, 'invalid states are not relayed');

    // checkpoint relay
    B.send({ type: 'cp', round_id: roundId, cp: 0, ms: 400 });
    const cpA = await A.next('cp');
    assert.deepEqual([cpA.id, cpA.cp, cpA.ms], [B.id, 0, 400]);
    await C.next('cp');
    B.send({ type: 'cp', round_id: roundId + 7, cp: 1, ms: 500 }); // stale: dropped
    await sleep(50);
    assert.equal(A.count('cp'), 1);

    // finishes -> leaderboard
    B.send({ type: 'finish', round_id: roundId, ms: 800 });
    const ackB = await B.next('finish_ack');
    assert.equal(ackB.ok, true);
    assert.equal(ackB.best_ms, 800);
    let lb = await A.next('leaderboard');
    assert.equal(lb.entries[0].id, B.id);
    C.send({ type: 'finish', round_id: roundId, ms: 600 });
    assert.equal((await C.next('finish_ack')).ok, true);
    lb = await A.next('leaderboard', (m) => m.entries[0].id === C.id);
    assert.deepEqual(lb.entries.map((e) => e.id), [C.id, B.id, A.id]);
    assert.equal(lb.entries[2].best_ms, -1, 'no finish = DNF last');
    assert.equal(lb.entries[1].car, 'brute', 'entries carry the car id');
    assert.equal(lb.entries[0].car, '', 'no profile sent = empty car id');
    // slower run counts as a run but keeps the best
    B.send({ type: 'finish', round_id: roundId, ms: 900 });
    const ackB2 = await B.next('finish_ack');
    assert.equal(ackB2.ok, true);
    assert.equal(ackB2.best_ms, 800);
    assert.equal(ackB2.runs, 2);

    // stale / bogus finishes are rejected
    C.send({ type: 'finish', round_id: roundId - 1, ms: 100 });
    assert.equal((await C.next('finish_ack')).reason, 'stale_round');
    C.send({ type: 'finish', round_id: roundId, ms: 'fast' });
    assert.equal((await C.next('finish_ack')).reason, 'invalid_time');
    C.send({ type: 'finish', round_id: roundId, ms: 3000000 });
    assert.equal((await C.next('finish_ack')).reason, 'impossible_time');

    // state rate limit: a burst of 100 is cut down
    B.drain();
    for (let i = 0; i < 100; i++) A.send({ ...snap, t: i });
    await sleep(120);
    const relayed = B.count('state');
    assert.ok(relayed >= 5 && relayed <= 20, `burst relayed ${relayed}`);

    // late joiner gets round_start immediately (+ the live leaderboard)
    const D = await client('Dave');
    D.send({ type: 'join_room', code });
    const lateRoom = await D.room();
    assert.equal(lateRoom.phase, 'racing');
    const lateStart = await D.next('round_start');
    assert.equal(lateStart.round_id, roundId);
    assert.equal(lateStart.start_at, startAt);
    const lateLb = await D.next('leaderboard');
    assert.equal(lateLb.entries[0].id, C.id);

    // round end: phase results, then round_end after the finish grace, then lobby
    await A.room((r) => r.phase === 'results', 4000);
    // a finish in flight inside the grace window still counts
    A.send({ type: 'finish', round_id: roundId, ms: 1900 });
    const ackA = await A.next('finish_ack');
    assert.equal(ackA.ok, true, `grace finish accepted (${ackA.reason})`);
    const ends = await Promise.all([A, B, C, D].map((c) => c.next('round_end', () => true, 3000)));
    const results = ends[0].results;
    assert.deepEqual(results.map((r) => r.id), [C.id, B.id, A.id, D.id]);
    assert.deepEqual(results.map((r) => r.best_ms), [600, 800, 1900, -1]);
    assert.equal(results[1].runs, 2);
    for (const r of results) assert.deepEqual(Object.keys(r).sort(), ['best_ms', 'car', 'id', 'name', 'runs']);
    const endedAt = Date.now();
    // finishes after the round are rejected
    B.send({ type: 'finish', round_id: roundId, ms: 100 });
    assert.equal((await B.next('finish_ack')).ok, false);

    room = await A.room((r) => r.phase === 'lobby', 3000);
    assert.ok(Date.now() - endedAt < RESULTS_MS + 200);
    assert.ok(room.players.every((p) => p.ready === false), 'ready resets after a round');

    // --- host migration + room deletion --------------------------------------------------------
    A.send({ type: 'leave_room' });
    const left = await A.next('room', (m) => m.room === null);
    assert.equal(left.room, null);
    const leftMsg = await B.next('left');
    assert.equal(leftMsg.id, A.id);
    room = await B.room((r) => r.players.length === 3);
    assert.equal(room.host, B.id, 'host passes to the next player');
    await B.close();
    room = await C.room((r) => r.players.length === 2);
    assert.equal(room.host, C.id);
    await C.close();
    await D.close();
    await sleep(50);
    A.send({ type: 'list_rooms' });
    const after = await A.next('rooms');
    assert.ok(!after.rooms.some((r) => r.code === code), 'empty room is deleted');
    await A.close();
  });

  test('player who drops mid-round keeps their time when rejoining', async () => {
    const A = await client('Host');
    const B = await client('Flaky');
    A.send({ type: 'create_room' });
    const { code } = await A.room();
    B.send({ type: 'join_room', code });
    await A.room((r) => r.players.length === 2);
    A.send({ type: 'settings', duration_s: 3 });
    await A.room((r) => r.settings.duration_s === 3);
    A.send({ type: 'start' });
    const s = await B.next('round_start');
    await B.room((r) => r.phase === 'racing', 2000);
    B.send({ type: 'finish', round_id: s.round_id, ms: 300 });
    assert.equal((await B.next('finish_ack')).ok, true);
    B.ws.terminate();
    await A.next('left');
    const B2 = await client('Flaky');
    B2.send({ type: 'join_room', code });
    const r2 = await B2.room();
    assert.equal(r2.players.find((p) => p.id === B2.id).best_ms, 300);
    await B2.next('round_start');
    await A.close();
    await B2.close();
  });

  test('rejoining before the old socket is reaped merges times into the live player', async () => {
    const A = await client('Host2');
    const B = await client('Reloader');
    A.send({ type: 'create_room' });
    const { code } = await A.room();
    B.send({ type: 'join_room', code });
    await A.room((r) => r.players.length === 2);
    A.send({ type: 'settings', duration_s: 3 });
    await A.room((r) => r.settings.duration_s === 3);
    A.send({ type: 'start' });
    const s = await B.next('round_start');
    await B.room((r) => r.phase === 'racing', 2000);
    B.send({ type: 'finish', round_id: s.round_id, ms: 300 });
    assert.equal((await B.next('finish_ack')).ok, true);
    // Page reload: a new socket with the same name joins while the old one is still connected.
    const B2 = await client('Reloader');
    B2.send({ type: 'join_room', code });
    await B2.room((r) => r.players.some((p) => p.id === B2.id));
    await B2.next('round_start');
    B2.send({ type: 'finish', round_id: s.round_id, ms: 500 });
    assert.equal((await B2.next('finish_ack')).ok, true);
    B.ws.terminate();
    await A.next('left', (m) => m.id === B.id);
    // The leaderboard sent when the old socket leaves has a single merged entry: best 300 over 2 runs.
    const lb = await A.next('leaderboard', (m) => m.entries.some((e) => e.name === 'Reloader' && e.runs === 2));
    const rows = lb.entries.filter((x) => x.name === 'Reloader');
    assert.equal(rows.length, 1);
    assert.equal(rows[0].best_ms, 300);
    assert.equal(rows[0].id, B2.id);
    await A.close();
    await B2.close();
  });

  test('state is not relayed to a client that went silent (hidden web tab)', async () => {
    const A = await client('Sender');
    const B = await client('Sleeper');
    A.send({ type: 'create_room' });
    const { code } = await A.room();
    B.send({ type: 'join_room', code });
    await A.room((r) => r.players.length === 2);
    const snap = { type: 'state', t: 1, p: [1, 2, 3], q: [0, 0, 0, 1], v: [0, 0, -30], st: 0, rpm: 0.5, fl: 16 };
    // Simulate a paused tab: B has sent nothing for 10 s.
    srv.lobby.clients.get(B.id).lastRx -= 10000;
    B.drain();
    A.send(snap);
    A.send({ type: 'chat', text: 'still there?' });
    await B.next('chat'); // reliable messages still arrive
    assert.equal(B.count('state'), 0);
    await B.ping(); // the tab is visible again
    A.send({ ...snap, t: 2 });
    const st = await B.next('state');
    assert.equal(st.id, A.id);
    await A.close();
    await B.close();
  });

  test('bad input is ignored without disconnecting anyone', async () => {
    const E = await client('Evil');
    const F = await client('Fine');
    F.send({ type: 'create_room' });
    const { code } = await F.room();
    E.send({ type: 'join_room', code });
    await F.room((r) => r.players.length === 2);

    E.send('this is not json');
    assert.equal((await E.next('error')).code, 'bad_json');
    E.send(JSON.stringify({ type: 'chat', text: 'x'.repeat(20 * 1024) }));
    assert.equal((await E.next('error')).code, 'too_large');
    E.ws.send(Buffer.from([1, 2, 3]), { binary: true });
    assert.equal((await E.next('error')).code, 'bad_frame');
    E.send('[1,2,3]');
    assert.equal((await E.next('error')).code, 'bad_message');
    E.send({ type: '__proto__' });
    assert.equal((await E.next('error')).code, 'unknown_type');
    E.send({ type: 'constructor' });
    assert.equal((await E.next('error')).code, 'unknown_type');

    // fuzz: random types with random garbage values must never crash the server
    const types = ['hello', 'ping', 'list_rooms', 'create_room', 'join_room', 'leave_room', 'profile', 'ready',
      'settings', 'start', 'state', 'cp', 'finish', 'chat'];
    const junk = [null, true, -1, 1e308, NaN, 'x', '', [], [1, 2], {}, { a: { b: [] } }, 'ABCD', 3.5, '‮'];
    const pick = (a) => a[Math.floor(Math.random() * a.length)];
    for (let i = 0; i < 300; i++) {
      const m = { type: pick(types) };
      for (const k of ['name', 'code', 'car', 'ready', 'track', 'duration_s', 'round_id', 'ms', 'cp', 'text', 't', 'p', 'q', 'v']) {
        if (Math.random() < 0.4) m[k] = pick(junk);
      }
      E.send(m);
    }
    await sleep(100);
    assert.equal(E.closed, false, 'fuzzing client still connected');
    assert.ok(await F.ping(), 'other client unaffected');
    assert.ok(await E.ping());

    // > 64 KB frames are cut off at the protocol level; only the offender is dropped
    E.send('x'.repeat(70 * 1024));
    await E.closedPromise;
    assert.ok(await F.ping(), 'other client still fine');
    await F.close();
  });

  test('heartbeat drops clients that stop answering pings', async () => {
    const c = await TestClient.open(url, { autoPong: false });
    open.push(c);
    await c.hello('Zombie');
    const t0 = Date.now();
    await c.closedPromise;
    const dt = Date.now() - t0;
    assert.ok(dt >= 250 && dt < 2000, `dropped after ${dt} ms`);
    const ok = await client('Alive');
    await sleep(600); // several heartbeat intervals: auto-pong keeps it alive
    assert.equal(ok.closed, false);
    await ok.close();
  });

  test('/health', async () => {
    const r = await request(port, '/health');
    assert.equal(r.status, 200);
    const j = JSON.parse(r.body.toString());
    assert.equal(j.ok, true);
    for (const k of ['rooms', 'players', 'uptime_s']) assert.equal(typeof j[k], 'number');
  });

  test('static files: MIME, COOP/COEP, compression, caching, traversal', async () => {
    const idx = await request(port, '/');
    assert.equal(idx.status, 200);
    assert.match(idx.headers['content-type'], /^text\/html/);
    assert.equal(idx.headers['cross-origin-opener-policy'], 'same-origin');
    assert.equal(idx.headers['cross-origin-embedder-policy'], 'require-corp');
    assert.equal(idx.headers['cache-control'], 'no-cache');
    assert.match(idx.body.toString(), /SpeedFest/);

    const mimes = {
      '/index.wasm': 'application/wasm',
      '/index.pck': 'application/octet-stream',
      '/index.js': 'text/javascript; charset=utf-8',
      '/index.png': 'image/png',
      '/index.icon.svg': 'image/svg+xml',
      '/favicon.ico': 'image/x-icon',
      '/data.json': 'application/json; charset=utf-8',
    };
    for (const [p, mime] of Object.entries(mimes)) {
      const r = await request(port, p);
      assert.equal(r.status, 200, p);
      assert.equal(r.headers['content-type'], mime, p);
      assert.equal(r.headers['cross-origin-embedder-policy'], 'require-corp', p);
    }

    const wasm = fs.readFileSync(path.join(publicDir, 'index.wasm'));
    const plain = await request(port, '/index.wasm');
    assert.equal(plain.headers['content-encoding'], undefined);
    assert.ok(plain.body.equals(wasm));
    const gz = await request(port, '/index.wasm', { headers: { 'Accept-Encoding': 'gzip, deflate' } });
    assert.equal(gz.headers['content-encoding'], 'gzip');
    assert.ok(gz.body.length < wasm.length / 4);
    assert.ok(zlib.gunzipSync(gz.body).equals(wasm));
    const br = await request(port, '/index.wasm', { headers: { 'Accept-Encoding': 'gzip, deflate, br' } });
    assert.equal(br.headers['content-encoding'], 'br');
    assert.ok(zlib.brotliDecompressSync(br.body).equals(wasm));
    const nobr = await request(port, '/index.wasm', { headers: { 'Accept-Encoding': 'br;q=0, gzip' } });
    assert.equal(nobr.headers['content-encoding'], 'gzip');
    const png = await request(port, '/index.png', { headers: { 'Accept-Encoding': 'gzip, br' } });
    assert.equal(png.headers['content-encoding'], undefined, 'images are not recompressed');
    assert.equal(br.headers.vary, 'Accept-Encoding');

    const again = await request(port, '/index.wasm', { headers: { 'If-None-Match': plain.headers.etag } });
    assert.equal(again.status, 304);
    const head = await request(port, '/index.pck', { method: 'HEAD' });
    assert.equal(head.status, 200);
    assert.equal(head.body.length, 0);
    assert.equal(Number(head.headers['content-length']), 16 * 4096);
    assert.equal((await request(port, '/index.html', { method: 'POST' })).status, 405);

    for (const p of ['/../server.js', '/..%2fserver.js', '/%2e%2e/%2e%2e/etc/passwd', '/.secret', '/a/../../x',
      '/%00', '/..\\server.js', '/%E0%A4%A']) {
      const r = await request(port, p);
      assert.ok(r.status === 404 || r.status === 400, `${p} -> ${r.status}`);
      assert.ok(!r.body.toString().includes('createServer'), `${p} leaked`);
    }
    assert.equal((await request(port, '/nope.js')).status, 404);
    assert.equal((await request(port, '/ws')).status, 426);
  });

  test('a re-exported file is picked up without a restart', async () => {
    const f = path.join(publicDir, 'index.js');
    fs.writeFileSync(f, 'console.log("v2");\n'.repeat(600));
    const future = new Date(Date.now() + 5000);
    fs.utimesSync(f, future, future);
    const r = await request(port, '/index.js', { headers: { 'Accept-Encoding': 'gzip' } });
    const body = r.headers['content-encoding'] === 'gzip' ? zlib.gunzipSync(r.body) : r.body;
    assert.match(body.toString(), /v2/);
  });

  test('websocket upgrade on other paths is refused', async () => {
    await assert.rejects(TestClient.open(`ws://127.0.0.1:${port}/other`));
  });
});

describe('missing web build', () => {
  test('serves a placeholder page', async () => {
    const srv = createServer({ port: 0, host: '127.0.0.1', publicDir: path.join(os.tmpdir(), 'speedfest-nope-' + Date.now()), quiet: true });
    const port = await srv.start();
    try {
      const r = await request(port, '/');
      assert.equal(r.status, 200);
      assert.match(r.body.toString(), /web build is missing/);
      assert.equal((await request(port, '/index.wasm')).status, 404);
      const h = JSON.parse((await request(port, '/health')).body.toString());
      assert.equal(h.ok, true);
      assert.equal(h.build, false);
    } finally {
      await srv.close();
    }
  });
});
