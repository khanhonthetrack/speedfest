'use strict';
// Server admins (like a TMNF dedicated server's admins): upload community tracks and car packs,
// import them from TrackMania Exchange and ManiaPark, choose each game server's map rotation and
// cars, jump to a map or skip to the next. An admin is a master account listed in the config's
// "admins", or anyone with the config's admin password (ADMIN_PASSWORD), sent as
// "Authorization: Admin <password>". Without either, admin calls are refused. The page /admin is
// a small web page over this API.
//
//   GET    /api/admin                        -> {login, servers: [{id, name, mode, track, tracks, cars, forced_car}],
//                                               tracks: [uploaded], cars: [uploaded], own: [the game's track ids]}
//   POST   /api/admin/tracks?servers=a,b|all    body: a .Challenge.Gbx  -> {track, servers}
//   POST   /api/admin/tracks?servers=...        {tmx: "<id or link>"}  (TrackMania Exchange)
//   DELETE /api/admin/tracks/<uid>
//   POST   /api/admin/cars?name=&servers=       body: a .zip (a TMNF skin or car model)  -> {car, servers}
//   POST   /api/admin/cars?servers=...          {maniapark: "<link>", name?}
//   DELETE /api/admin/cars/<id>
//   POST   /api/admin/servers/<id>          {tracks?, add_tracks?, remove_tracks?, cars?, add_cars?, remove_cars?,
//                                            forced_car?, jump?, next?}  -> {server}
// Public:
//   GET    /content/<sha256>.Challenge.Gbx | .zip   an uploaded file (never changes: cached for good)
//   GET    /api/content                     -> {tracks, cars} (what this server's admins uploaded)
//   GET    /admin                           the admin page

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { Content } = require('./content');

const JSON_MAX = 16 * 1024;
const TRACK_BODY_MAX = 32 * 1024 * 1024;
const CAR_BODY_MAX = 128 * 1024 * 1024;
const TRIES_PER_MIN = 20;
const PAGE = path.join(__dirname, 'admin_page.html');

function sha256(s) {
  return crypto.createHash('sha256').update(String(s)).digest();
}

class Admin {
  /** opts: {master, content, games (Map id -> Game), store, admins (logins), password, own (track ids),
   *  campaign (more ids a rotation may name, e.g. TMNF's A01..E05)} */
  constructor({ master, content, games, store, admins = [], password = '', own = [], campaign = [], now = () => Date.now() }) {
    this.master = master;
    this.content = content;
    this.games = games;
    this.store = store;
    this.admins = new Set(admins.map((a) => String(a).toLowerCase()));
    this.password = password ? sha256(password) : null;
    this.own = own.slice();
    this.campaign = campaign.slice();
    this.now = now;
    this._tries = new Map();
  }

  enabled() {
    return this.admins.size > 0 || !!this.password;
  }

  /** The servers' saved settings ({id: {tracks, cars, forced_car}}), applied at start and kept on change. */
  get saved() { return this.store.table('servers'); }

  /** Applies the saved rotation and cars to each game (at start). */
  restore() {
    for (const [id, g] of this.games) {
      const s = this.saved[id];
      if (!s) continue;
      const tracks = (s.tracks || []).filter((t) => this.validTrack(t));
      if (tracks.length) g.setTracks(tracks);
      g.setCars((s.cars || []).filter((c) => this.content.cars[c]), s.forced_car || '');
    }
  }

  validTrack(id) {
    return typeof id === 'string' && (this.own.includes(id) || this.campaign.includes(id) || !!this.content.tracks[id]);
  }

  _save(id, g) {
    this.saved[id] = { tracks: this._tracksOf(g), cars: g.cars.slice(), forced_car: g.forcedCar };
    this.store.changed();
  }

  _tracksOf(g) {
    return (g.mode.tracks || (g.mode.r && g.mode.r.tracks) || []).slice();
  }

  serverView(id, g) {
    const info = g.mode.info();
    return { id, name: g.name, mode: g.mode.name, track: info.track, state: info.state, players: g.players.size,
      tracks: this._tracksOf(g), cars: g.cars.slice(), forced_car: g.forcedCar };
  }

  /** Who is asking: {login} for an admin, {error, code} otherwise. */
  _who(req) {
    if (!this.enabled()) return { error: 'this server has no admins: set "admins" or "admin_password" (ADMIN_PASSWORD) in its config', code: 403 };
    const auth = String(req.headers.authorization || '');
    const pw = auth.match(/^Admin\s+(.+)$/i);
    if (pw) {
      if (!this._allow(req)) return { error: 'too many tries, wait a minute', code: 429 };
      if (this.password && crypto.timingSafeEqual(sha256(pw[1]), this.password)) return { login: '(admin password)' };
      return { error: 'wrong admin password', code: 401 };
    }
    const token = auth.replace(/^Bearer\s+/i, '');
    const a = this.master ? this.master.accounts.byToken(token) : null;
    if (!a) return { error: 'log in as an admin', code: 401 };
    if (!this.admins.has(a.login)) return { error: `${a.login} isn't an admin of this server`, code: 403 };
    return { login: a.login };
  }

  _allow(req) {
    const addr = String(req.headers['cf-connecting-ip'] || req.socket.remoteAddress || '?');
    const now = this.now();
    const tries = (this._tries.get(addr) || []).filter((t) => now - t < 60000);
    tries.push(now);
    this._tries.set(addr, tries);
    if (this._tries.size > 10000) this._tries.clear();
    return tries.length <= TRIES_PER_MIN;
  }

  /** The games a ?servers= list names ('all': every one). */
  _targets(list) {
    const v = String(list || '').trim();
    if (!v) return [];
    if (v === 'all') return [...this.games.keys()];
    return v.split(',').map((x) => x.trim()).filter((x) => this.games.has(x));
  }

  _addTrackTo(ids, uid) {
    for (const id of ids) {
      const g = this.games.get(id);
      const tracks = this._tracksOf(g);
      if (!tracks.includes(uid)) {
        g.setTracks([...tracks, uid]);
        this._save(id, g);
      }
    }
  }

  _addCarTo(ids, carId) {
    for (const id of ids) {
      const g = this.games.get(id);
      if (!g.cars.includes(carId)) {
        g.setCars([...g.cars, carId], g.forcedCar);
        this._save(id, g);
      }
    }
  }

  /** Handles /api/admin..., /api/content, /content/..., /admin; false for other paths. */
  handle(req, res) {
    const url = new URL(req.url, 'http://x');
    const p = url.pathname;
    if (!(p === '/admin' || p === '/api/content' || p.startsWith('/api/admin') || p.startsWith('/content/'))) return false;
    const send = (code, body) => {
      res.writeHead(code, { 'content-type': 'application/json', 'access-control-allow-origin': '*',
        'access-control-allow-headers': 'authorization, content-type', 'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
        'cache-control': 'no-store' });
      res.end(JSON.stringify(body));
    };
    if (req.method === 'OPTIONS') { send(204, {}); return true; }
    if (req.method === 'GET' && p === '/admin') {
      fs.readFile(PAGE, (err, html) => {
        if (err) { send(404, { error: 'not found' }); return; }
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
        res.end(html);
      });
      return true;
    }
    if (req.method === 'GET' && p.startsWith('/content/')) {
      const name = p.slice('/content/'.length);
      const data = this.content.file(name);
      if (!data) { send(404, { error: 'not found' }); return true; }
      res.writeHead(200, { 'content-type': name.endsWith('.zip') ? 'application/zip' : 'application/octet-stream',
        'content-length': data.length, 'access-control-allow-origin': '*', 'cache-control': 'public, max-age=31536000, immutable' });
      res.end(data);
      return true;
    }
    if (req.method === 'GET' && p === '/api/content') {
      send(200, { tracks: Object.values(this.content.tracks).map(Content.view), cars: Object.values(this.content.cars).map(Content.view) });
      return true;
    }
    this._admin(req, res, url, send).catch(() => { if (!res.headersSent) send(500, { error: 'server error' }); });
    return true;
  }

  _body(req, max) {
    return new Promise((resolve) => {
      let size = 0;
      const chunks = [];
      req.on('data', (c) => { size += c.length; if (size <= max) chunks.push(c); });
      req.on('end', () => resolve(size > max ? null : Buffer.concat(chunks)));
      req.on('error', () => resolve(null));
    });
  }

  async _admin(req, res, url, send) {
    const who = this._who(req);
    if (who.error) { req.resume(); return send(who.code, { error: who.error }); }
    const p = url.pathname;
    const isJson = /json/i.test(String(req.headers['content-type'] || ''));
    const route = `${req.method} ${p.replace(/^(\/api\/admin\/(?:tracks|cars|servers))\/.+$/, '$1/:id')}`;
    const param = decodeURIComponent(p.split('/')[4] || '');
    switch (route) {
      case 'GET /api/admin':
        return send(200, { login: who.login, servers: [...this.games].map(([id, g]) => this.serverView(id, g)),
          tracks: Object.values(this.content.tracks), cars: Object.values(this.content.cars), own: this.own, campaign: this.campaign });
      case 'POST /api/admin/tracks': {
        const buf = await this._body(req, isJson ? JSON_MAX : TRACK_BODY_MAX);
        if (!buf) return send(413, { error: 'the file is too big' });
        let r;
        if (isJson) {
          let body;
          try { body = JSON.parse(buf.toString('utf8') || '{}'); } catch { return send(400, { error: 'bad request' }); }
          r = await this.content.importTrack(body.tmx || body.url || '', { by: who.login });
        } else {
          r = this.content.addTrack(buf, { by: who.login });
        }
        if (r.error) return send(400, { error: r.error });
        const targets = this._targets(url.searchParams.get('servers'));
        this._addTrackTo(targets, r.track.uid);
        this._refreshTrack(r.track.uid);
        return send(200, { track: r.track, replaced: !!r.replaced, servers: targets });
      }
      case 'DELETE /api/admin/tracks/:id': {
        if (!this.content.tracks[param]) return send(404, { error: 'no such track' });
        for (const [id, g] of this.games) {
          const tracks = this._tracksOf(g);
          if (!tracks.includes(param)) continue;
          const left = tracks.filter((t) => t !== param);
          g.setTracks(left.length ? left : this.own.slice(0, 1));
          this._save(id, g);
        }
        this.content.removeTrack(param);
        return send(200, {});
      }
      case 'POST /api/admin/cars': {
        const buf = await this._body(req, isJson ? JSON_MAX : CAR_BODY_MAX);
        if (!buf) return send(413, { error: 'the file is too big' });
        let r;
        if (isJson) {
          let body;
          try { body = JSON.parse(buf.toString('utf8') || '{}'); } catch { return send(400, { error: 'bad request' }); }
          r = await this.content.importCar(body.maniapark || body.url || '', { by: who.login, name: body.name || '' });
        } else {
          r = this.content.addCar(buf, { by: who.login, name: url.searchParams.get('name') || '' });
        }
        if (r.error) return send(400, { error: r.error });
        const targets = this._targets(url.searchParams.get('servers'));
        this._addCarTo(targets, r.car.id);
        return send(200, { car: r.car, servers: targets });
      }
      case 'DELETE /api/admin/cars/:id': {
        if (!this.content.cars[param]) return send(404, { error: 'no such car' });
        for (const [id, g] of this.games) {
          if (!g.cars.includes(param)) continue;
          g.setCars(g.cars.filter((c) => c !== param), g.forcedCar === param ? '' : g.forcedCar);
          this._save(id, g);
        }
        this.content.removeCar(param);
        return send(200, {});
      }
      case 'POST /api/admin/servers/:id': {
        const g = this.games.get(param);
        if (!g) return send(404, { error: 'no such server' });
        const buf = await this._body(req, JSON_MAX);
        let body;
        try { body = JSON.parse((buf || '').toString('utf8') || '{}'); } catch { return send(400, { error: 'bad request' }); }
        const list = (v) => (Array.isArray(v) ? v.map(String) : []);
        let tracks = Array.isArray(body.tracks) ? list(body.tracks) : this._tracksOf(g);
        tracks = [...tracks, ...list(body.add_tracks).filter((t) => !tracks.includes(t))].filter((t) => !list(body.remove_tracks).includes(t));
        const bad = tracks.filter((t) => !this.validTrack(t));
        if (bad.length) return send(400, { error: `unknown tracks: ${bad.slice(0, 5).join(', ')}` });
        if (!tracks.length) return send(400, { error: 'a server needs at least one track' });
        let cars = Array.isArray(body.cars) ? list(body.cars) : g.cars.slice();
        cars = [...cars, ...list(body.add_cars).filter((c) => !cars.includes(c))].filter((c) => !list(body.remove_cars).includes(c));
        const badCars = cars.filter((c) => !this.content.cars[c]);
        if (badCars.length) return send(400, { error: `unknown cars: ${badCars.slice(0, 5).join(', ')}` });
        const forced = body.forced_car !== undefined ? String(body.forced_car || '') : g.forcedCar;
        if (forced && !cars.includes(forced)) return send(400, { error: 'the forced car must be one of the server\'s cars' });
        g.setTracks(tracks);
        g.setCars(cars, forced);
        if (body.jump !== undefined) {
          if (!tracks.includes(String(body.jump))) return send(400, { error: 'jump to a track of the rotation' });
          g.jump(String(body.jump));
        } else if (body.next) {
          g.next();
        }
        this._save(param, g);
        return send(200, { server: this.serverView(param, g) });
      }
      default:
        req.resume();
        return send(404, { error: 'not found' });
    }
  }

  /** A track re-uploaded with new contents while it is being raced: the games tell their players. */
  _refreshTrack(uid) {
    for (const g of this.games.values()) {
      if (g.mode.info().track === uid) g.broadcast({ t: 'round', now: this.now(), round: g.info() });
    }
  }
}

module.exports = { Admin };
