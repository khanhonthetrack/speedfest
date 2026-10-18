'use strict';
// Round logic of the SpeedFest Stadium online server, like a TMNF time-attack server: each round
// is one of the game's own tracks (SF01.., the files in stadium/tracks: every player has them)
// raced for ROUND_MS; players may restart any time and their best time counts; then RESULTS_MS of
// results and the next track, random but not one of the last few. TMNF_CAMPAIGN (A01..E05) is
// there for groups whose players all have TMNF installed. Pure logic (the clock is passed in),
// so the tests drive it without timers.

const fs = require('fs');
const path = require('path');

const TMNF_CAMPAIGN = [];
for (const [letter, count] of [['A', 15], ['B', 15], ['C', 15], ['D', 15], ['E', 5]]) {
  for (let i = 1; i <= count; i++) TMNF_CAMPAIGN.push(letter + String(i).padStart(2, '0'));
}

/** The game's campaign: stadium/tracks/campaign.json (the track ids in order: a list, or
 *  {"series": [{"name", "tracks": [..]}, ..]}, the series one after another); without it, the
 *  track files' names, sorted. */
function ownTracks(dir = path.join(__dirname, '..', '..', 'tracks')) {
  try {
    const listed = JSON.parse(fs.readFileSync(path.join(dir, 'campaign.json'), 'utf8'));
    if (Array.isArray(listed) && listed.length) return listed.map(String);
    if (listed && Array.isArray(listed.series)) {
      const ids = listed.series.flatMap((s) => (s && Array.isArray(s.tracks) ? s.tracks : [])).map(String);
      if (ids.length) return [...new Set(ids)];
    }
  } catch { /* no manifest: the files */ }
  try {
    return fs.readdirSync(dir).filter((f) => /^[A-Za-z0-9_-]+\.json$/.test(f) && f !== 'campaign.json')
      .map((f) => f.slice(0, -5)).sort();
  } catch {
    return [];
  }
}

const TRACKS = ownTracks();

class Rounds {
  constructor({ roundMs = 5 * 60 * 1000, resultsMs = 15 * 1000, tracks = TRACKS, recent = 12, random = Math.random } = {}) {
    if (!tracks.length) throw new Error('no tracks to race (stadium/tracks is empty?)');
    this.roundMs = roundMs;
    this.resultsMs = resultsMs;
    this.tracks = tracks.slice();
    this.recentMax = recent;
    this.recentSize = Math.min(recent, this.tracks.length - 1);
    this.random = random;
    this.recent = [];
    this.id = 0;
    this.state = 'race';
    this.track = '';
    this.start = 0;
    this.end = 0;
    this.best = new Map();        // player id -> {name, time}
  }

  _pick() {
    const pool = this.tracks.filter((t) => !this.recent.includes(t));
    const t = pool[Math.floor(this.random() * pool.length)];
    this.recent.push(t);
    while (this.recent.length > this.recentSize) this.recent.shift();
    return t;
  }

  /** A new rotation (an admin's): the next maps come from it; the current one plays on. */
  setTracks(tracks) {
    if (!tracks.length) return;
    this.tracks = tracks.slice();
    this.recentSize = Math.min(this.recentMax, this.tracks.length - 1);
    this.recent = this.recent.filter((t) => this.tracks.includes(t));
    while (this.recent.length > this.recentSize) this.recent.shift();
  }

  /** Starts the next race round at `now` (ms). */
  begin(now) {
    this.id += 1;
    this.state = 'race';
    this.track = this._pick();
    this.start = now;
    this.end = now + this.roundMs;
    this.best.clear();
    return this.info();
  }

  /** Moves the clock: 'results' when a race round ends, 'race' when the results are over. */
  tick(now) {
    if (this.state === 'race' && now >= this.end) {
      this.state = 'results';
      this.end = now + this.resultsMs;
      return 'results';
    }
    if (this.state === 'results' && now >= this.end) {
      this.begin(now);
      return 'race';
    }
    return null;
  }

  info() {
    return { id: this.id, track: this.track, state: this.state, start: this.start, end: this.end };
  }

  /** A finish: counts if it is this round's track, in the race, and the player's best. */
  finish(playerId, name, round, track, timeMs) {
    if (this.state !== 'race' || round !== this.id || track !== this.track) return false;
    if (!Number.isInteger(timeMs) || timeMs < 1000 || timeMs > this.roundMs + 60 * 1000) return false;
    const old = this.best.get(playerId);
    if (old && old.time <= timeMs) return false;
    this.best.set(playerId, { name, time: timeMs });
    return true;
  }

  forget(playerId) {
    this.best.delete(playerId);
  }

  /** This round's ranking: fastest first, ties by who set it first (insertion order). */
  ranking() {
    return [...this.best.entries()]
      .map(([id, b]) => ({ id, name: b.name, time: b.time }))
      .sort((a, b) => a.time - b.time);
  }
}

module.exports = { Rounds, TRACKS, TMNF_CAMPAIGN, ownTracks };
