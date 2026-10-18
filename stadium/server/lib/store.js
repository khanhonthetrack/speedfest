'use strict';
// The master server's small database: one JSON file (DATA_DIR/master.json) held in memory and
// written back atomically (a temporary file renamed over it) a moment after each change, and on
// close. Collections are plain objects keyed by id. Enough for a group of friends to a few thousand
// players; the owner's Raspberry Pi keeps it on a docker volume.

const fs = require('fs');
const path = require('path');

class Store {
  /** file: the JSON file ('' keeps everything in memory: tests). */
  constructor(file = '', { delayMs = 500 } = {}) {
    this.file = file;
    this.delayMs = delayMs;
    this.data = { accounts: {}, tokens: {}, records: {}, meta: { created: Date.now() } };
    this._timer = null;
    if (file && fs.existsSync(file)) {
      const loaded = JSON.parse(fs.readFileSync(file, 'utf8'));
      this.data = { ...this.data, ...loaded };
    }
  }

  /** A collection (created if missing). */
  table(name) {
    if (!this.data[name] || typeof this.data[name] !== 'object') this.data[name] = {};
    return this.data[name];
  }

  /** Marks the data changed: written back after delayMs. */
  changed() {
    if (!this.file || this._timer) return;
    this._timer = setTimeout(() => { this._timer = null; this.flush(); }, this.delayMs);
    if (this._timer.unref) this._timer.unref();
  }

  /** Writes the file now (atomically). */
  flush() {
    if (!this.file) return;
    if (this._timer) { clearTimeout(this._timer); this._timer = null; }
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.data));
    fs.renameSync(tmp, this.file);
  }

  close() {
    this.flush();
  }
}

module.exports = { Store };
