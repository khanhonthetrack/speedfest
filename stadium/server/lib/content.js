'use strict';
// Community content on a server: tracks (.Challenge.Gbx, e.g. from TrackMania Exchange) and car
// packs (TMNF skins and car models as .zip, e.g. from ManiaPark) that a server's admins upload.
// Each file is checked before it is kept: a track must read like the game reads it
// (lib/gbx.js), be a Stadium track, use only Stadium blocks and have a start and a finish; a car
// pack must hold a car (a mesh or a skin texture), and is repacked with only what the game uses
// (meshes, textures, sounds), so players download less. Files are stored by their SHA-256 under
// DATA_DIR/content and served at /content/<sha256>.<ext> (they never change); the index lives
// in the master's store (tables "tracks" and "cars").

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const gbx = require('./gbx');
const zip = require('./zip');
const { cleanText } = require('./accounts');

const TRACK_MAX = 32 * 1024 * 1024;
const CAR_MAX = 128 * 1024 * 1024;
const CAR_UNPACKED_MAX = 160 * 1024 * 1024;
const TRACK_EXT = '.Challenge.Gbx';
const CAR_EXT = '.zip';
const SITES = { tmnf: 'https://tmnf.exchange', tmuf: 'https://tmuf.exchange', tmn: 'https://nations.tm-exchange.com' };
const UA = 'SpeedFestStadium-server/1.0 (+https://github.com/khanhonthetrack/speedfest)';
// what a car pack may keep: meshes, textures and sounds, at its root or in Engine/
const CAR_FILE_RE = /^(?:engine\/)?[a-z0-9 _.()+-]+\.(?:gbx|dds|tga|png|jpe?g|bmp|wav|ogg|txt)$/i;

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

/** The Stadium block catalogue the game builds from (stadium/blocks/data/block_catalogue.json):
 *  block id -> waypoint (0 start, 1 finish, 2 checkpoint, 3 none, 4 start/finish line). */
function loadCatalogue(file = path.join(__dirname, '..', '..', 'blocks', 'data', 'block_catalogue.json')) {
  const out = new Map();
  try {
    const d = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const [id, e] of Object.entries(d)) out.set(id, Number(e.waypoint !== undefined ? e.waypoint : 3));
  } catch { /* no catalogue: blocks aren't checked */ }
  return out;
}

/** Checks a track file: {track: {uid, name, author, ...}} or {error}. */
function checkTrack(buf, catalogue) {
  if (!Buffer.isBuffer(buf) || buf.length < 32) return { error: 'empty file' };
  if (buf.length > TRACK_MAX) return { error: 'the track file is too big' };
  const c = gbx.readChallenge(buf);
  if (c.error) return { error: `not a track the game can read: ${c.error}` };
  if (c.environment && c.environment !== 'Stadium') return { error: `a ${c.environment} track: this game races Stadium tracks` };
  if (!/^[A-Za-z0-9_.-]{1,80}$/.test(c.uid)) return { error: 'the track has no usable uid' };
  if (c.unlimiter) return { error: 'a TMUnlimiter track: its blocks are in TMUnlimiter\'s own format, which this server can\'t read yet' };
  const unknown = new Set();
  let starts = 0; let finishes = 0; let checkpoints = 0; let lines = 0; let placed = 0;
  for (const b of c.blocks) {
    if (b.flags === 0xFFFFFFFF) continue;
    placed += 1;
    if (catalogue.size && !catalogue.has(b.name)) { unknown.add(b.name); continue; }
    const wp = catalogue.get(b.name);
    if (wp === 0) starts += 1;
    else if (wp === 1) finishes += 1;
    else if (wp === 2) checkpoints += 1;
    else if (wp === 4) lines += 1;
  }
  if (unknown.size) {
    return { error: `blocks that aren't TMNF Stadium blocks (a modded track: custom or other environments' blocks): ${[...unknown].slice(0, 8).join(', ')}` };
  }
  if (catalogue.size && !starts && !lines) return { error: 'the track has no start' };
  if (catalogue.size && !finishes && !lines) return { error: 'the track has no finish' };
  return { track: { uid: c.uid, name: cleanText(c.name, 120) || c.uid, author: cleanText(c.author, 80), blocks: placed,
    checkpoints, lap_race: c.lapRace || (lines > 0 && !finishes), laps: c.lapRace ? c.laps : (lines > 0 && !finishes ? Math.max(1, c.laps) : 1),
    times: c.times, size: c.size } };
}

/** Checks and repacks a car pack: {car: {name, files, mesh, skin, sounds}, data (the repacked zip)}
 *  or {error}. */
function checkCar(buf, name = '') {
  if (!Buffer.isBuffer(buf) || buf.length < 22) return { error: 'empty file' };
  if (buf.length > CAR_MAX) return { error: 'the car file is too big' };
  const l = zip.list(buf);
  if (l.error) return { error: `not a car pack: ${l.error}` };
  let entries = l.entries.filter((e) => !e.name.endsWith('/') && e.size > 0);
  // a pack zipped with its folder: drop the common leading folder (but keep Engine/)
  const firstDir = (n) => (n.includes('/') ? n.slice(0, n.indexOf('/') + 1) : '');
  const prefix = entries.length ? firstDir(entries[0].name) : '';
  if (prefix && prefix.toLowerCase() !== 'engine/' && entries.every((e) => e.name.startsWith(prefix))) {
    entries = entries.map((e) => ({ ...e, short: e.name.slice(prefix.length) }));
  } else {
    entries = entries.map((e) => ({ ...e, short: e.name }));
  }
  const keep = entries.filter((e) => CAR_FILE_RE.test(e.short) && !e.short.startsWith('.'));
  if (keep.reduce((s, e) => s + e.size, 0) > CAR_UNPACKED_MAX) return { error: 'the car pack unpacks too big' };
  const files = [];
  const seen = new Set();
  for (const e of keep) {
    const key = e.short.toLowerCase();
    if (seen.has(key)) continue;
    const data = zip.read(buf, e);
    if (!data) return { error: `can't unpack ${e.short} (encrypted or an unsupported compression)` };
    seen.add(key);
    files.push({ name: e.short, data });
  }
  const has = (re) => files.some((f) => re.test(f.name));
  const mesh = has(/^mainbody(high)?\.solid\.gbx$/i);
  const skin = has(/^diffuse\.(dds|tga|png|jpe?g|bmp)$/i);
  if (!mesh && !skin) return { error: 'no car in the pack: it needs MainBody.Solid.Gbx (a car model) or Diffuse.dds (a skin)' };
  for (const f of files) {
    if (/\.gbx$/i.test(f.name) && (f.data.length < 17 || f.data.toString('latin1', 0, 3) !== 'GBX')) {
      return { error: `${f.name} isn't a GBX file` };
    }
  }
  if (mesh) {
    const m = files.find((f) => /^mainbody(high)?\.solid\.gbx$/i.test(f.name));
    if (m.data.readUInt32LE(9) !== 0x09005000) return { error: `${m.name} isn't a TMNF car mesh (CPlugSolid)` };
  }
  files.sort((a, b) => a.name.localeCompare(b.name));
  return { car: { name: cleanText(name, 80), files: files.map((f) => f.name), mesh, skin,
    sounds: files.some((f) => /\.(wav|ogg)$/i.test(f.name)) }, data: zip.write(files) };
}

/** A TrackMania Exchange track's download address from what an admin pasted: an id (TMNF-X),
 *  tmnf:<id>, tmuf:<id>, or a TMX page/download link. */
function tmxUrl(text) {
  const t = String(text || '').trim();
  let m = t.match(/^(?:(tmnf|tmuf|tmn):)?(\d{1,10})$/i);
  if (m) return `${SITES[(m[1] || 'tmnf').toLowerCase()]}/trackgbx/${m[2]}`;
  m = t.match(/^https?:\/\/(tmnf\.exchange|tmuf\.exchange|nations\.tm-exchange\.com)\/(?:trackshow|trackgbx|tracks?(?:\/download)?|s\/tr)\/(\d{1,10})/i);
  if (m) return `https://${m[1].toLowerCase()}/trackgbx/${m[2]}`;
  m = t.match(/^https?:\/\/(?:www\.)?(tmnf|tmuf)\.tm-exchange\.com\/.*[?&]id=(\d{1,10})/i);
  if (m) return `${SITES[m[1].toLowerCase()]}/trackgbx/${m[2]}`;
  return '';
}

/** A ManiaPark car's download address from what an admin pasted: a skin/model page or download
 *  link, or skin:<id> / model:<id>. */
function maniaparkUrl(text) {
  const t = String(text || '').trim();
  let m = t.match(/^(skin|model):([A-Za-z0-9_-]{6,40})$/i);
  if (m) return `https://maniapark.com/${m[1].toLowerCase()}/${m[2]}/download`;
  m = t.match(/^https?:\/\/(?:www\.)?maniapark\.com\/(skin|model)\/([A-Za-z0-9_-]{6,40})/i);
  if (m) return `https://maniapark.com/${m[1].toLowerCase()}/${m[2]}/download`;
  return '';
}

async function download(url, max, fetchFn) {
  const res = await fetchFn(url, { headers: { 'user-agent': UA }, redirect: 'follow' });
  if (!res.ok) return { error: `${new URL(url).host} answered ${res.status}` };
  const len = Number(res.headers.get('content-length') || 0);
  if (len > max) return { error: 'the file is too big' };
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length > max) return { error: 'the file is too big' };
  const disp = String(res.headers.get('content-disposition') || '');
  const fm = disp.match(/filename\*=UTF-8''([^;]+)/i) || disp.match(/filename="?([^";]+)"?/i);
  return { data: buf, filename: fm ? decodeURIComponent(fm[1]) : '' };
}

class Content {
  /** store: the master's Store; dir: where files live ('' keeps them in memory: tests). */
  constructor(store, dir = '', { now = () => Date.now(), fetch: fetchFn = globalThis.fetch, catalogue = loadCatalogue() } = {}) {
    this.store = store;
    this.dir = dir;
    this.now = now;
    this.fetch = fetchFn;
    this.catalogue = catalogue;
    this.memory = new Map();       // sha -> Buffer (no dir)
    if (dir) fs.mkdirSync(dir, { recursive: true });
  }

  get tracks() { return this.store.table('tracks'); }
  get cars() { return this.store.table('cars'); }

  _put(sha, ext, data) {
    if (!this.dir) { this.memory.set(sha + ext, data); return; }
    const file = path.join(this.dir, sha + ext);
    if (!fs.existsSync(file)) {
      fs.writeFileSync(`${file}.tmp`, data);
      fs.renameSync(`${file}.tmp`, file);
    }
  }

  _drop(sha, ext) {
    if (!this.dir) { this.memory.delete(sha + ext); return; }
    try { fs.unlinkSync(path.join(this.dir, sha + ext)); } catch { /* already gone */ }
  }

  /** A stored file's bytes by its published name (<sha256>.<ext>), or null. */
  file(name) {
    if (!/^[0-9a-f]{64}(\.Challenge\.Gbx|\.zip)$/.test(name)) return null;
    if (!this.dir) return this.memory.get(name) || null;
    try { return fs.readFileSync(path.join(this.dir, name)); } catch { return null; }
  }

  /** Adds (or replaces, by uid) a track: {track} or {error}. source: {site, id} if imported. */
  addTrack(buf, { by = '', source = null } = {}) {
    const r = checkTrack(buf, this.catalogue);
    if (r.error) return r;
    const sha = sha256(buf);
    const old = this.tracks[r.track.uid];
    this._put(sha, TRACK_EXT, buf);
    if (old && old.sha256 !== sha && !Object.values(this.tracks).some((t) => t !== old && t.sha256 === old.sha256)) this._drop(old.sha256, TRACK_EXT);
    const track = { ...r.track, sha256: sha, size: buf.length, url: `/content/${sha}${TRACK_EXT}`, source, by, added: this.now() };
    this.tracks[track.uid] = track;
    this.store.changed();
    return { track, replaced: !!old };
  }

  removeTrack(uid) {
    const t = this.tracks[uid];
    if (!t) return false;
    delete this.tracks[uid];
    this._drop(t.sha256, TRACK_EXT);
    this.store.changed();
    return true;
  }

  /** Adds a car pack: {car} or {error}. Its id is the repacked file's hash (16 hex digits). */
  addCar(buf, { name = '', by = '', source = null } = {}) {
    const r = checkCar(buf, name);
    if (r.error) return r;
    const sha = sha256(r.data);
    const id = sha.slice(0, 16);
    this._put(sha, CAR_EXT, r.data);
    const car = { id, ...r.car, name: r.car.name || `Car ${id.slice(0, 6)}`, sha256: sha, size: r.data.length,
      url: `/content/${sha}${CAR_EXT}`, source, by, added: this.now() };
    this.cars[id] = car;
    this.store.changed();
    return { car };
  }

  removeCar(id) {
    const c = this.cars[id];
    if (!c) return false;
    delete this.cars[id];
    this._drop(c.sha256, CAR_EXT);
    this.store.changed();
    return true;
  }

  /** Downloads a track from TrackMania Exchange and adds it. */
  async importTrack(text, opts = {}) {
    const url = tmxUrl(text);
    if (!url) return { error: 'give a TrackMania Exchange track id or link (tmnf.exchange or tmuf.exchange)' };
    let d;
    try { d = await download(url, TRACK_MAX, this.fetch); } catch (e) { return { error: `TrackMania Exchange can't be reached (${e.message})` }; }
    if (d.error) return d;
    const host = new URL(url).host;
    return this.addTrack(d.data, { ...opts, source: { site: host, id: url.split('/').pop(), url } });
  }

  /** Downloads a car from ManiaPark and adds it (its name: the one given, else the file's). */
  async importCar(text, opts = {}) {
    const url = maniaparkUrl(text);
    if (!url) return { error: 'give a ManiaPark skin or model link (maniapark.com/skin/<id> or /model/<id>)' };
    let d;
    try { d = await download(url, CAR_MAX, this.fetch); } catch (e) { return { error: `ManiaPark can't be reached (${e.message})` }; }
    if (d.error) return d;
    const name = opts.name || d.filename.replace(/\.zip$/i, '');
    const parts = url.split('/');
    return this.addCar(d.data, { ...opts, name, source: { site: 'maniapark.com', kind: parts[3], id: parts[4], url: url.replace(/\/download$/, '') } });
  }

  /** What players may know of a track or car. */
  static view(item) {
    if (!item) return null;
    const { by, ...rest } = item;
    return rest;
  }
}

module.exports = { Content, checkTrack, checkCar, tmxUrl, maniaparkUrl, loadCatalogue, TRACK_EXT, CAR_EXT };
