'use strict';
// SpeedFest Stadium online: the master server (accounts, ladder, rankings, records, the server
// list: lib/master.js, HTTP /api) and the official game servers (lib/game.js: Time Attack,
// Rounds, Team, Laps, each a room on WebSocket /ws/<id>), all in one process on one port, so one
// Cloudflare tunnel serves them all (docker-compose.yml). Data: DATA_DIR/master.json.
//
// HTTP: /api/... (lib/master.js); GET / or /status: the first server's status and the list;
// GET /ws/<id>/status: a server's status. WebSocket: /ws/<id> (/ws: the first server).
// Admins (lib/admin.js): /api/admin/... and the page /admin upload community tracks (TrackMania
// Exchange) and car packs (ManiaPark) and set each server's rotation and cars; players download
// the files from /content/ (lib/content.js; files in DATA_DIR/content).
// The game's Community page (lib/community.js): /api/community/... passes TrackMania Exchange and
// ManiaPark searches, previews and files to browsers (the web build; those sites send no CORS headers).
// Run: node server.js [--config=config.json] [--port=8090] [--host=127.0.0.1] [--data=./data]
//      [--name= --mode=TimeAttack|Rounds|Team|Laps --round-ms= --results-ms= --max-players= --tracks=]
// config.json: {"port", "host", "data", "admins": [logins], "admin_password", "servers": [{"id", "name",
//   "mode", "max_players", "tracks", "round_ms", "results_ms", "ranked"}]}. Env: CONFIG, PORT, HOST,
//   DATA_DIR, NAME, ROUND_MS, ..., ADMINS (logins, comma-separated), ADMIN_PASSWORD.

const http = require('http');
const fs = require('fs');
const path = require('path');
const { Store } = require('./lib/store');
const { Master } = require('./lib/master');
const { Game, VERSION } = require('./lib/game');
const { TRACKS, TMNF_CAMPAIGN } = require('./lib/rounds');
const { Content } = require('./lib/content');
const { Admin } = require('./lib/admin');
const { Community, fixtureFetch } = require('./lib/community');

function trackList(v) {
  const list = String(v || '').trim();
  return list === 'tmnf' ? TMNF_CAMPAIGN : list ? list.split(',').map((t) => t.trim()).filter(Boolean) : TRACKS;
}

/** The app: {master, games, content, admin, httpServer, listen, close}. config: {data (dir; '' in
 *  memory), master (default true), admins (logins), adminPassword, fetch (tests), servers: [{id,
 *  name, mode, maxPlayers, tracks, roundMs, resultsMs, ranked}]}. */
function createApp(config = {}) {
  const store = new Store(config.data ? path.join(config.data, 'master.json') : '');
  const master = config.master === false ? null : new Master(store);
  const content = new Content(store, config.data ? path.join(config.data, 'content') : '', config.fetch ? { fetch: config.fetch } : {});
  const games = new Map();
  for (const s of (config.servers && config.servers.length ? config.servers : [{ id: 'main' }])) {
    const id = String(s.id || 'main');
    const game = new Game({ id, name: s.name || 'SpeedFest Stadium', mode: s.mode || 'TimeAttack', tracks: trackList(s.tracks),
      maxPlayers: Number(s.maxPlayers || s.max_players || 32), master, ranked: s.ranked !== false, path: `/ws/${id}`, content,
      modeOpts: { roundMs: Number(s.roundMs || s.round_ms || 5 * 60 * 1000), resultsMs: Number(s.resultsMs || s.results_ms || 15000) } });
    games.set(id, game.start());
    if (master) master.addOfficial(id, game);
  }
  const first = games.values().next().value;
  const admin = new Admin({ master, content, games, store, admins: config.admins || [], password: config.adminPassword || '',
    own: TRACKS, campaign: TMNF_CAMPAIGN });
  admin.restore();
  const json = (res, code, body) => {
    res.writeHead(code, { 'content-type': 'application/json', 'access-control-allow-origin': '*', 'cache-control': 'no-store' });
    res.end(JSON.stringify(body));
  };
  const community = new Community(config.communityFixtures ? { fetch: fixtureFetch(config.communityFixtures) }
    : config.fetch ? { fetch: config.fetch } : {});
  const httpServer = http.createServer((req, res) => {
    if (community.handle(req, res)) return;
    if (admin.handle(req, res)) return;
    if (master && master.handle(req, res)) return;
    const url = new URL(req.url, 'http://x');
    if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/status')) {
      return json(res, 200, { ...first.status(), servers: master ? master.servers(req) : [] });
    }
    const m = url.pathname.match(/^\/ws\/([A-Za-z0-9_-]+)\/status$/);
    if (req.method === 'GET' && m && games.has(m[1])) return json(res, 200, games.get(m[1]).status());
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('not found');
  });
  httpServer.on('upgrade', (req, socket, head) => {
    const p = new URL(req.url, 'http://x').pathname;
    const m = p.match(/^\/ws\/([A-Za-z0-9_-]+)$/);
    const game = p === '/ws' ? first : (m ? games.get(m[1]) : null);
    if (!game) { socket.destroy(); return; }
    game.upgrade(req, socket, head);
  });
  return {
    master, games, httpServer, store, content, admin,
    get players() { return first.players; },
    listen(port, cb, host) { if (host) httpServer.listen(port, host, cb); else httpServer.listen(port, cb); return this; },
    close(cb) {
      for (const g of games.values()) g.close();
      store.close();
      httpServer.closeAllConnections();
      httpServer.close(cb);
    },
  };
}

/** One server (the tests' and the old command line's): a mode's room, the master in memory. */
function createServer(opts = {}) {
  return createApp({ data: opts.data || '', master: opts.master, admins: opts.admins, adminPassword: opts.adminPassword, fetch: opts.fetch,
    servers: [{ id: 'main', name: opts.name || process.env.NAME, mode: opts.mode || process.env.MODE, maxPlayers: opts.maxPlayers || process.env.MAX_PLAYERS,
      tracks: opts.tracks || process.env.TRACKS, roundMs: opts.roundMs || process.env.ROUND_MS, resultsMs: opts.resultsMs || process.env.RESULTS_MS }] });
}

if (require.main === module) {
  const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith('--') && a.includes('='))
    .map((a) => [a.slice(2, a.indexOf('=')), a.slice(a.indexOf('=') + 1)]));
  const file = args.config || process.env.CONFIG;
  const cfg = file ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
  const port = Number(args.port || process.env.PORT || cfg.port || 8090);
  const host = args.host || process.env.HOST || cfg.host;
  const data = args.data || process.env.DATA_DIR || cfg.data || path.join(__dirname, 'data');
  const servers = cfg.servers || [{ id: 'main', name: args.name || process.env.NAME, mode: args.mode || process.env.MODE,
    maxPlayers: args['max-players'] || process.env.MAX_PLAYERS, tracks: args.tracks || process.env.TRACKS,
    roundMs: args['round-ms'] || process.env.ROUND_MS, resultsMs: args['results-ms'] || process.env.RESULTS_MS }];
  const admins = String(args.admins || process.env.ADMINS || '').split(',').map((a) => a.trim()).filter(Boolean)
    .concat(Array.isArray(cfg.admins) ? cfg.admins : []);
  const adminPassword = args['admin-password'] || process.env.ADMIN_PASSWORD || cfg.admin_password || '';
  const app = createApp({ data, servers, admins, adminPassword, communityFixtures: args['community-fixtures'] || '' });
  app.listen(port, () => {
    console.log(`SpeedFest Stadium on http://${host || 'localhost'}:${port}: master /api, data ${data}`);
    console.log(app.admin.enabled() ? `  admins: http://${host || 'localhost'}:${port}/admin (${admins.length} admin accounts${adminPassword ? ', admin password set' : ''})`
      : '  no admins (set ADMIN_PASSWORD or "admins" to upload community tracks and cars)');
    for (const g of app.games.values()) console.log(`  ${g.mode.name.padEnd(10)} ${g.name}: /ws/${g.id}, track ${g.mode.info().track}`);
  }, host);
  const stop = () => app.close(() => process.exit(0));
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

module.exports = { createApp, createServer, VERSION };
