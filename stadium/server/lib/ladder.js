'use strict';
// Ladder points, in the spirit of TMNF's ladder: a ranked round moves points between its
// finishers, from those who finished behind to those ahead, more when the one ahead had fewer
// points (Elo: for each pair, the one ahead gains K x (1 - expected), the one behind loses the
// same; K = 32 / (finishers - 1), so a round moves about as much as one game of chess). Players who
// didn't finish rank behind every finisher. Everyone starts at 1000 (accounts.LADDER_START).
// Rankings: by points, the world or a zone (a zone path and the zones inside it).

const K_TOTAL = 32;

/** Points for a ranked round. ranking: [{login, time}] (time -1: no finish), any order; accounts:
 *  login -> account (with .ladder). Returns login -> delta (rounded to 0.1), and applies it. */
function applyRound(ranking, accounts) {
  const rows = ranking.filter((r) => accounts[r.login]);
  if (rows.length < 2) return {};
  const finished = (r) => typeof r.time === 'number' && r.time > 0;
  rows.sort((a, b) => (finished(b) - finished(a)) || (finished(a) ? a.time - b.time : 0));
  const k = K_TOTAL / (rows.length - 1);
  const delta = Object.fromEntries(rows.map((r) => [r.login, 0]));
  for (let i = 0; i < rows.length; i++) {
    for (let j = i + 1; j < rows.length; j++) {
      const a = rows[i];
      const b = rows[j];
      if (!finished(a) && !finished(b)) continue;            // two non-finishers: no result between them
      if (finished(a) && finished(b) && a.time === b.time) continue;
      const ra = accounts[a.login].ladder;
      const rb = accounts[b.login].ladder;
      const expected = 1 / (1 + 10 ** ((rb - ra) / 400));
      const d = k * (1 - expected);
      delta[a.login] += d;
      delta[b.login] -= d;
    }
  }
  for (const [login, d] of Object.entries(delta)) {
    accounts[login].ladder = Math.max(0, accounts[login].ladder + d);
    delta[login] = Math.round(d * 10) / 10;
  }
  return delta;
}

/** True when a zone path is the zone or inside it ("Europe" holds "Europe|France"). */
function inZone(accountZone, zone) {
  if (!zone || zone === 'World') return true;
  return accountZone === zone || String(accountZone).startsWith(`${zone}|`);
}

/** Accounts by points (then by login), in a zone. */
function ranking(accounts, zone = 'World') {
  return Object.values(accounts).filter((a) => inZone(a.zone, zone))
    .sort((a, b) => (b.ladder - a.ladder) || (a.login < b.login ? -1 : 1));
}

/** An account's place (1 = first) in its world and its zone and its continent. */
function ranks(accounts, a) {
  const place = (zone) => ranking(accounts, zone).findIndex((x) => x.login === a.login) + 1;
  const continent = String(a.zone).split('|')[0];
  return { world: place('World'), zone: place(a.zone), continent: continent !== 'World' ? place(continent) : 0,
    players: Object.keys(accounts).length };
}

module.exports = { applyRound, ranking, ranks, inZone };
