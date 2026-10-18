# M9-7 Online like TMNF's: design

Owner's answers (TRANSCRIPT, session 13): accounts + ladder (login with a password, country/zone,
$-code nicknames, ladder points, world/zone rankings, saved online records, one always-on master
server with a small DB); hosting on the owner's Raspberry Pi: the master and the official servers
in one docker container behind a named Cloudflare tunnel.

What TMNF has (from the game, its manuals and its menus; nothing copied): a master server that
holds player accounts (login, password, nickname with $-codes, zone path World|Continent|Country|..),
ladder points won or lost on ranked servers by beating players with more or fewer points, world
and zone rankings, a server list where dedicated servers announce themselves, game modes Time
Attack (best time in a time limit), Rounds (everyone starts together, points per position: 10 6 4
3 2 1, first to a points limit), Team (blue against red, points per position summed for the team,
first team to a limit), Laps (a multilap race, first across the line), chat, votes (next map,
restart, kick), spectators, online records per track.

## Server (stadium/server, Node.js, one process)
- `lib/store.js`: a small JSON database (one file in DATA_DIR, written atomically, debounced);
  enough for a group of friends to a few thousand accounts.
- `lib/accounts.js`: register (login 3-20 of [a-z0-9_-], password >= 8, scrypt with a salt per
  account), log in (a token of 32 random bytes, kept 60 days, only its SHA-256 stored), nickname
  (TMNF's 75 characters with codes), zone (a path checked against `stadium/data/zones.json`).
  Logins rate-limited per address.
- `lib/ladder.js`: after each ranked round, every pair of finishers exchanges points (Elo: the
  winner gains K x (1 - expected), K = 32 / (finishers - 1)); start at 1000; world and zone ranks.
- `lib/records.js`: online records per track (best per account; top lists world and per zone).
  Solo campaign finishes are sent by logged-in clients (as TMNF did); server finishes by the
  game servers.
- `lib/master.js`: the HTTP API on /api: register, login, me (GET/POST), rankings, records (GET,
  POST), servers (GET; heartbeat POST from community servers with their host's token).
- `lib/game.js`: a game server (one room): modes TimeAttack, Rounds, Team, Laps; the map
  rotation; synchronized starts (start_at in server time) for Rounds/Team/Laps; points; teams;
  votes (next, restart, kick; more than half of the players, 30 s); spectators; chat; ranked
  results to the ladder (official servers only: they run in the master's process).
- `server.js`: reads `config.json` (or env): the master and the official servers, all on one port
  (game servers on /ws/<id>), for one Cloudflare hostname.
- Docker: `Dockerfile` (node:22-alpine, the server, the game's track list and zones),
  `docker-compose.yml` (the server with a data volume, cloudflared with the tunnel's token).

## Game (stadium)
- `net/tm_master.gd` (autoload Master): the account (token in the settings, never the
  password), the API calls.
- Online page: log in / register; your ladder points and ranks; SERVERS (from the master: name,
  mode, track, players) with JOIN; RANKINGS (world, your zone); join by address stays.
- Profile: nickname and zone saved to the account too.
- Campaign: the selected track's online records (world top, your zone, you); finishes sent.
- Race online: the mode's rules on screen (Rounds/Team points, laps), synchronized starts, team
  colours, spectating (follow a player, switch), votes (a menu and F1/F2).

## Order (commit after each)
A. Server: store, accounts, ladder, records, master API, tests.
B. Server: game modes, votes, spectators, ranked results, one-process config, tests.
C. Game: Master autoload, Online page (login, servers, rankings), Profile sync, campaign records.
D. Game: modes in the race, spectators, votes; the online smoke test.
E. Docker, the tunnel, official.json pointing at the master.
