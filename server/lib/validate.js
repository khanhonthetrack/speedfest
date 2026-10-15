'use strict';
// Input validation helpers. Every value that comes from a client goes through one of these.

const LIMITS = Object.freeze({
  MAX_FRAME_BYTES: 16 * 1024,     // larger text frames are ignored (error reply, connection kept)
  MAX_NAME: 16,
  MAX_ROOM_NAME: 24,
  MAX_CHAT: 200,
  MAX_CAR_JSON: 2048,             // CarConfig is ~600 bytes; anything bigger is dropped
  MAX_TRACK_ID: 24,
  MIN_DURATION_S: 1,
  MAX_DURATION_S: 3600,
  MAX_RUN_MS: 3600 * 1000,
  MAX_CP: 255,
  MAX_STATE_KEYS: 24,
});

// Control characters, zero-width/bidi overrides, and other invisible formatting characters.
const STRIP_RE = /[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁠-⁩﻿]/g;

/** Clean user-visible text: strip control/bidi chars, collapse whitespace, cut to maxLen code points. */
function cleanText(value, maxLen) {
  if (typeof value !== 'string') return '';
  let s = value.replace(STRIP_RE, '').replace(/\s+/g, ' ').trim();
  const cps = Array.from(s);
  if (cps.length > maxLen) s = cps.slice(0, maxLen).join('').trim();
  return s;
}

function isFiniteNumber(v) {
  return typeof v === 'number' && Number.isFinite(v);
}

function isInt(v, min, max) {
  return Number.isInteger(v) && v >= min && v <= max;
}

/** Accepts ints and integral floats (Godot's JSON emits 3.0 as 3, but be lenient). */
function toInt(v, min, max) {
  if (!isFiniteNumber(v)) return null;
  const n = Math.round(v);
  if (n < min || n > max) return null;
  return n;
}

function clamp(v, lo, hi) {
  return Math.min(hi, Math.max(lo, v));
}

function numArray(v, len, absMax) {
  if (!Array.isArray(v) || v.length !== len) return null;
  for (const x of v) {
    if (!isFiniteNumber(x) || Math.abs(x) > absMax) return null;
  }
  return v.slice();
}

/** Track ids are short lowercase slugs ("arena", "downtown", ...). */
function cleanTrackId(v) {
  if (typeof v !== 'string') return null;
  const s = v.trim().toLowerCase();
  if (s.length < 1 || s.length > LIMITS.MAX_TRACK_ID || !/^[a-z0-9_-]+$/.test(s)) return null;
  return s;
}

/** Car config is opaque to the server (clients run CarDefs.sanitize_config); keep it small. */
function cleanCarConfig(v) {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return null;
  let json;
  try {
    json = JSON.stringify(v);
  } catch {
    return null;
  }
  if (json.length > LIMITS.MAX_CAR_JSON) return null;
  return JSON.parse(json);
}

/** Car id string for leaderboards/results. */
function carIdOf(car) {
  if (car && typeof car === 'object' && typeof car.car === 'string') {
    const id = car.car.slice(0, 16);
    if (/^[a-z0-9_-]+$/i.test(id)) return id;
  }
  return '';
}

const STATE_SPEC = {
  t: (v) => toInt(v, -1, LIMITS.MAX_RUN_MS),
  p: (v) => numArray(v, 3, 1e6),
  q: (v) => numArray(v, 4, 2),
  v: (v) => numArray(v, 3, 1e4),
  st: (v) => (isFiniteNumber(v) ? clamp(v, -1, 1) : null),
  rpm: (v) => (isFiniteNumber(v) ? clamp(v, 0, 1.5) : null),
  fl: (v) => toInt(v, 0, 0xffff),
};

/**
 * Validate a state snapshot. Known fields are type-checked (a bad known field rejects the whole
 * snapshot). Unknown fields are passed through only when they are small primitives, so the client
 * can add fields later without a server change. Returns a clean object or null.
 */
function cleanState(msg) {
  const out = {};
  let keys = 0;
  for (const key of Object.keys(msg)) {
    if (key === 'type' || key === 'id') continue;
    if (++keys > LIMITS.MAX_STATE_KEYS) return null;
    const val = msg[key];
    const spec = STATE_SPEC[key];
    if (spec) {
      const clean = spec(val);
      if (clean === null) return null;
      out[key] = clean;
      continue;
    }
    if (key.length > 16) continue;
    if (typeof val === 'boolean' || (isFiniteNumber(val) && Math.abs(val) < 1e9)) {
      out[key] = val;
    } else if (typeof val === 'string' && val.length <= 32) {
      out[key] = val;
    } else if (Array.isArray(val) && val.length <= 8 && val.every((x) => isFiniteNumber(x) && Math.abs(x) < 1e9)) {
      out[key] = val.slice();
    }
  }
  if (!out.p) return null; // a snapshot without a position is useless
  return out;
}

module.exports = {
  LIMITS,
  cleanText,
  isFiniteNumber,
  isInt,
  toInt,
  clamp,
  cleanTrackId,
  cleanCarConfig,
  carIdOf,
  cleanState,
};
