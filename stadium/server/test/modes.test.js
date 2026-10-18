'use strict';
const test = require('node:test');
const assert = require('node:assert');
const WebSocket = require('ws');
const { makeMode, ROUND_POINTS } = require('../lib/modes');
const { createApp, VERSION } = require('../server');

const TRACKS = ['SF01', 'SF02', 'SF03', 'SF04'];

test('Rounds: a synchronized start, one finish each, points by place, the map ends at the limit', () => {
  const m = makeMode('Rounds', { tracks: TRACKS, random: () => 0, pointsLimit: 16, startDelay: 3000, finishTimeout: 10000 });
  m.join(1, 'Ann', 'ann'); m.join(2, 'Ben', 'ben'); m.join(3, 'Cat', '');
  let r = m.begin(1000);
  assert.strictEqual(r.start, 4000);
  assert.strictEqual(r.synced, true);
  assert.ok(m.finish(2, r.id, r.track, 30000));
  assert.ok(!m.finish(2, r.id, r.track, 29000));          // one finish each
  assert.ok(!m.finish(1, r.id, 'SF09', 25000));            // another track
  m.join(4, 'Late', '');                                   // joins mid-round: waits for the next
  assert.ok(!m.finish(4, r.id, r.track, 20000));
  assert.ok(m.finish(1, r.id, r.track, 25000));
  assert.strictEqual(m.tick(5000), null);                   // Cat still racing
  assert.ok(m.finish(3, r.id, r.track, 40000));
  assert.strictEqual(m.tick(5100), 'results');              // all in
  assert.deepStrictEqual(m.lastRound.map((x) => [x.id, x.points]), [[1, ROUND_POINTS[0]], [2, ROUND_POINTS[1]], [3, ROUND_POINTS[2]]]);
  assert.strictEqual(m.info().map_over, false);
  assert.strictEqual(m.ranked(), null);                     // the ladder counts the map, not a round
  assert.strictEqual(m.tick(20000), 'race');                // the next round, same map
  r = m.info();
  assert.strictEqual(r.number, 2);
  assert.ok(m.finish(1, r.id, r.track, 26000));
  assert.strictEqual(m.tick(r.start + 1000), null);
  assert.strictEqual(m.tick(r.start + 1000 + 10001), 'results');   // finish timeout after the first
  assert.strictEqual(m.points.get(1), 20);
  assert.strictEqual(m.info().map_over, true);              // 20 >= 16
  assert.deepStrictEqual(m.ranked(), [{ login: 'ann', time: 1 }, { login: 'ben', time: 2 }]);
  assert.strictEqual(m.tick(r.start + 60000), 'race');
  assert.strictEqual(m.info().map, 2);
  assert.strictEqual(m.points.size, 0);
});

test('Team: balanced teams, the round to the team with more, points to the limit', () => {
  const m = makeMode('Team', { tracks: TRACKS, random: () => 0, pointsLimit: 2, startDelay: 0, finishTimeout: 5000 });
  for (const [id, n] of [[1, 'a'], [2, 'b'], [3, 'c'], [4, 'd']]) m.join(id, n, n);
  assert.deepStrictEqual([1, 2, 3, 4].map((id) => m.teamOf(id)), [0, 1, 0, 1]);
  let r = m.begin(0);
  // blue 1st and 2nd: 4 + 3 = 7 against red 2 + 1 = 3
  m.finish(1, r.id, r.track, 20000); m.finish(3, r.id, r.track, 21000); m.finish(2, r.id, r.track, 22000); m.finish(4, r.id, r.track, 23000);
  assert.strictEqual(m.tick(100), 'results');
  assert.deepStrictEqual(m.lastTeams, [7, 3]);
  assert.deepStrictEqual(m.teamPoints, [1, 0]);
  m.tick(10000);
  r = m.info();
  m.finish(3, r.id, r.track, 20000); m.finish(1, r.id, r.track, 21000);
  m.tick(r.start + 100);
  assert.strictEqual(m.tick(r.start + 6000), 'results');
  assert.deepStrictEqual(m.teamPoints, [2, 0]);
  assert.strictEqual(m.info().map_over, true);
  const ranked = m.ranked();
  assert.deepStrictEqual(ranked.slice(0, 2).map((x) => x.login).sort(), ['a', 'c']);   // the winning team first
});

test('Laps: one race per map, ranked by the finish', () => {
  const m = makeMode('Laps', { tracks: TRACKS, random: () => 0, startDelay: 0 });
  m.join(1, 'a', 'a'); m.join(2, 'b', 'b');
  const r = m.begin(0);
  m.finish(2, r.id, r.track, 90000); m.finish(1, r.id, r.track, 95000);
  assert.strictEqual(m.tick(10), 'results');
  assert.strictEqual(m.info().map_over, true);
  assert.deepStrictEqual(m.ranked(), [{ login: 'b', time: 90000 }, { login: 'a', time: 95000 }]);
  assert.strictEqual(m.tick(100000), 'race');
  assert.strictEqual(m.info().map, 2);
});

test('TimeAttack: next and restart', () => {
  const m = makeMode('TimeAttack', { tracks: TRACKS, random: () => 0.5, roundMs: 60000 });
  const r = m.begin(0);
  m.restart(1000);
  assert.strictEqual(m.info().track, r.track);
  assert.ok(m.info().id > r.id);
  m.skip(2000);
  assert.notStrictEqual(m.info().track, r.track);
});

function client(port, path) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}${path}`);
  const inbox = [];
  ws.on('message', (d) => inbox.push(JSON.parse(d.toString())));
  const next = (type, pred = () => true, timeout = 4000) => new Promise((resolve, reject) => {
    const t0 = Date.now();
    const look = () => {
      const i = inbox.findIndex((m) => m.t === type && pred(m));
      if (i >= 0) return resolve(inbox.splice(i, 1)[0]);
      if (Date.now() - t0 > timeout) return reject(new Error(`timeout waiting for ${type}`));
      setTimeout(look, 20);
    };
    look();
  });
  return { ws, next, inbox, open: new Promise((r) => ws.on('open', r)), send: (m) => ws.send(JSON.stringify(m)) };
}

test('a room: accounts by token, spectators, votes, ranked results and records', async () => {
  const app = createApp({ servers: [{ id: 'rounds', name: 'R', mode: 'Rounds', tracks: TRACKS.join(',') }, { id: 'ta', name: 'T', mode: 'TimeAttack' }] });
  await new Promise((r) => app.listen(0, r, '127.0.0.1'));
  const port = app.httpServer.address().port;
  try {
    const reg = async (login) => (await (await fetch(`http://127.0.0.1:${port}/api/register`, { method: 'POST',
      body: JSON.stringify({ login, password: 'password1', nickname: `$f00${login}` }) })).json()).token;
    const ta = await reg('ann');
    const tb = await reg('ben');
    const list = await (await fetch(`http://127.0.0.1:${port}/api/servers`, { headers: { host: 'example.org' } })).json();
    assert.deepStrictEqual(list.servers.map((s) => [s.id, s.mode]), [['rounds', 'Rounds'], ['ta', 'TimeAttack']]);
    assert.match(list.servers[0].address, /^http:\/\/.+\/ws\/rounds$/);
    const status = await (await fetch(`http://127.0.0.1:${port}/ws/ta/status`)).json();
    assert.strictEqual(status.mode, 'TimeAttack');
    const a = client(port, '/ws/rounds');
    const b = client(port, '/ws/rounds');
    const s = client(port, '/ws/rounds');
    await Promise.all([a.open, b.open, s.open]);
    a.send({ t: 'hello', name: 'whatever', version: VERSION, token: ta });
    const wa = await a.next('welcome');
    assert.strictEqual(wa.mode, 'Rounds');
    assert.strictEqual(wa.login, 'ann');
    b.send({ t: 'hello', name: 'B', version: VERSION, token: tb });
    const wb = await b.next('welcome');
    s.send({ t: 'hello', name: 'Spec', version: VERSION, spectator: true });
    await s.next('welcome');
    let pl = await a.next('players', (m) => m.players.length === 3);
    assert.deepStrictEqual(pl.players.map((p) => [p.name, p.spectator]), [['$f00ann', false], ['$f00ben', false], ['Spec', true]]);
    // a vote needs more than half of the racers (2 of 2): the spectator can't vote
    s.send({ t: 'callvote', kind: 'restart' });
    a.send({ t: 'callvote', kind: 'restart' });
    let v = await b.next('vote', (m) => m.vote);
    assert.deepStrictEqual([v.vote.kind, v.vote.yes, v.vote.needed], ['restart', 1, 2]);
    b.send({ t: 'vote', yes: true });
    v = await a.next('vote', (m) => m.vote === null);
    assert.strictEqual(v.passed, true);
    const rd = await a.next('round', (m) => m.round.id > wa.round.id);
    assert.strictEqual(rd.round.track, wa.round.track);
    // both finish the restarted round: results, and on the map's end the ladder; the records
    const round = rd.round;
    a.send({ t: 'finish', round: round.id, track: round.track, time: 30000, uid: 'SF-test-1' });
    b.send({ t: 'finish', round: round.id, track: round.track, time: 31000, uid: 'SF-test-1' });
    const res = await a.next('results', () => true, 8000);
    assert.deepStrictEqual(res.last_round.map((x) => x.points), [10, 6]);
    assert.strictEqual(app.master.records.top('SF-test-1')[0].login, 'ann');
    // skipping the map ends it: Rounds' ladder counts the map's points
    app.games.get('rounds').mode.pointsLimit = 1;
    a.send({ t: 'chat', text: 'gg' });
    await b.next('chat', (m) => m.text === 'gg');
    a.ws.close(); b.ws.close(); s.ws.close();
    await wb;
  } finally {
    await new Promise((r) => app.close(r));
  }
});

test('ladder points move after a ranked map', async () => {
  const app = createApp({ servers: [{ id: 'laps', mode: 'Laps', tracks: TRACKS.join(',') }] });
  await new Promise((r) => app.listen(0, r, '127.0.0.1'));
  const port = app.httpServer.address().port;
  try {
    const game = app.games.get('laps');
    game.mode.startDelay = 0;
    const reg = async (login) => (await (await fetch(`http://127.0.0.1:${port}/api/register`, { method: 'POST',
      body: JSON.stringify({ login, password: 'password1' }) })).json()).token;
    const a = client(port, '/ws/laps');
    const b = client(port, '/ws/laps');
    await Promise.all([a.open, b.open]);
    a.send({ t: 'hello', version: VERSION, token: await reg('fast') });
    b.send({ t: 'hello', version: VERSION, token: await reg('slow') });
    await a.next('welcome'); await b.next('welcome');
    game.mode.restart(Date.now());   // a fresh race with both in it
    const r = game.mode.info();
    a.send({ t: 'finish', round: r.id, track: r.track, time: 60000 });
    b.send({ t: 'finish', round: r.id, track: r.track, time: 61000 });
    const lad = await a.next('ladder', () => true, 6000);
    assert.strictEqual(lad.deltas.length, 2);
    assert.ok(app.master.accounts.table.fast.ladder > 1000 && app.master.accounts.table.slow.ladder < 1000);
    a.ws.close(); b.ws.close();
  } finally {
    await new Promise((r) => app.close(r));
  }
});
