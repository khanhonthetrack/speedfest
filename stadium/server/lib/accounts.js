'use strict';
// Player accounts on the master server, as TMNF's: a login and a password (scrypt with a salt per
// account; never stored or logged in clear), a nickname with $-codes (TMNF's 75 characters), a
// zone (a path from stadium/data/zones.json: "World", "Europe", "Europe|France"), ladder points.
// Logging in gives a token (32 random bytes, kept 60 days; only its SHA-256 is stored) the game
// keeps instead of the password.

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const TOKEN_DAYS = 60;
const LADDER_START = 1000;
const LOGIN_RE = /^[a-z0-9_-]{3,20}$/;
const NICK_MAX = 75;
const PASSWORD_MIN = 8;

/** The zones players can pick: "World", each continent, each "Continent|Country". */
function loadZones(file = path.join(__dirname, '..', '..', 'data', 'zones.json')) {
  const zones = new Set(['World']);
  try {
    const d = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const [cont, countries] of Object.entries(d)) {
      zones.add(cont);
      for (const c of countries) zones.add(`${cont}|${c}`);
    }
  } catch { /* only World */ }
  return zones;
}

function cleanText(v, max) {
  if (typeof v !== 'string') return '';
  const s = v.replace(/[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁠-⁩﻿]/g, '')
    .replace(/\s+/g, ' ').trim();
  return Array.from(s).slice(0, max).join('').trim();
}

/** A nickname without its $-codes (TmNick.strip's rules), for checks and logs. */
function stripNick(nick) {
  let out = '';
  for (let i = 0; i < nick.length; i++) {
    const c = nick[i];
    if (c !== '$') { out += c; continue; }
    const k = (nick[i + 1] || '').toLowerCase();
    if (k === '$') { out += '$'; i += 1; continue; }
    if (/[0-9a-f]/.test(k)) {
      let n = 1;
      while (n < 3 && /[0-9a-f]/i.test(nick[i + 1 + n] || '')) n += 1;
      i += n;
      continue;
    }
    if ((k === 'l' || k === 'h') && nick[i + 2] === '[') {
      const close = nick.indexOf(']', i + 2);
      i = close >= 0 ? close : nick.length;
      continue;
    }
    i += 1;
  }
  return out;
}

function sha256(s) {
  return crypto.createHash('sha256').update(s).digest('hex');
}

function scrypt(password, salt) {
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 }, (err, key) => (err ? reject(err) : resolve(key.toString('hex'))));
  });
}

class Accounts {
  constructor(store, { zones = loadZones(), now = () => Date.now() } = {}) {
    this.store = store;
    this.zones = zones;
    this.now = now;
  }

  get table() { return this.store.table('accounts'); }
  get tokens() { return this.store.table('tokens'); }

  /** What anyone may see of an account. */
  view(a) {
    return a ? { login: a.login, nickname: a.nickname, zone: a.zone, ladder: Math.round(a.ladder), created: a.created } : null;
  }

  validZone(z) {
    return typeof z === 'string' && this.zones.has(z);
  }

  /** {login, password, nickname, zone} -> {account, token} or {error}. */
  async register(body = {}) {
    const login = String(body.login || '').trim().toLowerCase();
    if (!LOGIN_RE.test(login)) return { error: 'a login is 3 to 20 letters, digits, _ or -' };
    if (this.table[login]) return { error: 'that login is taken' };
    const password = typeof body.password === 'string' ? body.password : '';
    if (password.length < PASSWORD_MIN || password.length > 200) return { error: `a password has at least ${PASSWORD_MIN} characters` };
    const nickname = cleanText(body.nickname, NICK_MAX) || login;
    if (!stripNick(nickname).trim()) return { error: 'the nickname shows nothing without its codes' };
    const zone = this.validZone(body.zone) ? body.zone : 'World';
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = await scrypt(password, salt);
    if (this.table[login]) return { error: 'that login is taken' };
    const a = { login, salt, hash, nickname, zone, ladder: LADDER_START, created: this.now() };
    this.table[login] = a;
    this.store.changed();
    return { account: this.view(a), token: this.issue(login) };
  }

  /** {login, password} -> {account, token} or {error} (the same error for an unknown login). */
  async login(body = {}) {
    const login = String(body.login || '').trim().toLowerCase();
    const password = typeof body.password === 'string' ? body.password : '';
    const a = this.table[login];
    const hash = await scrypt(password, a ? a.salt : 'no-such-account');
    if (!a || !crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(a.hash, 'hex'))) return { error: 'wrong login or password' };
    return { account: this.view(a), token: this.issue(login) };
  }

  issue(login) {
    const token = crypto.randomBytes(32).toString('hex');
    this.tokens[sha256(token)] = { login, expires: this.now() + TOKEN_DAYS * 86400000 };
    this.store.changed();
    return token;
  }

  /** The account a token belongs to (null if none or expired). */
  byToken(token) {
    if (typeof token !== 'string' || token.length !== 64) return null;
    const t = this.tokens[sha256(token)];
    if (!t) return null;
    if (t.expires < this.now()) {
      delete this.tokens[sha256(token)];
      this.store.changed();
      return null;
    }
    return this.table[t.login] || null;
  }

  logout(token) {
    if (typeof token === 'string') delete this.tokens[sha256(token)];
    this.store.changed();
  }

  /** Changes a nickname and/or zone: {account} or {error}. */
  update(a, body = {}) {
    if (body.nickname !== undefined) {
      const nickname = cleanText(body.nickname, NICK_MAX);
      if (!stripNick(nickname).trim()) return { error: 'the nickname shows nothing without its codes' };
      a.nickname = nickname;
    }
    if (body.zone !== undefined) {
      if (!this.validZone(body.zone)) return { error: 'unknown zone' };
      a.zone = body.zone;
    }
    this.store.changed();
    return { account: this.view(a) };
  }
}

module.exports = { Accounts, loadZones, stripNick, cleanText, LADDER_START, NICK_MAX };
