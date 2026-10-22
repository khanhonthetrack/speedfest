'use strict';
// One game server (a room, like a TMNF dedicated server): a mode (lib/modes.js), its map rotation,
// the players and spectators on a WebSocket, their cars relayed 10 times a second, chat, votes,
// and, on the official servers (in the master's process), the ladder and the online records.
//
// Community content (lib/content.js): a map of the rotation may be a track an admin uploaded; the
// round then carries its file ({uid, name, author, sha256, size, url}: the game downloads it from
// this server's /content/). Players may drive one of the server's car packs (TMNF skins and
// models an admin uploaded): the welcome lists them, a player's pick is in the player list.
//
// Client -> server:
//   {t:'hello', name, version, colour, token?, spectator?, car?, model?, livery?} token: the master's (an
//                                                              account); car: a car pack's id ('' ours);
//                                                              model: which of our own cars ('' the
//                                                              open-wheeler, 'hyper' the hypercar, a
//                                                              road car); livery: its livery (0-4)
//   {t:'car', id}                                              another car (one of the server's)
//   {t:'state', p:[x,y,z], q:[x,y,z,w], v, s}                  the car (racers)
//   {t:'finish', round, track, time, uid?}                     a finish (uid: the track's, for records)
//   {t:'chat', text}
//   {t:'callvote', kind:'next'|'restart'|'kick', target?}      {t:'vote', yes}
//   {t:'spectate', on}
// Server -> client:
//   {t:'welcome', id, name, mode, now, round, players, cars, forced_car}   {t:'round', now, round}
//   {t:'players', players:[{id, name, colour, best, points, team, spectator, login, car, model, livery}]}
//   {t:'cars', cars, forced_car}                               the server's car packs changed
//   {t:'states', s:{id:[px,py,pz,qx,qy,qz,qw,v,s]}}
//   {t:'results', ranking, last_round, teams, map_over}         {t:'ladder', deltas:[{id, delta}]}
//   {t:'vote', vote:{kind, target, target_name, by, yes, no, needed, ends} | null, passed?}
//   {t:'chat', from, text}                                     {t:'error', msg}

const { WebSocketServer } = require('ws');
const { makeMode } = require('./modes');
const { cleanText, stripNick, NICK_MAX } = require('./accounts');

/** Our own cars a player may drive (TmUi.car_models()): '' the open-wheeler, 'hyper' the hypercar, and
 * the road cars (TmRoadCars.CARS); each but the open-wheeler has five liveries (0-4). */
const CAR_MODELS = ['', 'hyper', 'kobold', 'ayame', 'birdie', 'nemesis', 'umbra', 'zenith', 'stallion', 'kaiten', 'halberd',
  'gavial', 'argent', 'albion', 'taipan', 'corrida', 'frigate', 'quicksilver'];
const LIVERIES = 5;

const VERSION = 2;
const MAX_FRAME = 4096;
const STATE_HZ = 10;
const VOTE_MS = 30000;
const VOTE_COOLDOWN_MS = 60000;
const UID_RE = /^[A-Za-z0-9_.-]{1,80}$/;

/** A guest's name: its $-codes kept, 'Player' if it shows nothing without them. */
function guestName(v) {
  const name = cleanText(v, NICK_MAX);
  return name && stripNick(name).trim() ? name : 'Player';
}

function finiteArray(a, n, limit) {
  return Array.isArray(a) && a.length === n && a.every((x) => typeof x === 'number' && Number.isFinite(x) && Math.abs(x) < limit);
}

class Game {
  constructor({ id = 'main', name = 'SpeedFest Stadium', mode = 'TimeAttack', tracks, maxPlayers = 32, master = null,
    ranked = false, path = '/ws', modeOpts = {}, now = () => Date.now(), content = null, cars = [], forcedCar = '' } = {}) {
    this.id = id;
    this.name = name;
    this.maxPlayers = maxPlayers;
    this.master = master;
    this.ranked = ranked && !!master;
    this.path = path;
    this.now = now;
    this.mode = makeMode(mode, { ...modeOpts, ...(tracks ? { tracks } : {}) });
    this.content = content;       // uploaded tracks and car packs (lib/content.js) or null
    this.cars = cars.slice();     // the car packs players may pick (ids)
    this.forcedCar = forcedCar;   // a car pack everyone drives ('' none)
    this.players = new Map();     // id -> {id, name, colour, ws, state, stateAt, chatAt, login, spectator, voteAt}
    this.nextId = 1;
    this.vote = null;             // {kind, target, by, yes: Set, no: Set, ends}
    this.wss = new WebSocketServer({ noServer: true, maxPayload: MAX_FRAME });
    this.wss.on('connection', (ws) => this._connection(ws));
    this.clock = null;
  }

  start() {
    this.mode.begin(this.now());
    this.clock = setInterval(() => this.tick(), 1000 / STATE_HZ);
    return this;
  }

  close() {
    if (this.clock) clearInterval(this.clock);
    for (const c of this.wss.clients) c.terminate();
    this.wss.close();
  }

  upgrade(req, socket, head) {
    this.wss.handleUpgrade(req, socket, head, (ws) => this.wss.emit('connection', ws, req));
  }

  /** The round as players get it: the mode's, plus the track's file when an admin uploaded it. */
  info() {
    const info = this.mode.info();
    const t = this.content ? this.content.tracks[info.track] : null;
    if (t) info.file = { uid: t.uid, name: t.name, author: t.author, sha256: t.sha256, size: t.size, url: t.url };
    return info;
  }

  /** The car packs players may pick here: [{id, name, sha256, size, url, mesh, skin, sounds}]. */
  carList() {
    if (!this.content) return [];
    return this.cars.map((id) => this.content.cars[id]).filter(Boolean)
      .map((c) => ({ id: c.id, name: c.name, sha256: c.sha256, size: c.size, url: c.url, mesh: c.mesh, skin: c.skin, sounds: c.sounds }));
  }

  /** A player's car: the forced one, else theirs if the server has it, else '' (the game's own). */
  _car(id) {
    if (this.forcedCar && this.cars.includes(this.forcedCar)) return this.forcedCar;
    return typeof id === 'string' && this.cars.includes(id) ? id : '';
  }

  // --- admins (lib/admin.js) ------------------------------------------------------------------

  /** A new rotation: from the next map on (now too if the current map left it). */
  setTracks(tracks) {
    this.mode.setTracks(tracks);
    if (!tracks.includes(this.mode.info().track)) this.jump(tracks[0]);
  }

  /** `track` now (a new map). */
  jump(track) {
    const now = this.now();
    this.mode.jump(now, track);
    this.broadcast({ t: 'round', now, round: this.info() });
    this.broadcast({ t: 'players', players: this.playerList() });
  }

  /** The next map now (with the results). */
  next() {
    const now = this.now();
    const ev = this.mode.skip(now);
    if (ev === 'results') this._results();
    this.broadcast({ t: 'round', now, round: this.info() });
    this.broadcast({ t: 'players', players: this.playerList() });
  }

  setCars(cars, forcedCar = '') {
    this.cars = cars.slice();
    this.forcedCar = forcedCar && cars.includes(forcedCar) ? forcedCar : '';
    for (const p of this.players.values()) p.car = this._car(p.car);
    this.broadcast({ t: 'cars', cars: this.carList(), forced_car: this.forcedCar });
    this.broadcast({ t: 'players', players: this.playerList() });
  }

  racers() {
    return [...this.players.values()].filter((p) => !p.spectator);
  }

  /** For the master's server list (the address is relative: the master completes it). */
  listing() {
    const info = this.info();
    return { name: this.name, address: this.path, mode: this.mode.name, track: info.track, players: this.players.size, max: this.maxPlayers };
  }

  status() {
    return { name: this.name, version: VERSION, mode: this.mode.name, players: this.players.size, maxPlayers: this.maxPlayers,
      round: this.info(), tracks: this.mode.tracks || (this.mode.r && this.mode.r.tracks) || [], cars: this.carList(),
      forced_car: this.forcedCar, now: this.now(), ranking: this.mode.standings().slice(0, 10).map((r) => ({ name: r.name, time: r.time, points: r.points })) };
  }

  _send(ws, msg) {
    if (ws.readyState === 1) ws.send(JSON.stringify(msg));
  }

  broadcast(msg) {
    const s = JSON.stringify(msg);
    for (const p of this.players.values()) if (p.ws.readyState === 1) p.ws.send(s);
  }

  playerList() {
    const st = new Map(this.mode.standings().map((r) => [r.id, r]));
    return [...this.players.values()].map((p) => {
      const r = st.get(p.id) || {};
      return { id: p.id, name: p.name, colour: p.colour, best: r.time !== undefined ? r.time : -1, points: r.points || 0,
        team: this.mode.teamOf ? this.mode.teamOf(p.id) : -1, spectator: p.spectator, login: p.login || '', car: p.car || '',
        model: p.model || '', livery: p.livery || 0 };
    });
  }

  _chat(text) {
    this.broadcast({ t: 'chat', from: '', text });
  }

  tick() {
    const now = this.now();
    const ev = this.mode.tick(now);
    if (ev === 'results') this._results();
    if (ev) {
      this.broadcast({ t: 'round', now, round: this.info() });
      this.broadcast({ t: 'players', players: this.playerList() });
    }
    if (this.vote && now >= this.vote.ends) this._closeVote(false);
    const s = {};
    for (const p of this.players.values()) if (!p.spectator && p.state && now - p.stateAt < 2000) s[p.id] = p.state;
    if (Object.keys(s).length) this.broadcast({ t: 'states', s });
  }

  _results() {
    const m = this.mode;
    this.broadcast({ t: 'results', ranking: m.standings(), last_round: m.lastRound || null, teams: m.lastTeams || null,
      team_points: m.teamPoints || null, map_over: m.mapOver !== undefined ? m.mapOver : true });
    const ranked = m.ranked();
    if (ranked && this.ranked) {
      const delta = this.master.rankedRound(ranked);
      const byLogin = new Map([...this.players.values()].filter((p) => p.login).map((p) => [p.login, p.id]));
      const deltas = Object.entries(delta).filter(([l]) => byLogin.has(l)).map(([l, d]) => ({ id: byLogin.get(l), delta: d }));
      if (deltas.length) this.broadcast({ t: 'ladder', deltas });
    }
  }

  _connection(ws) {
    let me = null;
    ws.on('message', (data, isBinary) => {
      if (isBinary || data.length > MAX_FRAME) return;
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { return; }
      if (!msg || typeof msg.t !== 'string') return;
      if (!me) {
        if (msg.t !== 'hello') return;
        me = this._hello(ws, msg);
        return;
      }
      this._message(me, msg);
    });
    ws.on('close', () => {
      if (!me) return;
      this.players.delete(me.id);
      this.mode.leave(me.id);
      if (this.vote && this.vote.kind === 'kick' && this.vote.target === me.id) this._closeVote(false);
      if (this.vote) {
        this.vote.yes.delete(me.id);
        this.vote.no.delete(me.id);
        this._checkVote();
      }
      this.broadcast({ t: 'players', players: this.playerList() });
      this._chat(`${me.name} left`);
    });
    ws.on('error', () => {});
  }

  _hello(ws, msg) {
    if (msg.version !== VERSION) {
      this._send(ws, { t: 'error', msg: `version mismatch: server ${VERSION}, game ${msg.version}` });
      ws.close();
      return null;
    }
    if (this.players.size >= this.maxPlayers) {
      this._send(ws, { t: 'error', msg: 'server full' });
      ws.close();
      return null;
    }
    const account = this.master && msg.token ? this.master.accounts.byToken(msg.token) : null;
    const colour = finiteArray(msg.colour, 3, 2) ? msg.colour.map((c) => Math.min(1, Math.max(0, c))) : [0.85, 0.08, 0.06];
    const me = { id: this.nextId++, name: account ? account.nickname : guestName(msg.name), colour, ws,
      state: null, stateAt: 0, chatAt: 0, voteAt: 0, login: account ? account.login : '', spectator: !!msg.spectator,
      car: this._car(msg.car), model: CAR_MODELS.includes(msg.model) ? msg.model : '',
      livery: Number.isInteger(msg.livery) && msg.livery >= 0 && msg.livery < LIVERIES ? msg.livery : 0 };
    this.players.set(me.id, me);
    if (!me.spectator) this.mode.join(me.id, me.name, me.login, this.now());
    this._send(ws, { t: 'welcome', id: me.id, name: this.name, mode: this.mode.name, now: this.now(), round: this.info(),
      players: this.playerList(), login: me.login, vote: this._voteInfo(), cars: this.carList(), forced_car: this.forcedCar });
    this.broadcast({ t: 'players', players: this.playerList() });
    this._chat(`${me.name} joined${me.spectator ? ' as a spectator' : ''}`);
    return me;
  }

  _message(me, msg) {
    const now = this.now();
    switch (msg.t) {
      case 'state':
        if (!me.spectator && finiteArray(msg.p, 3, 1e5) && finiteArray(msg.q, 4, 2)) {
          const v = typeof msg.v === 'number' && Number.isFinite(msg.v) ? Math.max(-1000, Math.min(1000, msg.v)) : 0;
          const st = typeof msg.s === 'number' && Number.isFinite(msg.s) ? Math.max(-1, Math.min(1, msg.s)) : 0;
          me.state = [...msg.p.map((x) => Math.round(x * 100) / 100), ...msg.q.map((x) => Math.round(x * 1000) / 1000),
            Math.round(v * 10) / 10, Math.round(st * 100) / 100];
          me.stateAt = now;
        }
        break;
      case 'finish':
        if (!me.spectator && this.mode.finish(me.id, msg.round, msg.track, msg.time)) {
          this.broadcast({ t: 'players', players: this.playerList() });
          if (this.ranked && me.login && typeof msg.uid === 'string' && UID_RE.test(msg.uid)) this.master.records.submit(msg.uid, me.login, msg.time);
        }
        break;
      case 'chat': {
        const text = cleanText(msg.text, 120);
        if (text && now - me.chatAt > 700) {
          me.chatAt = now;
          this.broadcast({ t: 'chat', from: me.name, text });
        }
        break;
      }
      case 'callvote':
        this._callVote(me, msg);
        break;
      case 'vote':
        if (this.vote && !me.spectator) {
          (msg.yes ? this.vote.yes : this.vote.no).add(me.id);
          (msg.yes ? this.vote.no : this.vote.yes).delete(me.id);
          this._checkVote();
        }
        break;
      case 'car': {
        const car = this._car(msg.id);
        if (car !== me.car) {
          me.car = car;
          this.broadcast({ t: 'players', players: this.playerList() });
        }
        break;
      }
      case 'spectate': {
        const on = !!msg.on;
        if (on === me.spectator) break;
        me.spectator = on;
        me.state = null;
        if (on) this.mode.leave(me.id);
        else this.mode.join(me.id, me.name, me.login, now);
        this.broadcast({ t: 'players', players: this.playerList() });
        break;
      }
      default:
        break;
    }
  }

  // --- votes ---------------------------------------------------------------------------------------

  _voteInfo() {
    const v = this.vote;
    if (!v) return null;
    const target = v.target ? this.players.get(v.target) : null;
    return { kind: v.kind, target: v.target || 0, target_name: target ? target.name : '', by: v.by, yes: v.yes.size, no: v.no.size,
      needed: this._needed(), ends: v.ends };
  }

  _needed() {
    return Math.floor(this.racers().length / 2) + 1;
  }

  _callVote(me, msg) {
    const now = this.now();
    const kind = String(msg.kind || '');
    if (me.spectator || !['next', 'restart', 'kick'].includes(kind)) return;
    if (this.vote) { this._send(me.ws, { t: 'chat', from: '', text: 'A vote is already running' }); return; }
    if (now - me.voteAt < VOTE_COOLDOWN_MS) { this._send(me.ws, { t: 'chat', from: '', text: 'Wait a minute before calling another vote' }); return; }
    let target = 0;
    if (kind === 'kick') {
      target = Number(msg.target);
      const t = this.players.get(target);
      if (!t || target === me.id) return;
    }
    me.voteAt = now;
    this.vote = { kind, target, by: me.name, yes: new Set([me.id]), no: new Set(), ends: now + VOTE_MS };
    const what = kind === 'next' ? 'the next map' : kind === 'restart' ? 'this map again' : `kicking ${this.players.get(target).name}`;
    this._chat(`${me.name} calls a vote for ${what} (F1 yes, F2 no)`);
    this.broadcast({ t: 'vote', vote: this._voteInfo() });
    this._checkVote();
  }

  _checkVote() {
    if (!this.vote) return;
    const needed = this._needed();
    const voters = this.racers().length;
    if (this.vote.yes.size >= needed) this._closeVote(true);
    else if (this.vote.no.size > voters - needed) this._closeVote(false);
    else this.broadcast({ t: 'vote', vote: this._voteInfo() });
  }

  _closeVote(passed) {
    const v = this.vote;
    this.vote = null;
    this.broadcast({ t: 'vote', vote: null, passed });
    this._chat(passed ? 'The vote passed' : 'The vote failed');
    if (!passed) return;
    const now = this.now();
    if (v.kind === 'kick') {
      const t = this.players.get(v.target);
      if (t) { this._send(t.ws, { t: 'error', msg: 'kicked by a vote' }); t.ws.close(); }
      return;
    }
    const ev = v.kind === 'next' ? this.mode.skip(now) : this.mode.restart(now);
    if (ev === 'results') this._results();
    this.broadcast({ t: 'round', now, round: this.info() });
    this.broadcast({ t: 'players', players: this.playerList() });
  }
}

module.exports = { Game, VERSION };
