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

## Admins: community tracks and cars
A server's admins upload community tracks (TMNF `.Challenge.Gbx`, e.g. from TrackMania Exchange)
and car packs (TMNF car models and skins as `.zip`, e.g. from ManiaPark), put them in a server's
rotation or car list, jump to a map, skip to the next one, and can make one car everyone's.
Players' games download what a round or a car needs once (checked by its SHA-256, cached) and race
it; in a race, **C** picks a car among the server's packs.

- **Who is an admin:** master accounts listed in the config's `"admins": ["login", ...]` (they log
  in with their account), and/or anyone with the admin password: `--admin-password=...` or env
  `ADMIN_PASSWORD` (sent as `Authorization: Admin <password>`). Without either, uploads are off.
- **The page:** `http://<server>/admin` (log in, upload a file or paste a TMX / ManiaPark link or
  id, tick the servers, edit each server's rotation and cars).
- **The API** (`lib/admin.js`): `GET /api/admin`; `POST /api/admin/tracks?servers=a,b|all` with the
  file as the body, or `{"tmx": "<id or link>"}`; `POST /api/admin/cars?name=&servers=` with the
  zip, or `{"maniapark": "<link>"}`; `DELETE /api/admin/tracks/<uid>`, `/api/admin/cars/<id>`;
  `POST /api/admin/servers/<id>` `{tracks, add_tracks, remove_tracks, cars, add_cars, remove_cars,
  forced_car, jump, next}`. `GET /api/content` lists what was uploaded.
- **What is accepted** (`lib/content.js`, the same rules as the game's reader): a track must read,
  be a Stadium track, use TMNF Stadium blocks (the game builds every one) and have a start and a
  finish; modded tracks (TMUnlimiter, custom or other environments' blocks) are refused with the
  reason. A car pack must hold `MainBody.Solid.Gbx` (a TMNF car model) or a `Diffuse` texture; it
  is repacked with only its models, textures (DDS, TGA, PNG, JPG, BMP) and sounds (WAV, OGG).
  Files are stored by SHA-256 in `DATA_DIR/content` and served at `/content/<sha256>.<ext>`.
- **Checked on real samples** (outside the repo, never committed): `stadium/tools/compat/fetch_tmx.py`
  + `TMX_DIR=<dir> npm test` and `tests/test_compat_tracks --dir=<dir> --build` (1113 TMX tracks:
  all 1098 vanilla ones build and race); `stadium/tools/compat/fetch_maniapark.py` +
  `tests/test_compat_cars --dir=<dir>` (160 ManiaPark models and skins: all load and draw).

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
