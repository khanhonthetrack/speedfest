'use strict';
// The game modes of a SpeedFest server, TMNF's four, as pure logic (the clock is passed in, so the
// tests drive them without timers). Every mode has the same face for lib/game.js:
//   begin(now), tick(now) -> null | 'race' | 'results', info(), join(id, name, login),
//   leave(id), finish(id, round, track, time) -> bool, standings(), ranked() -> [{login, time}] |
//   null (a ladder round just ended), skip(now) (next map), restart(now) (this map again),
//   setTracks(ids) (an admin's rotation, from the next map), jump(now, id) (an admin's: that map now).
//
// - TimeAttack: a map for a time limit, everyone races as often as they like, the best time counts
//   (lib/rounds.js), then results and the next map.
// - Rounds: everyone starts together (start = now + START_DELAY, so every game counts down to the
//   same moment); one finish each; the round ends when all who started have finished (or left),
//   FINISH_TIMEOUT after the first finish, or at the round's limit; points by place (TMNF's 10 6 4
//   3 2 1); the map ends when someone has the points limit or after max rounds; then the next map.
// - Team: Rounds for two teams (0 blue, 1 red, new players join the smaller one): each finisher
//   scores (racers - place + 1), the team with more wins the round and a point; first to the limit.
// - Laps: one race per map, started together (the track's own laps; the client counts them).

const { Rounds, TRACKS } = require('./rounds');

const START_DELAY = 3000;
const FINISH_TIMEOUT = 15000;
const ROUND_POINTS = [10, 6, 4, 3, 2, 1];

class TimeAttack {
  constructor({ roundMs = 5 * 60 * 1000, resultsMs = 15 * 1000, tracks = TRACKS, random = Math.random } = {}) {
    this.name = 'TimeAttack';
    this.r = new Rounds({ roundMs, resultsMs, tracks, random });
    this.logins = new Map();      // id -> login
    this.names = new Map();
    this._ranked = null;
  }

  begin(now) { return this.r.begin(now); }

  tick(now) {
    const ev = this.r.tick(now);
    if (ev === 'results') {
      this._ranked = this.r.ranking().filter((x) => this.logins.get(x.id)).map((x) => ({ login: this.logins.get(x.id), time: x.time }));
    }
    return ev;
  }

  info() { return { mode: this.name, ...this.r.info() }; }

  join(id, name, login) {
    this.names.set(id, name);
    if (login) this.logins.set(id, login);
  }

  leave(id) {
    this.names.delete(id);
    this.logins.delete(id);
  }

  finish(id, round, track, time) { return this.r.finish(id, this.names.get(id) || '', round, track, time); }

  standings() { return this.r.ranking().map((x) => ({ id: x.id, name: x.name, time: x.time })); }

  ranked() {
    const out = this._ranked;
    this._ranked = null;
    return out && out.length >= 2 ? out : null;
  }

  skip(now) {
    this.r.state = 'results';
    this.r.end = now;
    return this.tick(now);
  }

  restart(now) {
    const track = this.r.track;
    this.r.begin(now);
    this.r.track = track;
    return 'race';
  }

  /** An admin's new rotation (from the next map on). */
  setTracks(tracks) { this.r.setTracks(tracks); }

  /** An admin's jump: `track` now, a fresh round on it. */
  jump(now, track) {
    this.r.begin(now);
    this.r.recent.pop();
    this.r.recent.push(track);
    this.r.track = track;
    return 'race';
  }
}

class RoundsMode {
  constructor({ team = false, laps = false, tracks = TRACKS, random = Math.random, pointsLimit, maxRounds,
    roundLimitMs = 5 * 60 * 1000, roundResultsMs = 6000, mapResultsMs = 15000, startDelay = START_DELAY,
    finishTimeout = FINISH_TIMEOUT } = {}) {
    if (!tracks.length) throw new Error('no tracks to race');
    this.team = team;
    this.laps = laps;
    this.name = team ? 'Team' : laps ? 'Laps' : 'Rounds';
    this.tracks = tracks.slice();
    this.random = random;
    this.pointsLimit = pointsLimit || (team ? 5 : 50);
    this.maxRounds = laps ? 1 : (maxRounds || (team ? 9 : 8));
    this.roundLimitMs = laps ? 2 * roundLimitMs : roundLimitMs;
    this.roundResultsMs = roundResultsMs;
    this.mapResultsMs = mapResultsMs;
    this.startDelay = startDelay;
    this.finishTimeout = finishTimeout;
    this.recent = [];
    this.id = 0;                  // round id (unique on the server)
    this.map = 0;                 // map number
    this.number = 0;              // round number on this map
    this.track = '';
    this.state = 'race';
    this.start = 0;
    this.end = 0;
    this.finishEnd = 0;           // FINISH_TIMEOUT after the first finish (0: none yet)
    this.mapOver = false;
    this.players = new Map();     // id -> {name, login, team}
    this.racers = new Set();      // ids racing this round (there at its start)
    this.times = new Map();       // id -> finish time this round
    this.points = new Map();      // id -> points on this map (Rounds; Team: what the player scored for the team)
    this.teamPoints = [0, 0];
    this.lastRound = [];          // the last round's places [{id, name, time, points}]
    this.lastTeams = null;        // the last round's team scores [blue, red] (Team)
    this._ranked = null;
  }

  _pick() {
    const recentSize = Math.min(12, this.tracks.length - 1);
    const pool = this.tracks.filter((t) => !this.recent.includes(t));
    const t = pool[Math.floor(this.random() * pool.length)];
    this.recent.push(t);
    while (this.recent.length > recentSize) this.recent.shift();
    return t;
  }

  /** A new map (its first round). */
  begin(now) {
    this.map += 1;
    this.track = this._pick();
    this.number = 0;
    this.points.clear();
    this.teamPoints = [0, 0];
    this.mapOver = false;
    return this._round(now);
  }

  _round(now) {
    this.id += 1;
    this.number += 1;
    this.state = 'race';
    this.start = now + this.startDelay;
    this.end = this.start + this.roundLimitMs;
    this.finishEnd = 0;
    this.times.clear();
    this.racers = new Set(this.players.keys());
    return this.info();
  }

  info() {
    return { mode: this.name, id: this.id, map: this.map, number: this.number, track: this.track, state: this.state,
      start: this.start, end: this.finishEnd ? Math.min(this.end, this.finishEnd) : this.end, synced: true,
      points_limit: this.pointsLimit, max_rounds: this.maxRounds, team_points: this.team ? this.teamPoints : undefined,
      map_over: this.state === 'results' ? this.mapOver : undefined };
  }

  /** A player joins (now: they race this round if it hasn't started yet). */
  join(id, name, login, now = Infinity) {
    let team = 0;
    if (this.team) {
      const blue = [...this.players.values()].filter((p) => p.team === 0).length;
      team = blue > this.players.size - blue ? 1 : 0;
    }
    this.players.set(id, { name, login, team });
    if (this.state === 'race' && now <= this.start) this.racers.add(id);
  }

  leave(id) {
    this.players.delete(id);
    this.racers.delete(id);
  }

  teamOf(id) {
    const p = this.players.get(id);
    return p ? p.team : -1;
  }

  /** A finish (race time from the synced start): one per racer per round. */
  finish(id, round, track, time) {
    if (this.state !== 'race' || round !== this.id || track !== this.track) return false;
    if (!this.racers.has(id) || this.times.has(id)) return false;
    if (!Number.isInteger(time) || time < 1000 || time > this.roundLimitMs + 60000) return false;
    this.times.set(id, time);
    return true;
  }

  tick(now) {
    if (this.state === 'race') {
      if (this.times.size && !this.finishEnd) this.finishEnd = now + this.finishTimeout;
      const live = [...this.racers].filter((id) => this.players.has(id));
      const allIn = live.length > 0 && live.every((id) => this.times.has(id));
      if (allIn || now >= this.end || (this.finishEnd && now >= this.finishEnd) || (live.length === 0 && now >= this.start + 5000)) {
        this._score();
        this.state = 'results';
        this.end = now + (this.mapOver ? this.mapResultsMs : this.roundResultsMs);
        return 'results';
      }
      return null;
    }
    if (this.state === 'results' && now >= this.end) {
      if (this.mapOver) this.begin(now);
      else this._round(now);
      return 'race';
    }
    return null;
  }

  /** The round's places and points; the map's end. */
  _score() {
    const places = [...this.times.entries()].sort((a, b) => a[1] - b[1]);
    const racers = [...this.racers].filter((id) => this.players.has(id)).length;
    this.lastRound = places.map(([id, time], i) => {
      const pts = this.team ? Math.max(racers - i, 1) : (ROUND_POINTS[i] || (this.laps ? 0 : 1));
      if (!this.laps) this.points.set(id, (this.points.get(id) || 0) + pts);
      return { id, name: (this.players.get(id) || {}).name || '', time, points: pts };
    });
    this.lastTeams = null;
    if (this.team) {
      const score = [0, 0];
      for (const r of this.lastRound) {
        const t = this.teamOf(r.id);
        if (t >= 0) score[t] += r.points;
      }
      this.lastTeams = score;
      if (score[0] !== score[1]) this.teamPoints[score[0] > score[1] ? 0 : 1] += 1;
    }
    const best = this.team ? Math.max(...this.teamPoints) : Math.max(0, ...this.points.values());
    this.mapOver = this.laps || best >= this.pointsLimit || this.number >= this.maxRounds;
    // the ladder: a Laps race by its places, Rounds and Team at the map's end by the map's points
    if (this.laps) {
      this._ranked = places.map(([id, time]) => ({ login: (this.players.get(id) || {}).login, time })).filter((x) => x.login);
    } else if (this.mapOver) {
      // by the map's points; on a team map the winning team's players first
      const won = this.teamPoints[0] === this.teamPoints[1] ? -1 : (this.teamPoints[0] > this.teamPoints[1] ? 0 : 1);
      const order = this.standings().sort((a, b) => (this.team ? (b.team === won) - (a.team === won) : 0) || (b.points - a.points));
      this._ranked = order.map((x, i) => ({ login: (this.players.get(x.id) || {}).login, time: i + 1 })).filter((x) => x.login);
    }
  }

  /** The map's standings: by points (Rounds), team then points (Team), the last race (Laps). */
  standings() {
    if (this.laps) return this.lastRound.map((r) => ({ id: r.id, name: r.name, time: r.time }));
    const rows = [...this.players.entries()].map(([id, p]) => ({ id, name: p.name, points: this.points.get(id) || 0,
      team: this.team ? p.team : undefined }));
    return rows.sort((a, b) => b.points - a.points);
  }

  ranked() {
    const out = this._ranked;
    this._ranked = null;
    return out && out.length >= 2 ? out : null;
  }

  skip(now) {
    this.mapOver = true;
    this.state = 'results';
    this.end = now;
    return this.tick(now);
  }

  restart(now) {
    const track = this.track;
    this.begin(now);
    this.recent.pop();
    this.track = track;
    return 'race';
  }

  /** An admin's new rotation (from the next map on). */
  setTracks(tracks) {
    if (!tracks.length) return;
    this.tracks = tracks.slice();
    this.recent = this.recent.filter((t) => this.tracks.includes(t));
    while (this.recent.length > Math.min(12, this.tracks.length - 1)) this.recent.shift();
  }

  /** An admin's jump: `track` now, a new map on it. */
  jump(now, track) {
    this.begin(now);
    this.recent.pop();
    this.recent.push(track);
    this.track = track;
    return 'race';
  }
}

/** A mode by name: TimeAttack, Rounds, Team, Laps. */
function makeMode(name, opts = {}) {
  switch (name) {
    case 'Rounds': return new RoundsMode(opts);
    case 'Team': return new RoundsMode({ ...opts, team: true });
    case 'Laps': return new RoundsMode({ ...opts, laps: true });
    default: return new TimeAttack(opts);
  }
}

module.exports = { makeMode, TimeAttack, RoundsMode, ROUND_POINTS, START_DELAY, FINISH_TIMEOUT };
