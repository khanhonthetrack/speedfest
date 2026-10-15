'use strict';
// Test helpers: a promise-based WebSocket test client and small HTTP helpers.

const http = require('node:http');
const WebSocket = require('ws');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

class TestClient {
  static async open(url, opts = {}) {
    const c = new TestClient();
    await c._open(url, opts);
    return c;
  }

  _open(url, opts) {
    this.msgs = [];
    this.waiters = [];
    this.closed = false;
    this.closeCode = null;
    this.ws = new WebSocket(url, opts);
    this.ws.on('message', (data) => {
      let m;
      try {
        m = JSON.parse(data.toString());
      } catch {
        m = { type: '__raw__', data: data.toString() };
      }
      this.msgs.push(m);
      this._pump();
    });
    this.closedPromise = new Promise((resolve) => {
      this.ws.on('close', (code) => {
        this.closed = true;
        this.closeCode = code;
        resolve(code);
      });
    });
    return new Promise((resolve, reject) => {
      this.ws.once('open', resolve);
      this.ws.once('error', reject);
    });
  }

  _pump() {
    for (let i = 0; i < this.waiters.length; i++) {
      const w = this.waiters[i];
      const m = this.msgs.find((x) => !x.__used && x.type === w.type && w.pred(x));
      if (m) {
        m.__used = true;
        clearTimeout(w.timer);
        this.waiters.splice(i, 1);
        i--;
        w.resolve(m);
      }
    }
  }

  send(obj) {
    this.ws.send(typeof obj === 'string' || Buffer.isBuffer(obj) ? obj : JSON.stringify(obj));
  }

  /** Resolve with the oldest unconsumed message of `type` matching `pred` (waits up to timeout). */
  next(type, pred = () => true, timeout = 3000) {
    return new Promise((resolve, reject) => {
      const w = { type, pred, resolve };
      w.timer = setTimeout(() => {
        const i = this.waiters.indexOf(w);
        if (i >= 0) this.waiters.splice(i, 1);
        reject(new Error(`timeout waiting for "${type}" (got: ${this.msgs.map((m) => m.type).join(',')})`));
      }, timeout);
      this.waiters.push(w);
      this._pump();
    });
  }

  /** Wait for a room message matching pred (e.g. a phase). */
  room(pred = () => true, timeout = 3000) {
    return this.next('room', (m) => m.room !== null && pred(m.room), timeout).then((m) => m.room);
  }

  count(type, pred = () => true) {
    return this.msgs.filter((m) => m.type === type && pred(m)).length;
  }

  /** Mark everything received so far as consumed. */
  drain() {
    for (const m of this.msgs) m.__used = true;
  }

  async hello(name) {
    this.send({ type: 'hello', name, version: 1 });
    const w = await this.next('welcome');
    this.id = w.id;
    return w;
  }

  async ping() {
    const t = Date.now();
    this.send({ type: 'ping', t });
    return this.next('pong', (m) => m.t === t);
  }

  close() {
    if (!this.closed) this.ws.close();
    return this.closedPromise;
  }
}

/** Raw HTTP GET that does not normalize the path (for traversal tests). */
function request(port, path, { method = 'GET', headers = {} } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path, method, headers }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    });
    req.on('error', reject);
    req.end();
  });
}

module.exports = { TestClient, request, sleep };
