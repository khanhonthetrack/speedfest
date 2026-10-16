'use strict';
const test = require('node:test');
const assert = require('node:assert');
const WebSocket = require('ws');
const { createServer, VERSION } = require('../server');

function client(port) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`);
  const inbox = [];
  ws.on('message', (d) => inbox.push(JSON.parse(d.toString())));
  // the next message of a type (polled every 20 ms)
  const next = (type, timeout = 3000) => new Promise((resolve, reject) => {
    const t0 = Date.now();
    const look = () => {
      const i = inbox.findIndex((m) => m.t === type);
      if (i >= 0) return resolve(inbox.splice(i, 1)[0]);
      if (Date.now() - t0 > timeout) return reject(new Error('timeout waiting for ' + type));
      setTimeout(look, 20);
    };
    look();
  });
  return { ws, next, open: new Promise((r) => ws.on('open', r)) };
}

test('two players: welcome, relay, finish ranking, round change, results', async () => {
  const srv = createServer({ roundMs: 1500, resultsMs: 500 });
  await new Promise((r) => srv.listen(0, r));
  try {
  const port = srv.httpServer.address().port;
  const a = client(port);
  const b = client(port);
  await a.open; await b.open;
  a.ws.send(JSON.stringify({ t: 'hello', name: 'Alice', version: VERSION }));
  const wa = await a.next('welcome');
  b.ws.send(JSON.stringify({ t: 'hello', name: 'Bob\u0000‮', version: VERSION }));
  const wb = await b.next('welcome');
  assert.strictEqual(wa.round.track, wb.round.track);
  a.ws.send(JSON.stringify({ t: 'state', p: [1, 2, 3], q: [0, 0, 0, 1], v: 50, s: 0.5 }));
  let st;
  do { st = await b.next('states'); } while (!st.s[wa.id]);
  assert.deepStrictEqual(st.s[wa.id].slice(0, 3), [1, 2, 3]);
  b.ws.send(JSON.stringify({ t: 'finish', round: wb.round.id, track: wb.round.track, time: 25000 }));
  let pl;
  do { pl = await a.next('players'); } while (!pl.players.some((p) => p.best === 25000));
  assert.ok(pl.players.some((p) => p.name === 'Bob' && p.best === 25000));
  const res = await a.next('results', 4000);
  assert.strictEqual(res.ranking[0].time, 25000);
  let rd;
  do { rd = await a.next('round', 4000); } while (rd.round.state !== 'race');
  assert.ok(rd.round.id > wa.round.id);
  const status = await (await fetch(`http://127.0.0.1:${port}/`)).json();
  assert.strictEqual(status.players, 2);
  a.ws.close(); b.ws.close();
  } finally {
    await new Promise((r) => srv.close(r));
  }
});

test('wrong version is refused', async () => {
  const srv = createServer({});
  await new Promise((r) => srv.listen(0, r));
  const c = client(srv.httpServer.address().port);
  await c.open;
  c.ws.send(JSON.stringify({ t: 'hello', name: 'x', version: 999 }));
  try {
    const e = await c.next('error');
    assert.match(e.msg, /version/);
  } finally {
    await new Promise((r) => srv.close(r));
  }
});
