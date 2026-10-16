# SpeedFest Stadium server

An always-on online room like a TMNF time-attack server: 5-minute rounds on random campaign
tracks (A01-E05, never one of the last 12), best times ranked live, everyone's car visible to
everyone, 15 s of results, chat. Players load the tracks from their own TMNF install; the server
only sends track ids. Node.js 20+.

    npm install
    npm start                       # http://localhost:8090 (status JSON), WebSocket /ws
    npm test

Options (env or args): `PORT`/`--port=8090`, `--host=127.0.0.1`, `ROUND_MS`/`--round-ms=300000`,
`RESULTS_MS`/`--results-ms=15000`, `NAME`/`--name=`, `MAX_PLAYERS`/`--max-players=32`.

## The official server
The game's "Join the official server" reads `official.json` here (from GitHub, branch
`stadium`): `{"name", "url"}`. Whoever runs the official server keeps that address current.

- **This PC + Cloudflare quick tunnel** (free, no account; the PC must stay on and awake):
  `powershell -ExecutionPolicy Bypass -File stadium\server\run_official.ps1 -Publish` starts the
  server (bound to 127.0.0.1) and `cloudflared tunnel --url ...`, then writes the tunnel's
  address to `official.json` and commits and pushes only that file. The address changes on
  every start. `stop_official.ps1` stops both. Logs: `%LOCALAPPDATA%\SpeedFestStadium\`.
  `cloudflared`: `winget install --id Cloudflare.cloudflared`, or Cloudflare's GitHub releases
  (pass `-Cloudflared <path>`).
- **A permanent host** (Render, a Raspberry Pi, any VPS): run `npm start` there with `PORT`
  from the host and put its `https://` address in `official.json`.
- **Same Wi-Fi**: start it without `--host`, then players type `<your-ip>:8090` under Online.
