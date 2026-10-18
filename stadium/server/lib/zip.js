'use strict';
// Just enough of the ZIP format for car packs (ManiaPark's TMNF skins and models): reading the
// central directory and its stored or deflated entries, and writing a new archive. Node's zlib
// does the deflating; nothing else is needed.

const zlib = require('zlib');

const MAX_ENTRY = 128 * 1024 * 1024;

/** The entries of a ZIP archive: [{name, size, csize, method, offset}] or {error}. */
function list(buf) {
  // the end of central directory record: within the last 64 KiB + 22 bytes
  let eocd = -1;
  for (let i = buf.length - 22; i >= Math.max(0, buf.length - 65557); i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) return { error: 'not a zip file' };
  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  const out = [];
  for (let i = 0; i < count; i++) {
    if (p + 46 > buf.length || buf.readUInt32LE(p) !== 0x02014b50) return { error: 'broken zip directory' };
    const flags = buf.readUInt16LE(p + 8);
    const method = buf.readUInt16LE(p + 10);
    const csize = buf.readUInt32LE(p + 20);
    const size = buf.readUInt32LE(p + 24);
    const nlen = buf.readUInt16LE(p + 28);
    const xlen = buf.readUInt16LE(p + 30);
    const clen = buf.readUInt16LE(p + 32);
    const offset = buf.readUInt32LE(p + 42);
    const raw = buf.subarray(p + 46, p + 46 + nlen);
    // names are CP437 unless flag 11 says UTF-8; TMNF packs use ASCII names
    const name = (flags & 0x800 ? raw.toString('utf8') : raw.toString('latin1')).replace(/\\/g, '/');
    out.push({ name, size, csize, method, offset, encrypted: !!(flags & 1) });
    p += 46 + nlen + xlen + clen;
  }
  return { entries: out };
}

/** An entry's bytes (Buffer) or null (unsupported method, encrypted, broken). */
function read(buf, e) {
  if (e.encrypted || e.size > MAX_ENTRY || e.offset + 30 > buf.length || buf.readUInt32LE(e.offset) !== 0x04034b50) return null;
  const start = e.offset + 30 + buf.readUInt16LE(e.offset + 26) + buf.readUInt16LE(e.offset + 28);
  const data = buf.subarray(start, start + e.csize);
  try {
    if (e.method === 0) return data.length === e.size ? Buffer.from(data) : null;
    if (e.method === 8) {
      const out = zlib.inflateRawSync(data, { maxOutputLength: MAX_ENTRY });
      return out.length === e.size ? out : null;
    }
  } catch { /* broken data */ }
  return null;
}

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

/** A ZIP archive (Buffer) of [{name, data}], deflated (stored when that is smaller). */
function write(files) {
  const locals = [];
  const central = [];
  let offset = 0;
  for (const f of files) {
    const name = Buffer.from(f.name, 'utf8');
    const deflated = zlib.deflateRawSync(f.data, { level: 6 });
    const stored = deflated.length >= f.data.length;
    const body = stored ? f.data : deflated;
    const crc = crc32(f.data);
    const h = Buffer.alloc(30);
    h.writeUInt32LE(0x04034b50, 0);
    h.writeUInt16LE(20, 4);
    h.writeUInt16LE(0x800, 6);
    h.writeUInt16LE(stored ? 0 : 8, 8);
    h.writeUInt32LE(0x00210000, 10); // 1980-01-01 00:00
    h.writeUInt32LE(crc, 14);
    h.writeUInt32LE(body.length, 18);
    h.writeUInt32LE(f.data.length, 22);
    h.writeUInt16LE(name.length, 26);
    locals.push(h, name, body);
    const c = Buffer.alloc(46);
    c.writeUInt32LE(0x02014b50, 0);
    c.writeUInt16LE(20, 4);
    c.writeUInt16LE(20, 6);
    c.writeUInt16LE(0x800, 8);
    c.writeUInt16LE(stored ? 0 : 8, 10);
    c.writeUInt32LE(0x00210000, 12);
    c.writeUInt32LE(crc, 16);
    c.writeUInt32LE(body.length, 20);
    c.writeUInt32LE(f.data.length, 24);
    c.writeUInt16LE(name.length, 28);
    c.writeUInt32LE(offset, 42);
    central.push(c, name);
    offset += 30 + name.length + body.length;
  }
  const dir = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(dir.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, dir, end]);
}

module.exports = { list, read, write, crc32 };
