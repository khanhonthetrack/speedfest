'use strict';
// SpeedFest server: one Node process that
//   1. serves the exported Godot web build (PUBLIC_DIR, default ./public) over HTTP, and
//   2. runs online Time Attack rooms over WebSocket at /ws (protocol: docs/ARCHITECTURE.md).
//
// Env: PORT (8080), HOST (all interfaces), PUBLIC_DIR (./public), COUNTDOWN_MS (4000),
//      RESULTS_MS (12000), FINISH_GRACE_MS (1500), HEARTBEAT_MS (10000), MAX_PLAYERS (8),
//      BROTLI (1), LOG_LEVEL (info|silent),
//      LIVE (1; 0 = no always-on LIVE room), LIVE_RESULTS_MS (10000), LIVE_ROUND_S (0 = per track),
//      LIVE_MAX_PLAYERS (12).

const http = require('node:http');
const path = require('node:path');
const { WebSocketServer } = require('ws');
const { Lobby, PROTOCOL_VERSION } = require('./lib/lobby');
const { StaticFiles } = require('./lib/static');
const { Rotation } = require('./lib/rotation');
const logger = require('./lib/log');

const { log, warn } = logger;

function envInt(name, def) {
  const v = parseInt(process.env[name] ?? '', 10);
  return Number.isFinite(v) ? v : def;
}

/**
 * Build a server without starting it. Options override env vars (tests use this).
 * @returns {{httpServer: http.Server, wss: WebSocketServer, lobby: Lobby, files: StaticFiles,
 *            start: () => Promise<number>, close: () => Promise<void>, config: object}}
 */
function createServer(opts = {}) {
  const config = {
    port: opts.port ?? envInt('PORT', 8080),
    host: opts.host ?? process.env.HOST ?? undefined,
    publicDir: path.resolve(opts.publicDir ?? process.env.PUBLIC_DIR ?? path.join(__dirname, 'public')),
    countdownMs: opts.countdownMs ?? envInt('COUNTDOWN_MS', 4000),
    resultsMs: opts.resultsMs ?? envInt('RESULTS_MS', 12000),
    finishGraceMs: opts.finishGraceMs ?? envInt('FINISH_GRACE_MS', 1500),
    heartbeatMs: opts.heartbeatMs ?? envInt('HEARTBEAT_MS', 10000),
    helloTimeoutMs: opts.helloTimeoutMs ?? envInt('HELLO_TIMEOUT_MS', 20000),
    maxPlayers: opts.maxPlayers ?? envInt('MAX_PLAYERS', 8),
    brotli: opts.brotli ?? process.env.BROTLI !== '0',
    live: opts.live ?? process.env.LIVE !== '0',
    liveResultsMs: opts.liveResultsMs ?? envInt('LIVE_RESULTS_MS', 10000),
    liveRoundS: opts.liveRoundS ?? envInt('LIVE_ROUND_S', 0),
    liveMaxPlayers: opts.liveMaxPlayers ?? envInt('LIVE_MAX_PLAYERS', 12),
    warm: opts.warm ?? true,
  };
  if (opts.quiet) logger.setQuiet(true);

  const startedAt = Date.now();
  const lobby = new Lobby({
    countdownMs: config.countdownMs,
    resultsMs: config.resultsMs,
    finishGraceMs: config.finishGraceMs,
    maxPlayers: config.maxPlayers,
    live: config.live,
    liveResultsMs: config.liveResultsMs,
    liveMaxPlayers: config.liveMaxPlayers,
    rotation: opts.rotation ?? new Rotation({ durationS: config.liveRoundS }),
  });
  const files = new StaticFiles(config.publicDir, { brotli: config.brotli });

  const httpServer = http.createServer((req, res) => {
    const url = req.url || '/';
    const pathname = url.split('?')[0];
    if (pathname === '/health' || pathname === '/healthz') {
      const s = lobby.stats();
      const body = JSON.stringify({
        ok: true,
        rooms: s.rooms,
        players: s.players,
        uptime_s: Math.round((Date.now() - startedAt) / 1000),
        version: PROTOCOL_VERSION,
        build: files.hasBuild(),
      });
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      return res.end(body);
    }
    if (pathname === '/ws' || pathname === '/ws/') {
      res.writeHead(426, { 'Content-Type': 'text/plain; charset=utf-8', Upgrade: 'websocket' });
      return res.end('This endpoint speaks WebSocket.');
    }
    files.handle(req, res).catch((err) => {
      warn('static error:', err && err.message);
      if (!res.headersSent) res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal Server Error');
    });
  });
  httpServer.keepAliveTimeout = 65000; // longer than typical proxy idle timeouts (Render, Cloudflare)
  httpServer.headersTimeout = 66000;

  // perMessageDeflate off: frames are tiny, latency matters, and Godot's client doesn't negotiate it.
  const wss = new WebSocketServer({ noServer: true, maxPayload: 64 * 1024, perMessageDeflate: false });

  httpServer.on('upgrade', (req, socket, head) => {
    const pathname = (req.url || '').split('?')[0];
    if (pathname !== '/ws' && pathname !== '/ws/') {
      socket.write('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n');
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => wss.emit('connection', ws, req));
  });

  wss.on('connection', (ws, req) => {
    const fwd = String(req.headers['cf-connecting-ip'] || req.headers['x-forwarded-for'] || '').split(',')[0].trim();
    const ip = fwd || req.socket.remoteAddress || '?';
    const client = lobby.addClient(ws, ip);
    if (!client) {
      ws.close(1013, 'Server full');
      return;
    }
    const helloTimer = setTimeout(() => {
      if (!client.hello) ws.close(4000, 'hello timeout');
    }, config.helloTimeoutMs);
    ws.on('message', (data, isBinary) => lobby.onMessage(client, data, isBinary));
    ws.on('pong', () => lobby.alive(client));
    ws.on('error', (err) => warn(`ws #${client.id} error: ${err.message}`));
    ws.on('close', (code) => {
      clearTimeout(helloTimer);
      lobby.removeClient(client, `code ${code}`);
    });
  });

  let heartbeat = null;

  return {
    httpServer,
    wss,
    lobby,
    files,
    config,
    start() {
      return new Promise((resolve, reject) => {
        httpServer.once('error', reject);
        httpServer.listen(config.port, config.host, () => {
          httpServer.off('error', reject);
          const port = httpServer.address().port;
          heartbeat = setInterval(() => lobby.heartbeat(), config.heartbeatMs);
          log(`SpeedFest server on http://localhost:${port}  (ws: /ws, health: /health)`);
          log(`serving ${config.publicDir}${files.hasBuild() ? '' : '  [web build missing]'}`);
          if (config.warm) files.warm().catch((err) => warn('warm failed:', err.message));
          resolve(port);
        });
      });
    },
    close() {
      clearInterval(heartbeat);
      lobby.shutdown();
      for (const ws of wss.clients) ws.terminate();
      wss.close();
      return new Promise((resolve) => {
        httpServer.close(() => resolve());
        if (httpServer.closeAllConnections) httpServer.closeAllConnections();
      });
    },
  };
}

module.exports = { createServer };

if (require.main === module) {
  const srv = createServer();
  srv.start().catch((err) => {
    console.error(`Could not start: ${err.message}`);
    if (err.code === 'EADDRINUSE') console.error(`Port ${srv.config.port} is in use. Try: PORT=8081 npm start`);
    process.exit(1);
  });
  const stop = (sig) => {
    log(`${sig}: shutting down`);
    srv.close().then(() => process.exit(0));
    setTimeout(() => process.exit(0), 2000).unref();
  };
  process.on('SIGINT', () => stop('SIGINT'));
  process.on('SIGTERM', () => stop('SIGTERM'));
  process.on('uncaughtException', (err) => warn('uncaught:', err && err.stack ? err.stack : err));
  process.on('unhandledRejection', (err) => warn('unhandled rejection:', err && err.stack ? err.stack : err));
}
