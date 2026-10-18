'use strict';
// LZO1X decompression (the stream format of lzo1x_1 / lzo1x_999, used by GBX bodies): our own
// implementation of the public algorithm, the same as the game's gbx/lzo1x.gd.

/** Decompresses `src` (Buffer) into exactly `outLen` bytes; null on malformed input. */
function decompress(input, outLen) {
  const n = input.length;
  if (n === 0 || outLen <= 0 || outLen > 256 * 1024 * 1024) return null;
  // zero padding so a truncated stream fails the checks below instead of reading past the end
  const src = Buffer.concat([input, Buffer.alloc(8)]);
  const dst = Buffer.alloc(outLen);
  let op = 0;
  let ip = 0;
  let t = 0;
  let state = 0; // 0 loop, 1 first literal run, 2 match, 3 match done
  const copyLit = (len) => {
    if (op + len > outLen || ip + len > n) return false;
    src.copy(dst, op, ip, ip + len);
    op += len;
    ip += len;
    return true;
  };
  if (src[0] > 17) {
    t = src[0] - 17;
    ip = 1;
    if (!copyLit(t)) return null;
    if (t < 4) { t = src[ip++]; state = 2; } else state = 1;
  }
  for (;;) {
    if (ip >= n) return null;
    if (state === 0) {
      t = src[ip++];
      if (t >= 16) { state = 2; continue; }
      if (t === 0) {
        while (ip < n && src[ip] === 0) { t += 255; ip++; }
        t += 15 + src[ip++];
      }
      if (!copyLit(t + 3)) return null;
      state = 1;
    } else if (state === 1) {
      t = src[ip++];
      if (t >= 16) { state = 2; continue; }
      const mPos = op - (1 + 0x0800) - (t >> 2) - (src[ip++] << 2);
      if (mPos < 0 || op + 3 > outLen) return null;
      for (let k = 0; k < 3; k++) dst[op++] = dst[mPos + k];
      state = 3;
    } else if (state === 2) {
      let mPos = 0;
      let length = 0;
      if (t >= 64) {
        mPos = op - 1 - ((t >> 2) & 7) - (src[ip++] << 3);
        length = (t >> 5) + 1;
      } else if (t >= 32) {
        t &= 31;
        if (t === 0) {
          while (ip < n && src[ip] === 0) { t += 255; ip++; }
          t += 31 + src[ip++];
        }
        mPos = op - 1 - (src[ip] >> 2) - (src[ip + 1] << 6);
        ip += 2;
        length = t + 2;
      } else if (t >= 16) {
        mPos = op - ((t & 8) << 11);
        t &= 7;
        if (t === 0) {
          while (ip < n && src[ip] === 0) { t += 255; ip++; }
          t += 7 + src[ip++];
        }
        mPos -= (src[ip] >> 2) + (src[ip + 1] << 6);
        ip += 2;
        if (mPos === op) break; // end of stream
        mPos -= 0x4000;
        length = t + 2;
      } else {
        mPos = op - 1 - (t >> 2) - (src[ip++] << 2);
        length = 2;
      }
      if (mPos < 0 || op + length > outLen) return null;
      for (let k = 0; k < length; k++) dst[op++] = dst[mPos + k];
      state = 3;
    } else {
      t = src[ip - 2] & 3;
      if (t === 0) { state = 0; continue; }
      if (!copyLit(t)) return null;
      t = src[ip++];
      state = 2;
    }
  }
  return op === outLen ? dst : null;
}

/** A valid LZO1X stream that holds `data` as one literal run (no compression): for tests and
 *  for writing GBX bodies without a compressor. */
function literals(data) {
  const parts = [];
  if (data.length <= 238) {
    parts.push(Buffer.from([17 + data.length]));
  } else {
    let t = data.length - 3 - 15;
    const head = [0];
    while (t > 255) { head.push(0); t -= 255; }
    head.push(t);
    parts.push(Buffer.from(head));
  }
  parts.push(data, Buffer.from([0x11, 0, 0]));
  return Buffer.concat(parts);
}

module.exports = { decompress, literals };
