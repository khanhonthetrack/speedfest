'use strict';
// Rooms, players and the Time Attack round flow. Pure game-state logic: it knows nothing about
// HTTP. server.js feeds it WebSocket connections and frames. See docs/ARCHITECTURE.md
// "Network protocol" for the message reference.

const crypto = require('node:crypto');
const { log, warn } = require('./log');
const V = require('./validate');

const PROTOCOL_VERSION = 1;
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ'; // no I, L, O (ambiguous with 1/0)
const ACTIVE_PHASES = new Set(['countdown', 'racing']);

// Outbound buffering limits per client (bytes). Lossy messages (state) are skipped above the soft
// limit; a client whose buffer grows past the hard limit is considered dead and dropped.
const SOFT_BUFFER = 256 * 1024;
const HARD_BUFFER = 8 * 1024 * 1024;
const FINISH_CLOCK_SLACK_MS = 3000;
// A client whose main loop runs pings every 2 s (net.gd PING_INTERVAL_MS). Silence longer than this
// means a paused web tab (hidden/minimized: requestAnimationFrame stops). We stop relaying lossy
// state to it, so its inbound packet queue (4096 in Godot's web WebSocket) isn't filled by state
// frames and the reliable room/round_end/round_start messages still get through.
const STALE_RX_MS = 5000;

class TokenBucket {
  constructor(ratePerSec, burst, now) {
    this.rate = ratePerSec;
    this.burst = burst;
    this.tokens = burst;
    this.last = now;
  }

  take(now) {
    this.tokens = Math.min(this.burst, this.tokens + ((now - this.last) * this.rate) / 1000);
    this.last = now;
    if (this.tokens >= 1) {
      this.tokens -= 1;
      return true;
    }
    return false;
  }
}

class Client {
  constructor(id, ws, ip, now) {
    this.id = id;
    this.ws = ws;
    this.ip = ip;
    this.name = `Racer${id}`;
    this.car = null;
    this.hello = false;
    this.version = 0;
    this.room = null;
    // per-room state (reset on join / round start)
    this.ready = false;
    this.best_ms = -1;
    this.best_at = 0;
    this.runs = 0;
    // liveness + limits
    this.missed = 0;
    this.lastRx = now; // last application message received (ws pongs don't count: browsers auto-answer them)
    this.msgBucket = new TokenBucket(120, 120, now);
    this.stateBucket = new TokenBucket(40, 10, now); // <= 40/s sustained
    this.chatBucket = new TokenBucket(1, 5, now);
    this.errorBucket = new TokenBucket(2, 6, now);
  }
}

class Room {
  constructor(code, name, now) {
    this.code = code;
    this.name = name;
    this.hostId = -1;
    this.phase = 'lobby';
    this.settings = { track: 'arena', duration_s: 300 };
    this.players = []; // Client[], join order (host migration picks players[0])
    this.roundCounter = 0;
    this.round = { round_id: 0, track: 'arena', duration_s: 300, start_at: 0, end_at: 0 };
    this.finalized = true; // round_end sent for the current round
    this.phaseEndAt = 0;
    this.timer = null;
    this.departed = new Map(); // name -> standings entry of players who left mid-round
    this.createdAt = now;
  }
}

class Lobby {
  /**
   * @param {object} o
   * @param {number} [o.countdownMs=4000]  countdown before GO
   * @param {number} [o.resultsMs=12000]   time from round end (end_at) back to lobby
   * @param {number} [o.finishGraceMs=1500] finishes are accepted until end_at + this; round_end follows
   * @param {number} [o.maxPlayers=8]
   * @param {number} [o.maxRooms=200]
   * @param {number} [o.maxClients=500]
   * @param {() => number} [o.now=Date.now]
   */
  constructor(o = {}) {
    this.countdownMs = o.countdownMs ?? 4000;
    this.finishGraceMs = o.finishGraceMs ?? 1500;
    this.resultsMs = Math.max(o.resultsMs ?? 12000, this.finishGraceMs + 250);
    this.maxPlayers = o.maxPlayers ?? 8;
    this.maxRooms = o.maxRooms ?? 200;
    this.maxClients = o.maxClients ?? 500;
    this.now = o.now ?? Date.now;
    this.clients = new Map();
    this.rooms = new Map();
    this.nextId = 1;
    this.handlers = {
      hello: this._onHello,
      ping: this._onPing,
      list_rooms: this._onListRooms,
      create_room: this._onCreateRoom,
      join_room: this._onJoinRoom,
      leave_room: this._onLeaveRoom,
      profile: this._onProfile,
      ready: this._onReady,
      settings: this._onSettings,
      start: this._onStart,
      state: this._onState,
      cp: this._onCheckpoint,
      finish: this._onFinish,
      chat: this._onChat,
    };
  }

  stats() {
    return { rooms: this.rooms.size, players: this.clients.size };
  }

  // --- connections -----------------------------------------------------------------------------

  addClient(ws, ip = '?') {
    if (this.clients.size >= this.maxClients) return null;
    const c = new Client(this.nextId++, ws, ip, this.now());
    this.clients.set(c.id, c);
    return c;
  }

  removeClient(c, why = 'closed') {
    if (!this.clients.has(c.id)) return;
    this._leaveRoom(c);
    this.clients.delete(c.id);
    if (c.hello) log(`- ${c.name} #${c.id} left (${why}); online ${this.clients.size}`);
  }

  /** Called every heartbeat interval: ping everyone, drop clients that missed 2 pings. */
  heartbeat() {
    for (const c of this.clients.values()) {
      if (c.missed >= 2) {
        log(`x ${c.name} #${c.id} timed out (no pong)`);
        try {
          c.ws.terminate();
        } catch {
          /* ignore */
        }
        this.removeClient(c, 'timeout');
        continue;
      }
      c.missed++;
      try {
        c.ws.ping();
      } catch {
        /* ignore */
      }
    }
  }

  /** The client answered a ws ping (or sent anything): it is alive. */
  alive(c) {
    c.missed = 0;
  }

  shutdown() {
    for (const room of this.rooms.values()) this._clearTimer(room);
  }

  /** Entry point for every inbound frame. Never throws. */
  onMessage(c, data, isBinary) {
    try {
      this.alive(c);
      const now = this.now();
      c.lastRx = now;
      if (!c.msgBucket.take(now)) return; // flood: drop silently
      if (isBinary) return this._error(c, 'Binary frames are not supported', 'bad_frame');
      const size = typeof data === 'string' ? Buffer.byteLength(data) : data.length;
      if (size > V.LIMITS.MAX_FRAME_BYTES) return this._error(c, 'Message too large', 'too_large');
      let msg;
      try {
        msg = JSON.parse(typeof data === 'string' ? data : data.toString('utf8'));
      } catch {
        return this._error(c, 'Invalid JSON', 'bad_json');
      }
      if (!msg || typeof msg !== 'object' || Array.isArray(msg) || typeof msg.type !== 'string') {
        return this._error(c, 'Invalid message', 'bad_message');
      }
      const handler = Object.prototype.hasOwnProperty.call(this.handlers, msg.type) ? this.handlers[msg.type] : null;
      if (!handler) return this._error(c, `Unknown message type "${String(msg.type).slice(0, 24)}"`, 'unknown_type');
      if (!c.hello && msg.type !== 'hello' && msg.type !== 'ping') {
        return this._error(c, 'Send hello first', 'no_hello');
      }
      handler.call(this, c, msg, now);
    } catch (err) {
      warn(`handler error for #${c.id}:`, err && err.stack ? err.stack : err);
    }
  }

  // --- sending ---------------------------------------------------------------------------------

  _sendRaw(c, text, lossy = false) {
    const ws = c.ws;
    if (!ws || ws.readyState !== 1) return;
    if (ws.bufferedAmount > HARD_BUFFER) {
      log(`x ${c.name} #${c.id} dropped (outbound buffer full)`);
      try {
        ws.terminate();
      } catch {
        /* ignore */
      }
      return;
    }
    if (lossy && ws.bufferedAmount > SOFT_BUFFER) return;
    try {
      ws.send(text);
    } catch {
      /* socket closing; close handler cleans up */
    }
  }

  _send(c, obj) {
    this._sendRaw(c, JSON.stringify(obj));
  }

  _broadcast(room, obj, except = null, lossy = false) {
    const text = JSON.stringify(obj);
    const now = lossy ? this.now() : 0;
    for (const p of room.players) {
      if (p === except) continue;
      if (lossy && now - p.lastRx > STALE_RX_MS) continue; // paused web tab: don't flood its queue
      this._sendRaw(p, text, lossy);
    }
  }

  _error(c, message, code = 'error') {
    if (!c.errorBucket.take(this.now())) return;
    this._send(c, { type: 'error', message, code });
  }

  // --- views -----------------------------------------------------------------------------------

  _roomJSON(room) {
    return {
      code: room.code,
      name: room.name,
      host: room.hostId,
      phase: room.phase,
      settings: { track: room.settings.track, duration_s: room.settings.duration_s },
      players: room.players.map((p) => ({
        id: p.id,
        name: p.name,
        car: p.car || {},
        ready: p.ready,
        best_ms: p.best_ms,
        runs: p.runs,
      })),
      round: {
        round_id: room.round.round_id,
        track: room.round.track,
        duration_s: room.round.duration_s,
        start_at: room.round.start_at,
        end_at: room.round.end_at,
      },
      max_players: this.maxPlayers,
      phase_end_at: room.phaseEndAt,
      server_t: this.now(),
    };
  }

  _roomSummary(room) {
    const host = room.players.find((p) => p.id === room.hostId);
    return {
      code: room.code,
      name: room.name,
      players: room.players.length,
      phase: room.phase,
      track: room.settings.track,
      max_players: this.maxPlayers,
      host_name: host ? host.name : '',
    };
  }

  _roundStartMsg(room) {
    return {
      type: 'round_start',
      round_id: room.round.round_id,
      track: room.round.track,
      duration_s: room.round.duration_s,
      start_at: room.round.start_at,
      end_at: room.round.end_at,
      server_t: this.now(),
    };
  }

  /** Standings: best time ascending, DNF (-1) last, ties broken by who set it first. */
  _standings(room) {
    const rows = room.players.map((p) => ({
      id: p.id,
      name: p.name,
      car: V.carIdOf(p.car),
      best_ms: p.best_ms,
      runs: p.runs,
      _at: p.best_at,
    }));
    for (const d of room.departed.values()) rows.push({ ...d });
    rows.sort((a, b) => {
      const ad = a.best_ms < 0;
      const bd = b.best_ms < 0;
      if (ad !== bd) return ad ? 1 : -1;
      if (!ad && a.best_ms !== b.best_ms) return a.best_ms - b.best_ms;
      if (!ad && a._at !== b._at) return a._at - b._at;
      return a.name.localeCompare(b.name);
    });
    return rows.map(({ _at, ...rest }) => rest);
  }

  _broadcastRoom(room) {
    this._broadcast(room, { type: 'room', room: this._roomJSON(room) });
  }

  // --- room membership -------------------------------------------------------------------------

  _genCode() {
    for (let i = 0; i < 2000; i++) {
      let code = '';
      for (let k = 0; k < 4; k++) code += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
      if (!this.rooms.has(code)) return code;
    }
    return null;
  }

  _roundOpen(room) {
    return room.phase !== 'lobby' && !room.finalized;
  }

  _addToRoom(c, room) {
    c.room = room;
    c.ready = false;
    c.best_ms = -1;
    c.best_at = 0;
    c.runs = 0;
    // A player who dropped mid-round and rejoins under the same name keeps their times.
    if (this._roundOpen(room) && room.departed.has(c.name)) {
      const d = room.departed.get(c.name);
      room.departed.delete(c.name);
      c.best_ms = d.best_ms;
      c.best_at = d._at || 0;
      c.runs = d.runs;
    }
    room.players.push(c);
  }

  _leaveRoom(c) {
    const room = c.room;
    if (!room) return false;
    c.room = null;
    const idx = room.players.indexOf(c);
    if (idx >= 0) room.players.splice(idx, 1);
    let foldedIntoLive = false;
    if (this._roundOpen(room) && c.runs > 0) {
      const better = (bms, bat, ams, aat) => bms >= 0 && (ams < 0 || bms < ams || (bms === ams && bat < aat));
      const live = room.players.find((p) => p.name === c.name);
      if (live) {
        // Same racer reconnected (e.g. page reload) before this old socket was reaped: carry the times over.
        if (better(c.best_ms, c.best_at, live.best_ms, live.best_at)) {
          live.best_ms = c.best_ms;
          live.best_at = c.best_at;
        }
        live.runs += c.runs;
        foldedIntoLive = true;
      } else {
        const prev = room.departed.get(c.name);
        const e = { id: c.id, name: c.name, car: V.carIdOf(c.car), best_ms: c.best_ms, runs: c.runs, left: true, _at: c.best_at };
        if (prev) {
          e.runs += prev.runs;
          if (better(prev.best_ms, prev._at, e.best_ms, e._at)) {
            e.best_ms = prev.best_ms;
            e._at = prev._at;
          }
        }
        room.departed.set(c.name, e);
      }
    }
    c.ready = false;
    c.best_ms = -1;
    c.runs = 0;
    if (room.players.length === 0) {
      this._clearTimer(room);
      this.rooms.delete(room.code);
      log(`  room ${room.code} closed (empty); rooms ${this.rooms.size}`);
      return true;
    }
    if (room.hostId === c.id) {
      room.hostId = room.players[0].id;
      log(`  room ${room.code}: host -> ${room.players[0].name} #${room.hostId}`);
    }
    this._broadcast(room, { type: 'left', id: c.id });
    this._broadcastRoom(room);
    if (foldedIntoLive) {
      this._broadcast(room, { type: 'leaderboard', round_id: room.round.round_id, entries: this._standings(room) });
    }
    return true;
  }

  _requireHost(c) {
    if (!c.room) {
      this._error(c, 'Not in a room', 'no_room');
      return null;
    }
    if (c.room.hostId !== c.id) {
      this._error(c, 'Only the host can do that', 'not_host');
      return null;
    }
    return c.room;
  }

  // --- round flow ------------------------------------------------------------------------------

  _clearTimer(room) {
    if (room.timer) clearTimeout(room.timer);
    room.timer = null;
  }

  _schedule(room, atMs, fn) {
    this._clearTimer(room);
    const delay = Math.max(0, atMs - this.now());
    room.timer = setTimeout(() => {
      room.timer = null;
      if (this.rooms.get(room.code) !== room) return; // room was deleted
      try {
        fn.call(this, room);
      } catch (err) {
        warn(`room ${room.code} timer error:`, err && err.stack ? err.stack : err);
      }
    }, delay);
  }

  _startRound(room) {
    const now = this.now();
    room.roundCounter++;
    const startAt = now + this.countdownMs;
    room.round = {
      round_id: room.roundCounter,
      track: room.settings.track,
      duration_s: room.settings.duration_s,
      start_at: startAt,
      end_at: startAt + room.settings.duration_s * 1000,
    };
    room.finalized = false;
    room.departed.clear();
    for (const p of room.players) {
      p.best_ms = -1;
      p.best_at = 0;
      p.runs = 0;
    }
    room.phase = 'countdown';
    room.phaseEndAt = startAt;
    this._broadcastRoom(room);
    this._broadcast(room, this._roundStartMsg(room));
    log(`> room ${room.code}: round ${room.round.round_id} on ${room.round.track} for ${room.round.duration_s}s, ${room.players.length} player(s)`);
    this._schedule(room, startAt, this._toRacing);
  }

  _toRacing(room) {
    room.phase = 'racing';
    room.phaseEndAt = room.round.end_at;
    this._broadcastRoom(room);
    this._schedule(room, room.round.end_at, this._toResults);
  }

  _toResults(room) {
    room.phase = 'results';
    room.phaseEndAt = room.round.end_at + this.resultsMs;
    this._broadcastRoom(room);
    // Finishes in flight are still accepted for finishGraceMs; then the results are final.
    this._schedule(room, room.round.end_at + this.finishGraceMs, this._finalizeRound);
  }

  _finalizeRound(room) {
    room.finalized = true;
    const results = this._standings(room);
    this._broadcast(room, { type: 'round_end', round_id: room.round.round_id, results });
    const top = results
      .filter((r) => r.best_ms >= 0)
      .slice(0, 3)
      .map((r) => `${r.name} ${(r.best_ms / 1000).toFixed(3)}s`)
      .join(', ');
    log(`< room ${room.code}: round ${room.round.round_id} over. ${top || 'no finishes'}`);
    this._schedule(room, room.phaseEndAt, this._toLobby);
  }

  _toLobby(room) {
    room.phase = 'lobby';
    room.phaseEndAt = 0;
    room.departed.clear();
    for (const p of room.players) p.ready = false;
    this._broadcastRoom(room);
  }

  // --- handlers --------------------------------------------------------------------------------

  _onHello(c, m, now) {
    const name = V.cleanText(m.name, V.LIMITS.MAX_NAME);
    if (name) c.name = name;
    c.version = V.toInt(m.version, 0, 1e6) ?? 0;
    const first = !c.hello;
    c.hello = true;
    this._send(c, {
      type: 'welcome',
      id: c.id,
      server_t: now,
      version: PROTOCOL_VERSION,
      max_players: this.maxPlayers,
    });
    if (first) {
      const vnote = c.version !== PROTOCOL_VERSION ? ` (client protocol v${c.version}, server v${PROTOCOL_VERSION})` : '';
      log(`+ ${c.name} #${c.id} connected from ${c.ip}${vnote}; online ${this.clients.size}`);
    }
    if (c.room) this._broadcastRoom(c.room);
  }

  _onPing(c, m, now) {
    this._send(c, { type: 'pong', t: V.isFiniteNumber(m.t) ? m.t : 0, server_t: now });
  }

  _onListRooms(c) {
    const rooms = [...this.rooms.values()].sort((a, b) => a.createdAt - b.createdAt).map((r) => this._roomSummary(r));
    this._send(c, { type: 'rooms', rooms });
  }

  _onCreateRoom(c, m, now) {
    if (this.rooms.size >= this.maxRooms) return this._error(c, 'Server is full (too many rooms)', 'server_full');
    const code = this._genCode();
    if (!code) return this._error(c, 'Could not allocate a room code', 'server_full');
    this._leaveRoom(c);
    const name = V.cleanText(m.name, V.LIMITS.MAX_ROOM_NAME) || V.cleanText(`${c.name}'s room`, V.LIMITS.MAX_ROOM_NAME);
    const room = new Room(code, name, now);
    this.rooms.set(code, room);
    this._addToRoom(c, room);
    room.hostId = c.id;
    log(`  room ${code} "${name}" created by ${c.name} #${c.id}; rooms ${this.rooms.size}`);
    this._broadcastRoom(room);
  }

  _onJoinRoom(c, m) {
    const code = typeof m.code === 'string' ? m.code.trim().toUpperCase() : '';
    if (!/^[A-Z]{4}$/.test(code)) return this._error(c, 'Invalid room code', 'bad_code');
    const room = this.rooms.get(code);
    if (!room) return this._error(c, `Room ${code} not found`, 'no_such_room');
    if (c.room === room) return this._send(c, { type: 'room', room: this._roomJSON(room) });
    if (room.players.length >= this.maxPlayers) return this._error(c, `Room ${code} is full`, 'room_full');
    this._leaveRoom(c);
    this._addToRoom(c, room);
    log(`  ${c.name} #${c.id} joined room ${code} (${room.players.length}/${this.maxPlayers}, ${room.phase})`);
    this._broadcastRoom(room);
    if (ACTIVE_PHASES.has(room.phase)) {
      // Late joiner: drop straight into the running round.
      this._send(c, this._roundStartMsg(room));
      this._send(c, { type: 'leaderboard', round_id: room.round.round_id, entries: this._standings(room) });
    }
  }

  _onLeaveRoom(c) {
    if (c.room) {
      const code = c.room.code;
      this._leaveRoom(c);
      log(`  ${c.name} #${c.id} left room ${code}`);
    }
    this._send(c, { type: 'room', room: null });
  }

  _onProfile(c, m) {
    let changed = false;
    if (m.name !== undefined) {
      const name = V.cleanText(m.name, V.LIMITS.MAX_NAME);
      if (name && name !== c.name) {
        c.name = name;
        changed = true;
      }
    }
    if (m.car !== undefined) {
      const car = V.cleanCarConfig(m.car);
      if (car) {
        c.car = car;
        changed = true;
      } else {
        this._error(c, 'Car config rejected (invalid or too large)', 'bad_car');
      }
    }
    if (changed && c.room) this._broadcastRoom(c.room);
  }

  _onReady(c, m) {
    if (!c.room) return this._error(c, 'Not in a room', 'no_room');
    if (typeof m.ready !== 'boolean') return this._error(c, 'ready must be true or false', 'bad_value');
    if (c.ready === m.ready) return;
    c.ready = m.ready;
    this._broadcastRoom(c.room);
  }

  _onSettings(c, m) {
    const room = this._requireHost(c);
    if (!room) return;
    const next = { ...room.settings };
    if (m.track !== undefined) {
      const track = V.cleanTrackId(m.track);
      if (!track) return this._error(c, 'Invalid track', 'bad_value');
      next.track = track;
    }
    if (m.duration_s !== undefined) {
      if (!V.isFiniteNumber(m.duration_s)) return this._error(c, 'Invalid duration', 'bad_value');
      next.duration_s = V.clamp(Math.round(m.duration_s), V.LIMITS.MIN_DURATION_S, V.LIMITS.MAX_DURATION_S);
    }
    room.settings = next;
    this._broadcastRoom(room);
  }

  _onStart(c) {
    const room = this._requireHost(c);
    if (!room) return;
    if (ACTIVE_PHASES.has(room.phase)) return this._error(c, 'A round is already running', 'bad_phase');
    if (room.phase === 'results' && !room.finalized) return this._error(c, 'Results are still coming in', 'bad_phase');
    if (room.players.length < 1) return this._error(c, 'Need at least one player', 'bad_phase');
    this._startRound(room);
  }

  _onState(c, m, now) {
    if (!c.room) return;
    if (!c.stateBucket.take(now)) return;
    const s = V.cleanState(m);
    if (!s) return;
    this._broadcast(c.room, { type: 'state', id: c.id, ...s }, c, true);
  }

  _onCheckpoint(c, m) {
    const room = c.room;
    if (!room || !this._roundOpen(room) || room.phase === 'countdown') return;
    if (V.toInt(m.round_id, 0, 1e9) !== room.round.round_id) return;
    const cp = V.toInt(m.cp, 0, V.LIMITS.MAX_CP);
    const ms = V.toInt(m.ms, 0, V.LIMITS.MAX_RUN_MS);
    if (cp === null || ms === null) return;
    this._broadcast(room, { type: 'cp', id: c.id, cp, ms, round_id: room.round.round_id }, c);
  }

  _onFinish(c, m, now) {
    const room = c.room;
    const roundId = V.toInt(m.round_id, 0, 1e9);
    const ms = V.toInt(m.ms, 1, V.LIMITS.MAX_RUN_MS);
    const ack = (ok, reason) =>
      this._send(c, {
        type: 'finish_ack',
        round_id: roundId ?? -1,
        ms: ms ?? -1,
        ok,
        reason,
        best_ms: c.best_ms,
        runs: c.runs,
      });
    if (!room) return ack(false, 'not_in_room');
    if (roundId !== room.round.round_id) return ack(false, 'stale_round');
    if (room.phase === 'lobby' || room.phase === 'countdown' || room.finalized) return ack(false, 'round_over');
    if (now > room.round.end_at + this.finishGraceMs) return ack(false, 'too_late');
    if (ms === null) return ack(false, 'invalid_time');
    if (ms > now - room.round.start_at + FINISH_CLOCK_SLACK_MS) return ack(false, 'impossible_time');
    c.runs++;
    const improved = c.best_ms < 0 || ms < c.best_ms;
    if (improved) {
      c.best_ms = ms;
      c.best_at = now;
    }
    ack(true, improved ? 'best' : 'slower');
    log(`  room ${room.code}: ${c.name} finished ${(ms / 1000).toFixed(3)}s${improved ? ' (best)' : ''}`);
    this._broadcast(room, { type: 'leaderboard', round_id: room.round.round_id, entries: this._standings(room) });
  }

  _onChat(c, m, now) {
    if (!c.room) return this._error(c, 'Not in a room', 'no_room');
    if (!c.chatBucket.take(now)) return this._error(c, 'Slow down', 'rate_limited');
    const text = V.cleanText(m.text, V.LIMITS.MAX_CHAT);
    if (!text) return;
    this._broadcast(c.room, { type: 'chat', id: c.id, name: c.name, text });
  }
}

module.exports = { Lobby, PROTOCOL_VERSION, CODE_ALPHABET };
