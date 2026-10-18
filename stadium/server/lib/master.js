'use strict';
// The master server (TMNF's master: accounts, ladder, rankings, online records, the server list),
// an HTTP JSON API under /api, served by the same process and port as the official game servers.
//
//   POST /api/register {login, password, nickname, zone}  -> {account, token}
//   POST /api/login {login, password}                      -> {account, token}
//   POST /api/logout                                       (Authorization: Bearer <token>)
//   GET  /api/me                                           -> {account, ranks}
//   POST /api/me {nickname?, zone?}                        -> {account}
//   GET  /api/rankings?zone=Europe&limit=50&offset=0       -> {zone, total, players: [{rank, login, nickname, zone, ladder}]}
//   GET  /api/records?track=<uid>&zone=Europe&limit=10     -> {track, count, top, zone_top, mine}
//   POST /api/records {track, time}                        -> {improved, time, rank}   (a logged-in player's finish)
//   GET  /api/servers                                      -> {servers: [{id, name, address, mode, track, players, max, official}]}
//   POST /api/servers {id, name, address, mode, track, players, max}   a community server's heartbeat (its host's token)
//   GET  /api/zones                                        -> {zones}
// Errors: {error} with 400 (bad request), 401 (no or bad token), 404, 429 (too many tries).

const { Accounts, cleanText } = require('./accounts');
const { Records } = require('./records');
const ladder = require('./ladder');

const BODY_MAX = 8192;
const HEARTBEAT_MS = 60000;
const TRIES_PER_MIN = 12;
const MODES = ['TimeAttack', 'Rounds', 'Team', 'Laps'];

class Master {
  constructor(store, { now = () => Date.now(), zones } = {}) {
    this.store = store;
    this.now = now;
    this.accounts = new Accounts(store, zones ? { zones, now } : { now });
    this.records = new Records(store, this.accounts, { now });
    this.official = new Map();      // id -> game server (lib/game.js) in this process
    this.community = new Map();     // id -> {id, name, address, mode, track, players, max, host, seen}
    this._tries = new Map();        // address -> [times]
  }

  // --- in-process use (the official game servers) --------------------------------------------

  addOfficial(id, game) {
    this.official.set(id, game);
  }

  /** A ranked round's results from an official server: [{login, time}] -> login -> ladder delta. */
  rankedRound(ranking) {
    const delta = ladder.applyRound(ranking, this.accounts.table);
    if (Object.keys(delta).length) this.store.changed();
    return delta;
  }

  /** The server list; official servers' relative addresses completed with the request's host. */
  servers(req = null) {
    const now = this.now();
    const out = [];
    let base = '';
    if (req) {
      const visitor = String(req.headers['cf-visitor'] || '');
      const proto = String(req.headers['x-forwarded-proto'] || (visitor.includes('https') ? 'https' : 'http')).split(',')[0];
      base = `${proto}://${req.headers.host || 'localhost'}`;
    }
    for (const [id, g] of this.official) {
      const l = g.listing();
      out.push({ id, official: true, ...l, address: l.address.startsWith('/') ? base + l.address : l.address });
    }
    for (const [id, s] of this.community) {
      if (now - s.seen > HEARTBEAT_MS) { this.community.delete(id); continue; }
      out.push({ id, official: false, name: s.name, address: s.address, mode: s.mode, track: s.track, players: s.players, max: s.max });
    }
    return out;
  }

  // --- HTTP ---------------------------------------------------------------------------------------

  /** Handles a request under /api; returns false for other paths. */
  handle(req, res) {
    const url = new URL(req.url, 'http://x');
    if (!url.pathname.startsWith('/api/')) return false;
    const send = (code, body) => {
      res.writeHead(code, { 'content-type': 'application/json', 'access-control-allow-origin': '*',
        'access-control-allow-headers': 'authorization, content-type', 'cache-control': 'no-store' });
      res.end(JSON.stringify(body));
    };
    if (req.method === 'OPTIONS') { send(204, {}); return true; }
    const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    const route = `${req.method} ${url.pathname}`;
    const readBody = () => new Promise((resolve) => {
      let size = 0;
      const chunks = [];
      req.on('data', (c) => { size += c.length; if (size <= BODY_MAX) chunks.push(c); });
      req.on('end', () => {
        if (size > BODY_MAX) { resolve(null); return; }
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); } catch { resolve(null); }
      });
      req.on('error', () => resolve(null));
    });
    const run = async () => {
      const me = this.accounts.byToken(token);
      switch (route) {
        case 'POST /api/register':
        case 'POST /api/login': {
          if (!this._allow(req)) return send(429, { error: 'too many tries, wait a minute' });
          const body = await readBody();
          if (!body) return send(400, { error: 'bad request' });
          const r = route.endsWith('register') ? await this.accounts.register(body) : await this.accounts.login(body);
          return send(r.error ? (route.endsWith('login') ? 401 : 400) : 200, r);
        }
        case 'POST /api/logout':
          this.accounts.logout(token);
          return send(200, {});
        case 'GET /api/me':
          if (!me) return send(401, { error: 'not logged in' });
          return send(200, { account: this.accounts.view(me), ranks: ladder.ranks(this.accounts.table, me) });
        case 'POST /api/me': {
          if (!me) return send(401, { error: 'not logged in' });
          const body = await readBody();
          if (!body) return send(400, { error: 'bad request' });
          const r = this.accounts.update(me, body);
          return send(r.error ? 400 : 200, r);
        }
        case 'GET /api/rankings': {
          const zone = url.searchParams.get('zone') || 'World';
          const limit = Math.max(1, Math.min(100, Number(url.searchParams.get('limit')) || 50));
          const offset = Math.max(0, Number(url.searchParams.get('offset')) || 0);
          const all = ladder.ranking(this.accounts.table, zone);
          return send(200, { zone, total: all.length, players: all.slice(offset, offset + limit)
            .map((a, i) => ({ rank: offset + i + 1, ...this.accounts.view(a) })) });
        }
        case 'GET /api/records': {
          const track = url.searchParams.get('track') || '';
          const zone = url.searchParams.get('zone') || '';
          const limit = Number(url.searchParams.get('limit')) || 10;
          const mine = me && this.records.table[track] && this.records.table[track][me.login]
            ? { time: this.records.table[track][me.login].time, rank: this.records.rank(track, me.login),
              zone_rank: this.records.rank(track, me.login, me.zone) } : null;
          return send(200, { track, count: this.records.count(track), top: this.records.top(track, 'World', limit),
            zone_top: zone && zone !== 'World' ? this.records.top(track, zone, limit) : [], mine });
        }
        case 'POST /api/records': {
          if (!me) return send(401, { error: 'not logged in' });
          const body = await readBody();
          if (!body) return send(400, { error: 'bad request' });
          const r = this.records.submit(String(body.track || ''), me.login, Number(body.time));
          return send(r.error ? 400 : 200, r);
        }
        case 'GET /api/servers':
          return send(200, { servers: this.servers(req) });
        case 'POST /api/servers': {
          if (!me) return send(401, { error: 'log in to list a server' });
          const body = await readBody();
          if (!body) return send(400, { error: 'bad request' });
          const address = cleanText(body.address, 200);
          if (!/^(https?|wss?):\/\/[^\s/]+/.test(address)) return send(400, { error: 'bad address' });
          const id = `${me.login}:${cleanText(String(body.id || 'main'), 20)}`;
          this.community.set(id, { name: cleanText(body.name, 60) || `${me.login}'s server`, address,
            mode: MODES.includes(body.mode) ? body.mode : 'TimeAttack', track: cleanText(body.track, 80),
            players: Math.max(0, Math.min(255, Number(body.players) || 0)), max: Math.max(1, Math.min(255, Number(body.max) || 32)),
            host: me.login, seen: this.now() });
          return send(200, { id });
        }
        case 'GET /api/zones':
          return send(200, { zones: [...this.accounts.zones] });
        default:
          return send(404, { error: 'not found' });
      }
    };
    run().catch(() => send(500, { error: 'server error' }));
    return true;
  }

  /** Rate limit for register/login: TRIES_PER_MIN per address. */
  _allow(req) {
    const addr = String(req.headers['cf-connecting-ip'] || req.socket.remoteAddress || '?');
    const now = this.now();
    const tries = (this._tries.get(addr) || []).filter((t) => now - t < 60000);
    if (tries.length >= TRIES_PER_MIN) { this._tries.set(addr, tries); return false; }
    tries.push(now);
    this._tries.set(addr, tries);
    if (this._tries.size > 10000) this._tries.clear();
    return true;
  }
}

module.exports = { Master, MODES };
