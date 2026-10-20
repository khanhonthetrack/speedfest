'use strict';
// A TMNF track (.Challenge.Gbx) as the server checks it before putting it on a server: name,
// author, uid, environment, medal times, laps and the block list. The same reading as the game's
// gbx/tm_challenge.gd (our own reader of the public GBX format), so a track the server accepts
// is one the game reads.

const lzo = require('./lzo');

const CLASS_CHALLENGE = 0x03043000;
const FACADE = 0xFACADE01;
const PIKS = 0x534B4950;
// old class ids (TrackMania Original / Sunrise / Nations ESWC files, which TMNF still loads) -> TMNF's
// (from GBX.NET's public-domain WrapTMF table; only the classes a track body uses)
const WRAP = { 0x24003000: 0x03043000, 0x2400A000: 0x0301A000, 0x2400C000: 0x0305B000, 0x2403A000: 0x03059000, 0x2403C000: 0x0301B000 };
const remap = (id) => { const w = WRAP[(id & 0xFFFFF000) >>> 0]; return w ? (w | (id & 0xFFF)) >>> 0 : id; };
const COLLECTIONS = { 0: 'Desert', 1: 'Snow', 2: 'Rally', 3: 'Island', 4: 'Bay', 5: 'Coast', 6: 'Stadium', 7: 'Valley', 8: 'Speed',
  11: 'Alpine', 12: 'Rally', 13: 'Island', 14: 'Bay', 25: 'Stadium256', 26: 'Stadium', 10003: 'Common' };

class Stream {
  constructor(buf, at = 0) {
    this.data = buf;
    this.pos = at;
    this.error = '';
    this.ids = [];
    this.idsStarted = false;
    this.nodes = new Map();
  }

  ok() { return !this.error; }
  fail(why) { if (!this.error) this.error = `${why} (at byte ${this.pos})`; }
  remaining() { return this.data.length - this.pos; }
  need(n) {
    if (this.pos + n > this.data.length) { this.fail('unexpected end of data'); return false; }
    return true;
  }

  u8() { if (!this.need(1)) return 0; return this.data[this.pos++]; }
  u16() { if (!this.need(2)) return 0; this.pos += 2; return this.data.readUInt16LE(this.pos - 2); }
  u32() { if (!this.need(4)) return 0; this.pos += 4; return this.data.readUInt32LE(this.pos - 4); }
  i32() { if (!this.need(4)) return 0; this.pos += 4; return this.data.readInt32LE(this.pos - 4); }
  peekU32() { return this.pos + 4 <= this.data.length ? this.data.readUInt32LE(this.pos) : 0; }
  bytes(n) { if (!this.need(n)) return Buffer.alloc(0); this.pos += n; return this.data.subarray(this.pos - n, this.pos); }
  skip(n) { if (this.need(n)) this.pos += n; }

  string() {
    const n = this.u32();
    if (n > this.remaining()) { this.fail(`bad string length ${n}`); return ''; }
    return this.bytes(n).toString('utf8');
  }

  lookback() {
    if (!this.idsStarted) {
      const ver = this.u32();
      if (ver < 2) { this.fail(`lookback version ${ver}`); return ''; }
      this.idsStarted = true;
    }
    const v = this.u32();
    if (v === 0xFFFFFFFF || v === 0xFFFFFFFE) return '';   // unassigned (some editors write -2)
    if ((v & 0xC0000000) !== 0 && (v & 0x3FFFFFFF) === 0) {
      const s = this.string();
      this.ids.push(s);
      return s;
    }
    if ((v & 0xC0000000) === 0) return COLLECTIONS[v] || `#${v}`;
    const i = (v & 0x3FFFFFFF) - 1;
    if (i < 0 || i >= this.ids.length) { this.fail(`lookback index ${i} out of range`); return ''; }
    return this.ids[i];
  }

  ident() { return [this.lookback(), this.lookback(), this.lookback()]; }

  fileref() {
    const v = this.u8();
    if (v >= 3) this.skip(32);
    const p = this.string();
    if ((p.length > 0 && v >= 1) || v >= 3) this.string();
    return p;
  }
}

/** Reads a challenge: {error?, uid, name, author, environment, decoration, times: {bronze, silver,
 *  gold, author}, timeLimit, lapRace, laps, size: [x, y, z], blocks: [{name, dir, coord, flags,
 *  ground}]}. headerOnly: just the header (no blocks). */
function readChallenge(raw, { headerOnly = false } = {}) {
  const c = { error: '', uid: '', name: '', author: '', environment: '', decoration: '', vehicle: '',
    times: { bronze: -1, silver: -1, gold: -1, author: -1 }, timeLimit: -1, lapRace: false, laps: 0,
    size: [32, 32, 32], blocks: [], unlimiter: false };
  const s = new Stream(raw);
  if (s.bytes(3).toString('latin1') !== 'GBX') { c.error = 'not a GBX file'; return c; }
  const ver = s.u16();
  if (ver < 6) { c.error = `GBX version ${ver} not supported`; return c; }
  const fmt = s.bytes(4);
  const cls = remap(s.u32());
  if (cls !== CLASS_CHALLENGE) { c.error = `not a track (class ${cls.toString(16).toUpperCase()})`; return c; }
  const userSize = s.u32();
  if (userSize > 0) {
    const n = s.u32();
    if (n > 64) { c.error = 'bad header'; return c; }
    const entries = [];
    for (let i = 0; i < n; i++) entries.push([s.u32(), s.u32() & 0x7FFFFFFF]);
    for (const [cid, size] of entries) headerChunk(c, remap(cid), s.bytes(size));
  }
  if (!s.ok()) { c.error = s.error; return c; }
  if (headerOnly) return c;
  s.u32(); // number of nodes
  if (s.u32() !== 0) { c.error = 'external references are not supported'; return c; }
  let body;
  if (fmt.length >= 3 && fmt[2] === 0x43) { // 'C': LZO-compressed body
    const usize = s.u32();
    const csize = s.u32();
    body = lzo.decompress(s.bytes(csize), usize);
    if (!body) { c.error = 'LZO body failed to decompress'; return c; }
  } else {
    body = raw.subarray(s.pos);
  }
  if (!s.ok()) { c.error = s.error; return c; }
  const b = new Stream(body);
  const root = {};
  nodeBody(c, b, root);
  if (!b.ok()) c.error = `body: ${b.error}`;
  const params = root.params || {};
  if (params.times) [c.times.bronze, c.times.silver, c.times.gold, c.times.author] = params.times;
  if (params.timeLimit !== undefined) c.timeLimit = params.timeLimit;
  return c;
}

function headerChunk(c, cid, chunk) {
  const r = new Stream(chunk);
  if (cid === 0x03043002) {
    const v = r.u8();
    if (v < 3) { r.ident(); r.string(); }
    r.u32();
    if (v >= 1) {
      c.times = { bronze: r.i32(), silver: r.i32(), gold: r.i32(), author: r.i32() };
    }
  } else if (cid === 0x03043003) {
    r.u8();
    const id = r.ident();
    [c.uid, c.environment, c.author] = id;
    c.name = r.string();
    r.u8();
    r.u32();
    r.string();
    c.decoration = r.ident()[0];
  }
}

function nodeRef(c, b) {
  const idx = b.i32();
  if (idx === -1 || !b.ok()) return null;
  if (b.nodes.has(idx)) return b.nodes.get(idx);
  const node = { cls: remap(b.u32()) };
  b.nodes.set(idx, node);
  nodeBody(c, b, node);
  return node;
}

function nodeBody(c, b, node) {
  while (b.ok()) {
    const cid = remap(b.u32());
    if (cid === FACADE) return;
    if (b.peekU32() === PIKS) {
      b.u32();
      const sz = b.u32();
      const end = b.pos + sz;
      if (cid === 0x03043018) {
        c.lapRace = b.u32() !== 0;
        c.laps = b.u32();
      }
      if (end > b.data.length) { b.fail('skippable chunk past the end'); return; }
      b.pos = end;
      continue;
    }
    if (!chunk(c, b, cid, node)) return;
    if (cid === 0x0304301F || cid === 0x03043013) {
      // the rest of the body (media clips, ...) isn't needed, but TMUnlimiter's chunks say how to read the blocks
      // a TMUnlimiter 2 track: its block list is a placeholder (the name says it needs TMUnlimiter) and
      // the blocks are in Unlimiter's chunks (older Unlimiter tracks keep TMNF's list: TMNF loads them)
      if (c.blocks.length && /TMUnlimiter/i.test(c.blocks[0].name)) c.unlimiter = true;
      return;
    }
  }
}

function chunk(c, b, cid, node) {
  switch (cid) {
    case 0x0304300D: node.vehicle = b.ident(); c.vehicle = node.vehicle[0]; break;
    case 0x03043011:
      node.collectors = nodeRef(c, b);
      node.params = nodeRef(c, b);
      b.u32();
      break;
    case 0x0301B000: { const n = b.u32(); for (let i = 0; i < n && b.ok(); i++) { b.ident(); b.u32(); } break; }
    case 0x0305B000: b.skip(32); break;
    case 0x0305B001: for (let i = 0; i < 4; i++) b.string(); break;
    case 0x0305B004: node.times = [b.i32(), b.i32(), b.i32(), b.i32(), b.i32()]; break;
    case 0x0305B005: b.skip(12); break;
    case 0x0305B006: b.skip(4 * b.u32()); break;
    case 0x0305B008: node.timeLimit = b.i32(); b.i32(); break;
    case 0x0305B00D: nodeRef(c, b); break;
    case 0x03059000: node.text = b.string(); b.string(); break;
    case 0x03059001: node.text = b.string(); node.pack = b.fileref(); break;
    case 0x03059002: node.text = b.string(); node.pack = b.fileref(); b.fileref(); break;
    case 0x03059003: b.u32(); b.fileref(); break;
    case 0x2E009000: {
      const v = b.u32();
      if (v === 1) { b.u32(); node.order = b.u32(); } else if (v === 2) { node.tag = b.string(); node.order = b.u32(); }
      break;
    }
    case 0x0304301F: blocks(c, b); break;
    case 0x03043013: blocks(c, b, true); break;   // TrackMania PowerUp's block list: no version, the oldest layout
    default:
      b.fail(`unknown chunk ${cid.toString(16).toUpperCase().padStart(8, '0')}`);
      return false;
  }
  return true;
}

function blocks(c, b, legacy = false) {
  const id = b.ident();
  if (!c.uid) c.uid = id[0];
  const n2 = b.string();
  if (!c.name) c.name = n2;
  b.ident();
  c.size = [b.u32(), b.u32(), b.u32()];
  b.u32();
  const ver = legacy ? 0 : b.u32();
  b.u32(); // block count (free blocks are listed too)
  while (b.ok() && b.remaining() >= 4 && (b.peekU32() & 0xC0000000) !== 0) {
    const name = b.lookback();
    const dir = b.u8();
    const coord = [b.u8(), b.u8(), b.u8()];
    const flags = ver === 0 ? b.u16() : b.u32();
    const blk = { name, dir, coord, flags, ground: (flags & 0x1000) !== 0 };
    if (flags !== 0xFFFFFFFF && ((ver === 0 && flags !== 0xFFFF) || ver !== 0)) {
      if (flags & 0x8000) {
        b.lookback();
        nodeRef(c, b);
      }
      // bit 20: a waypoint's special property, from version 2 of the list (version 1's bit is unrelated)
      if (ver >= 2 && (flags & 0x100000)) nodeRef(c, b);
    }
    c.blocks.push(blk);
    if (c.blocks.length > 200000) { b.fail('too many blocks'); return; }
  }
}

/** A minimal uncompressed TMNF track (tests): header chunks 002/003 and a block list. */
function writeChallenge({ uid = 'TestUid000000000000000000', name = 'Test', author = 'tester', environment = 'Stadium',
  times = [60000, 50000, 45000, 40000], blocks: list = [], size = [32, 32, 32], compress = false } = {}) {
  const u32 = (v) => { const x = Buffer.alloc(4); x.writeUInt32LE(v >>> 0); return x; };
  const str = (t) => { const x = Buffer.from(t, 'utf8'); return Buffer.concat([u32(x.length), x]); };
  const ids = () => { const seen = []; let started = false; return (t) => {
    const head = started ? [] : [u32(3)];
    started = true;
    if (t === '') return Buffer.concat([...head, u32(0xFFFFFFFF)]);
    const i = seen.indexOf(t);
    if (i >= 0) return Buffer.concat([...head, u32((0x40000000 | (i + 1)) >>> 0)]);
    seen.push(t);
    return Buffer.concat([...head, u32(0x40000000), str(t)]);
  }; };
  const h2 = Buffer.concat([Buffer.from([4]), u32(0), ...times.map(u32), u32(0)]);
  const id3 = ids();
  const h3 = Buffer.concat([Buffer.from([5]), id3(uid), id3(environment), id3(author), str(name), Buffer.from([0]), u32(0), str(''),
    id3('Day'), id3(environment), id3('Nadeo')]);
  const bid = ids();
  const body = [u32(0x0304301F), bid(uid), bid(environment), bid(author), str(name), bid('Day'), bid(environment), bid('Nadeo'),
    u32(size[0]), u32(size[1]), u32(size[2]), u32(0), u32(1), u32(list.length)];
  for (const k of list) {
    body.push(bid(k.name), Buffer.from([k.dir || 0, ...(k.coord || [0, 1, 0])]), u32(k.flags !== undefined ? k.flags : (k.ground ? 0x1000 : 0)));
  }
  body.push(u32(0x03043022), u32(1), u32(FACADE)); // the next chunk ends the block list
  let bodyBuf = Buffer.concat(body);
  const head = [Buffer.from('GBX', 'latin1'), Buffer.from([6, 0]), Buffer.from(compress ? 'BUCR' : 'BUUR', 'latin1'), u32(CLASS_CHALLENGE)];
  const user = Buffer.concat([u32(2), u32(0x03043002), u32(h2.length), u32(0x03043003), u32(h3.length), h2, h3]);
  head.push(u32(user.length), user, u32(1), u32(0));
  if (compress) {
    const z = lzo.literals(bodyBuf);
    head.push(u32(bodyBuf.length), u32(z.length));
    bodyBuf = z;
  }
  return Buffer.concat([...head, bodyBuf]);
}

module.exports = { readChallenge, writeChallenge, CLASS_CHALLENGE, Stream };
