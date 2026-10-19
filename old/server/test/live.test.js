'use strict';
// The always-on LIVE room: rotation, drop-in rounds, no host, idle when empty.
// Run: cd server && npm test

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../server');
const { Rotation, PLAYLIST } = require('../lib/rotation');
const { TestClient } = require('./helpers');

/** Deterministic rng (mulberry32). */
function seeded(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

describe('rotation', () => {
  test('every track once per cycle, never twice in a row, valid weather', () => {
    const r = new Rotation({ rng: seeded(7) });
    const n = PLAYLIST.length;
    let prev = '';
    for (let cycle = 0; cycle < 20; cycle++) {
      const seen = new Set();
      for (let i = 0; i < n; i++) {
        const peeked = r.peek();
        const round = r.next();
        assert.deepEqual(round, peeked, 'peek() shows the next round');
        assert.notEqual(round.track, prev, 'no repeat');
        const e = PLAYLIST.find((x) => x.track === round.track);
        assert.ok(e.weathers.includes(round.weather));
        assert.equal(round.duration_s, e.duration_s);
        seen.add(round.track);
        prev = round.track;
      }
      assert.equal(seen.size, n, 'each track once per cycle');
    }
  });

  test('duration override', () => {
    const r = new Rotation({ durationS: 3 });
    assert.equal(r.next().duration_s, 3);
  });
});

describe('LIVE room', () => {
  let srv;
  let url;
  const open = [];
  const client = async (name) => {
    const c = await TestClient.open(url);
    open.push(c);
    await c.hello(name);
    return c;
  };

  before(async () => {
    srv = createServer({
      port: 0,
      host: '127.0.0.1',
      publicDir: '/nonexistent',
      countdownMs: 200,
      finishGraceMs: 150,
      liveResultsMs: 500,
      heartbeatMs: 1000,
      helloTimeoutMs: 5000,
      quiet: true,
      warm: false,
      rotation: new Rotation({ rng: seeded(42), durationS: 1 }),
    });
    const port = await srv.start();
    url = `ws://127.0.0.1:${port}/ws`;
  });

  after(async () => {
    for (const c of open) c.ws.terminate();
    await srv.close();
  });

  test('drop-in rounds that rotate by themselves', async () => {
    const a = await client('Alice');
    a.send({ type: 'list_rooms' });
    const listed = (await a.next('rooms')).rooms;
    assert.equal(listed[0].code, 'LIVE');
    assert.equal(listed[0].live, true);
    assert.equal(listed[0].players, 0);
    assert.equal(listed[0].phase, 'lobby');

    // Joining an idle LIVE room starts a round right away: no host, no ready-up.
    a.send({ type: 'join_room', code: 'live' });
    const r1 = await a.next('round_start');
    const room = await a.room((r) => r.phase === 'countdown');
    assert.equal(room.live, true);
    assert.equal(room.host, -1);
    assert.equal(room.max_players, 12);
    assert.ok(room.next && room.next.track, 'room shows the next track');
    assert.notEqual(room.next.track, r1.track);
    assert.equal(r1.duration_s, 1);

    // Host commands are refused.
    a.send({ type: 'settings', track: 'arena' });
    assert.equal((await a.next('error')).code, 'live_room');
    a.send({ type: 'start' });
    assert.equal((await a.next('error')).code, 'live_room');

    // A late joiner drops straight into the running round.
    await a.room((r) => r.phase === 'racing');
    const b = await client('Bob');
    b.send({ type: 'join_room', code: 'LIVE' });
    const rb = await b.next('round_start');
    assert.equal(rb.round_id, r1.round_id);
    assert.equal(rb.track, r1.track);

    a.send({ type: 'finish', round_id: r1.round_id, ms: 500 });
    assert.equal((await a.next('finish_ack')).ok, true);

    // Round over -> results -> the next track starts by itself (the one announced as next).
    const end = await a.next('round_end', () => true, 4000);
    assert.equal(end.results[0].name, 'Alice');
    const r2 = await a.next('round_start', () => true, 4000);
    assert.equal(r2.round_id, r1.round_id + 1);
    assert.equal(r2.track, room.next.track);
    assert.equal((await b.next('round_start', (m) => m.round_id === r2.round_id, 4000)).track, r2.track);

    // Everyone leaves: the room stays listed and goes idle.
    a.send({ type: 'leave_room' });
    b.send({ type: 'leave_room' });
    await a.next('room', (m) => m.room === null);
    await b.next('room', (m) => m.room === null);
    a.send({ type: 'list_rooms' });
    const after = (await a.next('rooms')).rooms.find((r) => r.code === 'LIVE');
    assert.equal(after.players, 0);
    assert.equal(after.phase, 'lobby');

    // Coming back starts the next round straight away.
    a.drain();
    a.send({ type: 'join_room', code: 'LIVE' });
    const r3 = await a.next('round_start');
    assert.ok(r3.round_id > r2.round_id);
  });

  test('private rooms still work next to LIVE', async () => {
    const c = await client('Cara');
    c.send({ type: 'create_room', name: 'Friends' });
    const room = await c.room((r) => r.code !== 'LIVE');
    assert.equal(room.live, false);
    assert.equal(room.next, null);
    assert.equal(room.host, c.id);
    assert.ok(!/[LI]/.test(room.code));
  });
});
