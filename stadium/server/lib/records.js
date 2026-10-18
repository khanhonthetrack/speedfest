'use strict';
// Online records per track, as TMNF kept them: each account's best time on each track (the
// track's uid, which changes with its layout), with when it was set; the world's best and a zone's
// best lists, and where a player stands. Times come from logged-in players' finishes (solo
// campaign runs and the official servers' rounds).

const { inZone } = require('./ladder');

const MAX_TIME = 60 * 60 * 1000;
const UID_RE = /^[A-Za-z0-9_.-]{1,80}$/;

class Records {
  constructor(store, accounts, { now = () => Date.now() } = {}) {
    this.store = store;
    this.accounts = accounts;
    this.now = now;
  }

  get table() { return this.store.table('records'); }

  /** A finish: {improved, time (the account's best), rank (world)}; or {error}. */
  submit(track, login, time) {
    if (!UID_RE.test(String(track))) return { error: 'bad track' };
    if (!Number.isInteger(time) || time <= 0 || time > MAX_TIME) return { error: 'bad time' };
    const t = this.table[track] || (this.table[track] = {});
    const prev = t[login];
    const improved = !prev || time < prev.time;
    if (improved) {
      t[login] = { time, at: this.now() };
      this.store.changed();
    }
    return { improved, time: t[login].time, rank: this.rank(track, login) };
  }

  /** The best times on a track in a zone: [{login, nickname, zone, time, at}]. */
  top(track, zone = 'World', limit = 10) {
    const t = this.table[track] || {};
    const accounts = this.accounts.table;
    return Object.entries(t)
      .filter(([login]) => accounts[login] && inZone(accounts[login].zone, zone))
      .map(([login, r]) => ({ login, nickname: accounts[login].nickname, zone: accounts[login].zone, time: r.time, at: r.at }))
      .sort((a, b) => (a.time - b.time) || (a.at - b.at))
      .slice(0, Math.max(1, Math.min(100, limit)));
  }

  /** A login's place on a track (1 = the record; 0 = no time). */
  rank(track, login, zone = 'World') {
    const t = this.table[track] || {};
    if (!t[login]) return 0;
    const accounts = this.accounts.table;
    const mine = t[login];
    let better = 0;
    for (const [l, r] of Object.entries(t)) {
      if (l === login || !accounts[l] || !inZone(accounts[l].zone, zone)) continue;
      if (r.time < mine.time || (r.time === mine.time && r.at < mine.at)) better += 1;
    }
    return better + 1;
  }

  count(track) {
    return Object.keys(this.table[track] || {}).length;
  }
}

module.exports = { Records };
