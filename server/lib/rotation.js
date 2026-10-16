'use strict';
// The LIVE room's playlist: which track and weather come next. Pure logic (tests seed the rng).
//
// Every track is played once per cycle, in a fresh shuffled order, never twice in a row across
// cycles. Round length follows the run length (aim: 6-12 attempts per round). The first weather in
// a track's list is its usual one; the others come up now and then (wet rounds keep it fresh).

const PLAYLIST = [
  { track: 'downtown', duration_s: 240, weathers: ['rain', 'storm', 'dry'] },
  { track: 'arena', duration_s: 240, weathers: ['dry', 'rain'] },
  { track: 'coast', duration_s: 240, weathers: ['dry', 'rain', 'storm'] },
  { track: 'infield', duration_s: 120, weathers: ['dry', 'rain'] },
  { track: 'dunes', duration_s: 120, weathers: ['dry'] },
  { track: 'rails', duration_s: 90, weathers: ['dry', 'rain'] },
  { track: 'rooftop', duration_s: 180, weathers: ['rain', 'dry', 'storm'] },
  { track: 'cliff', duration_s: 180, weathers: ['dry', 'rain'] },
  { track: 'twister', duration_s: 150, weathers: ['dry', 'rain'] },
  { track: 'pipes', duration_s: 150, weathers: ['dry', 'rain', 'storm'] },
  { track: 'frost', duration_s: 150, weathers: ['dry'] },
  { track: 'dust', duration_s: 150, weathers: ['dry', 'rain'] },
  { track: 'blackout', duration_s: 150, weathers: ['rain', 'dry'] },
  { track: 'glide', duration_s: 150, weathers: ['dry', 'rain'] },
  { track: 'techlab', duration_s: 150, weathers: ['dry', 'rain'] },
  { track: 'fullsend', duration_s: 180, weathers: ['dry', 'rain'] },
  { track: 'cruise', duration_s: 150, weathers: ['rain', 'dry'] },
  { track: 'plastic', duration_s: 150, weathers: ['dry'] },
  { track: 'sausage', duration_s: 120, weathers: ['dry', 'rain'] },
  { track: 'mixer', duration_s: 150, weathers: ['dry', 'rain'] },
  { track: 'platform', duration_s: 120, weathers: ['dry'] },
  { track: 'snake', duration_s: 150, weathers: ['rain', 'dry'] },
  { track: 'nosteer', duration_s: 120, weathers: ['dry'] },
  { track: 'canyon', duration_s: 180, weathers: ['dry', 'rain', 'storm'] },
  { track: 'icepipe', duration_s: 150, weathers: ['dry'] },
  { track: 'grassland', duration_s: 150, weathers: ['dry', 'rain'] },
  { track: 'skyline', duration_s: 150, weathers: ['rain', 'dry'] },
  { track: 'dropzone', duration_s: 120, weathers: ['dry', 'rain'] },
  { track: 'rally', duration_s: 180, weathers: ['dry', 'rain'] },
  { track: 'spiral', duration_s: 150, weathers: ['dry', 'rain'] },
];

const ALT_WEATHER_CHANCE = 0.25;

class Rotation {
  /**
   * @param {object} [o]
   * @param {Array<{track: string, duration_s: number, weathers: string[]}>} [o.playlist]
   * @param {() => number} [o.rng=Math.random]
   * @param {number} [o.durationS]  override every round's length (tests, LIVE_ROUND_S)
   */
  constructor(o = {}) {
    this.playlist = (o.playlist ?? PLAYLIST).filter((e) => e && e.track && e.weathers && e.weathers.length);
    if (this.playlist.length === 0) throw new Error('empty LIVE playlist');
    this.rng = o.rng ?? Math.random;
    this.durationS = o.durationS ?? 0;
    this.queue = [];
    this.lastTrack = '';
  }

  _refill() {
    const order = this.playlist.slice();
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(this.rng() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }
    // Don't repeat the track that just ended at the start of the new cycle.
    if (order.length > 1 && order[0].track === this.lastTrack) order.push(order.shift());
    for (const e of order) this.queue.push(this._round(e));
  }

  _round(e) {
    let weather = e.weathers[0];
    if (e.weathers.length > 1 && this.rng() < ALT_WEATHER_CHANCE) {
      weather = e.weathers[1 + Math.floor(this.rng() * (e.weathers.length - 1))];
    }
    return { track: e.track, weather, duration_s: this.durationS > 0 ? this.durationS : e.duration_s };
  }

  /** The round after the current one (stable until next() is called). */
  peek() {
    if (this.queue.length === 0) this._refill();
    return { ...this.queue[0] };
  }

  /** Take the next round: {track, weather, duration_s}. */
  next() {
    if (this.queue.length === 0) this._refill();
    const r = this.queue.shift();
    this.lastTrack = r.track;
    return { ...r };
  }
}

module.exports = { Rotation, PLAYLIST };
