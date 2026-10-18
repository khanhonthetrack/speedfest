# SpeedFest Stadium online

One Node.js process (Node 20+) that is both TMNF's master server and its official game servers:

- **Master** (`lib/master.js`, HTTP `/api`): accounts (login + password, scrypt; a token for the
  game), nicknames with TMNF's $-codes, zones (`stadium/data/zones.json`), ladder points (Elo
  over every pair of a ranked round's finishers, `lib/ladder.js`), world/zone rankings, online
  records per track (`lib/records.js`), the server list (official servers in this process and
  community servers that send a heartbeat). Data: one JSON file, `DATA_DIR/master.json`
  (`lib/store.js`).
- **Game servers** (`lib/game.js`, WebSocket `/ws/<id>`): TMNF's modes (`lib/modes.js`):
  TimeAttack (best time in a time limit), Rounds (everyone starts together; 10 6 4 3 2 1 points;
  first to the limit), Team (blue against red), Laps (one race per map); map rotation over the
  game's own tracks, the cars relayed 10 times a second, chat, votes (next map, restart, kick),
  spectators; on the official servers ranked results go to the ladder and finishes to the
  records.

    npm install
    npm start                          # master + one Time Attack server on :8090 (data in ./data)
    node server.js --config=config.json
    npm test

`config.json` (see `config.example.json`): `{"port", "host", "data", "servers": [{"id", "name",
"mode", "max_players", "tracks", "round_ms", "results_ms", "ranked"}]}`. Without one:
`--port=8090 --host=127.0.0.1 --data=./data --name= --mode=TimeAttack|Rounds|Team|Laps
--round-ms= --results-ms= --max-players= --tracks=SF01,SF02` (or env `PORT`, `HOST`, `DATA_DIR`,
`NAME`, `MODE`, ...). `GET /` gives the first server's status and the server list; `GET
/ws/<id>/status` a server's status.

## The official servers (the owner's Raspberry Pi)
`docker compose up -d` here runs this server (`Dockerfile`, `config.example.json`'s four
servers, data on a volume) and `cloudflared` with a **named** tunnel, so the address never
changes. One-time setup in Cloudflare (free account, a domain on Cloudflare):

1. Zero Trust > Networks > Tunnels > Create a tunnel (Cloudflared), name it `speedfest`; copy its
   token into `.env` here as `TUNNEL_TOKEN=...` (never commit `.env`).
2. In the tunnel's Public Hostname: e.g. `speedfest.<your domain>` -> `http://speedfest:8090`.
3. Put `https://speedfest.<your domain>` in `official.json` (`"url"`), commit and push: every
   game finds the master (and through it the servers) there.

Updating: `git pull && docker compose up -d --build`. The accounts live in the `speedfest-data`
volume (back it up with `docker run --rm -v speedfest-data:/d -v $PWD:/b alpine tar czf /b/data.tgz /d`).

## Other ways
- **This PC + a Cloudflare quick tunnel** (no account; the address changes on every start):
  `powershell -ExecutionPolicy Bypass -File stadium\server\run_official.ps1 -Publish`.
- **Same Wi-Fi**: `npm start` without `--host`, then players type `<your-ip>:8090` under Online
  (and start the game with `--master=http://<your-ip>:8090` for accounts and the server list).
