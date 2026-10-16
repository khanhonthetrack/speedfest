'use strict';
// SpeedFest Stadium online server: one always-on time-attack room like a TMNF server. Rounds of
// ROUND_MS on random campaign tracks (players load them from their own TMNF install), players'
// best times ranked live, their cars' positions relayed (10 per second) so everyone sees everyone,
// results between rounds, chat. WebSocket on /ws (JSON messages, see docs below); GET / gives the
// status as JSON for the game's server list.
//
// Client -> server: {t:'hello', name, version, colour}  {t:'state', p:[x,y,z], q:[x,y,z,w], v, s}
//                   {t:'finish', round, track, time}  {t:'chat', text}
// Server -> client: {t:'welcome', id, now, round, players}  {t:'round', now, round}
//                   {t:'players', players}  {t:'states', s:{id:[px,py,pz,qx,qy,qz,qw,v,s]}}
//                   {t:'results', ranking}  {t:'chat', from, text}  {t:'error', msg}
//
// Env: PORT (8090), ROUND_MS (300000), RESULTS_MS (15000), NAME ("SpeedFest Stadium"), MAX_PLAYERS (32);
// or arguments --port= --round-ms= --results-ms= --name= --max-players= (the game's tests use them).

const http = require('http');
const { WebSocketServer } = require('ws');
const { Rounds } = require('./lib/rounds');

const VERSION = 1;
const MAX_FRAME = 4096;
const STATE_HZ = 10;

function cleanText(v, max) {
  if (typeof v !== 'string') return '';
  const s = v.replace(/[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁠-⁩﻿]/g, '')
    .replace(/\s+/g, ' ').trim();
  return Array.from(s).slice(0, max).join('').trim();
}

function finiteArray(a, n, limit) {
  return Array.isArray(a) && a.length === n && a.every((x) => typeof x === 'number' && Number.isFinite(x) && Math.abs(x) < limit);
}

function createServer(opts = {}) {
  const name = opts.name || process.env.NAME || 'SpeedFest Stadium';
  const maxPlayers = Number(opts.maxPlayers || process.env.MAX_PLAYERS || 32);
  const rounds = new Rounds({
    roundMs: Number(opts.roundMs || process.env.ROUND_MS || 5 * 60 * 1000),
    resultsMs: Number(opts.resultsMs || process.env.RESULTS_MS || 15 * 1000),
  });
  const players = new Map();      // id -> {id, name, colour, ws, state, chatAt}
  let nextId = 1;

  const status = () => ({
    name, version: VERSION, players: players.size, maxPlayers,
    round: rounds.info(), now: Date.now(),
    ranking: rounds.ranking().slice(0, 10).map((r) => ({ name: r.name, time: r.time })),
  });

  const httpServer = http.createServer((req, res) => {
    if (req.method === 'GET' && (req.url === '/' || req.url === '/status')) {
      res.writeHead(200, { 'content-type': 'application/json', 'access-control-allow-origin': '*', 'cache-control': 'no-store' });
      res.end(JSON.stringify(status()));
      return;
    }
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('not found');
  });
  const wss = new WebSocketServer({ server: httpServer, path: '/ws', maxPayload: MAX_FRAME });

  const send = (ws, msg) => { if (ws.readyState === 1) ws.send(JSON.stringify(msg)); };
  const broadcast = (msg) => { const s = JSON.stringify(msg); for (const p of players.values()) if (p.ws.readyState === 1) p.ws.send(s); };
  const playerList = () => {
    const best = new Map(rounds.ranking().map((r) => [r.id, r.time]));
    return [...players.values()].map((p) => ({ id: p.id, name: p.name, colour: p.colour, best: best.has(p.id) ? best.get(p.id) : -1 }));
  };

  rounds.begin(Date.now());

  const clock = setInterval(() => {
    const now = Date.now();
    const changed = rounds.tick(now);
    if (changed === 'results') {
      broadcast({ t: 'results', ranking: rounds.ranking().map((r) => ({ id: r.id, name: r.name, time: r.time })) });
      broadcast({ t: 'round', now, round: rounds.info() });
    } else if (changed === 'race') {
      broadcast({ t: 'round', now, round: rounds.info() });
      broadcast({ t: 'players', players: playerList() });
    }
    // relay the cars
    const s = {};
    for (const p of players.values()) if (p.state && now - p.stateAt < 2000) s[p.id] = p.state;
    if (Object.keys(s).length) broadcast({ t: 'states', s });
  }, 1000 / STATE_HZ);

  wss.on('connection', (ws) => {
    let me = null;
    ws.on('message', (data, isBinary) => {
      if (isBinary || data.length > MAX_FRAME) return;
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { return; }
      if (!msg || typeof msg.t !== 'string') return;
      if (!me) {
        if (msg.t !== 'hello') return;
        if (msg.version !== VERSION) { send(ws, { t: 'error', msg: `version mismatch: server ${VERSION}, game ${msg.version}` }); ws.close(); return; }
        if (players.size >= maxPlayers) { send(ws, { t: 'error', msg: 'server full' }); ws.close(); return; }
        const colour = finiteArray(msg.colour, 3, 2) ? msg.colour.map((c) => Math.min(1, Math.max(0, c))) : [0.85, 0.08, 0.06];
        me = { id: nextId++, name: cleanText(msg.name, 16) || 'Player', colour, ws, state: null, stateAt: 0, chatAt: 0 };
        players.set(me.id, me);
        send(ws, { t: 'welcome', id: me.id, name, now: Date.now(), round: rounds.info(), players: playerList() });
        broadcast({ t: 'players', players: playerList() });
        broadcast({ t: 'chat', from: '', text: `${me.name} joined` });
        return;
      }
      switch (msg.t) {
        case 'state':
          if (finiteArray(msg.p, 3, 1e5) && finiteArray(msg.q, 4, 2)) {
            const v = typeof msg.v === 'number' && Number.isFinite(msg.v) ? Math.max(-1000, Math.min(1000, msg.v)) : 0;
            const st = typeof msg.s === 'number' && Number.isFinite(msg.s) ? Math.max(-1, Math.min(1, msg.s)) : 0;
            me.state = [...msg.p.map((x) => Math.round(x * 100) / 100), ...msg.q.map((x) => Math.round(x * 1000) / 1000),
              Math.round(v * 10) / 10, Math.round(st * 100) / 100];
            me.stateAt = Date.now();
          }
          break;
        case 'finish':
          if (rounds.finish(me.id, me.name, msg.round, msg.track, msg.time)) {
            broadcast({ t: 'players', players: playerList() });
          }
          break;
        case 'chat': {
          const now = Date.now();
          const text = cleanText(msg.text, 120);
          if (text && now - me.chatAt > 700) {
            me.chatAt = now;
            broadcast({ t: 'chat', from: me.name, text });
          }
          break;
        }
        default:
          break;
      }
    });
    ws.on('close', () => {
      if (!me) return;
      players.delete(me.id);
      broadcast({ t: 'players', players: playerList() });
      broadcast({ t: 'chat', from: '', text: `${me.name} left` });
    });
    ws.on('error', () => {});
  });

  return {
    httpServer, wss, rounds, players,
    listen(port, cb) { httpServer.listen(port, cb); return this; },
    close(cb) {
      clearInterval(clock);
      for (const c of wss.clients) c.terminate();
      wss.close();
      httpServer.closeAllConnections();
      httpServer.close(cb);
    },
  };
}

if (require.main === module) {
  const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith('--') && a.includes('='))
    .map((a) => [a.slice(2, a.indexOf('=')), a.slice(a.indexOf('=') + 1)]));
  const port = Number(args.port || process.env.PORT || 8090);
  const srv = createServer({ roundMs: args['round-ms'], resultsMs: args['results-ms'], name: args.name, maxPlayers: args['max-players'] });
  srv.listen(port, () => console.log(`SpeedFest Stadium server on http://localhost:${port} (WebSocket /ws), round ${srv.rounds.track}`));
}

module.exports = { createServer, VERSION };
