# Hosting a SpeedFest game night

One person runs the **server**. It is a single Node.js program that serves the game to browsers
and runs the online rooms. Everyone else just opens a URL in a desktop browser
(Chrome, Edge or Firefox, with a keyboard). Nobody installs anything except the host.

The web build lives in `server/public/` (committed). If that folder is missing or empty, the
server shows a "web build missing" page. See "Rebuilding the web build" below.

## 1. Run the server (host's PC, ~5 minutes the first time)

Requirements: [Node.js 20+](https://nodejs.org) (the LTS installer is fine) and
[Git](https://git-scm.com).

```bash
git clone https://github.com/khanhonthetrack/speedfest.git
cd speedfest/server
npm install
npm start
```
It prints `SpeedFest server on http://localhost:8080`. Open that URL to check the game loads.

To use a specific branch: `git checkout <branch>` after cloning (`git pull` updates it later).

## 2. Let your friends in

Pick one option. **C (Render)** gives a permanent website and needs no PC running.

### A. Cloudflare quick tunnel (free, no account; your PC must keep running the server)
1. Install `cloudflared`:
   - Windows: `winget install --id Cloudflare.cloudflared` (or download it from Cloudflare's site)
   - macOS: `brew install cloudflared`
   - Linux: see Cloudflare's "cloudflared downloads" page.
2. With the server running, in a second terminal:
   ```bash
   cloudflared tunnel --url http://localhost:8080
   ```
3. It prints a URL like `https://random-words.trycloudflare.com`. Send it to your friends.
   The game connects back to the same address (`wss://…/ws`) automatically.
   The URL changes every time you restart the tunnel.

### B. Same Wi-Fi / LAN
Friends open `http://<host-ip>:8080`. Find the IP with `ipconfig` on Windows or `ip addr` on Linux.
Allow Node.js through the firewall when Windows asks.

### C. Deploy to Render (a permanent website, recommended): about 10 minutes, works from a phone
Free, with HTTPS and WebSockets. The repo has a `render.yaml` blueprint, so there's almost nothing to type.
1. Go to **render.com** → **Get Started** → sign up with **GitHub**. Allow Render to see the
   `khanhonthetrack/speedfest` repo, or all repos.
2. Dashboard → **New +** → **Web Service** → pick `speedfest`, then fill in:
   - **Branch:** `main` (the integrated game)
   - **Root Directory:** `server`
   - **Language / Runtime:** Node
   - **Build Command:** `npm install --omit=dev`
   - **Start Command:** `npm start`
   - **Instance Type:** Free
   Then **Deploy Web Service**. (Alternative: **New +** → **Blueprint** → pick the repo and that
   branch. It reads `render.yaml` and fills everything in.)
3. Wait for "Live" (2–4 minutes). Your game is at `https://speedfest-xxxx.onrender.com`, the URL at
   the top of the page. Send that link to your friends.

Good to know:
- The free plan **sleeps after 15 minutes without visitors**. The first visit then takes ~1 minute
  to wake up, so open the link a few minutes before game night.
- Every push to that branch **redeploys automatically**, and that restarts the server and drops
  players from their room. Before playing, turn off **Settings → Auto-Deploy** in Render (turn it
  back on later), or tell the agents not to push during the game.
- Health check: `https://<your-url>/health` shows `{"ok":true,...}`.
- Custom domain: Render → Settings → Custom Domains (needs a domain you own).

## 3. Playing

1. Everyone opens the URL, enters a name, and optionally tunes a car in the **Garage**.
2. **Online** → one player creates a room (the host). The others join it from the list or by its
   4-letter code.
3. The host picks the track and the round length, and presses **Start**. Everyone gets a
   3-2-1-GO countdown.
4. Drive as many runs as you like before the timer runs out. Your best time counts.
   Backspace/R respawns at the last checkpoint, Delete/Enter restarts the run, and Tab shows
   the leaderboard.
5. Results appear when the round ends, then everyone returns to the room.

Controls: W/S or arrows to drive and brake, A/D to steer, Space for the handbrake, Shift/N for
nitro, C for the camera, Q to look back, Esc to pause. Gamepads work too.

## Troubleshooting

- **Black page / "WebGL 2 not supported"**: update the browser and enable hardware
  acceleration (Chrome: Settings → System). Integrated laptop GPUs are fine. Lower Quality in Settings.
- **Can't connect online**: check that the server terminal is still running. Over the tunnel,
  use the `https://` URL, not `http://localhost`.
- **Low frame rate**: Settings → Quality: Low and Render scale 0.75.
- **Server port in use**: `PORT=8081 npm start` (Windows PowerShell: `$env:PORT=8081; npm start`).

## Server options (environment variables)

`PORT` (8080), `HOST` (all interfaces), `PUBLIC_DIR` (./public), `MAX_PLAYERS` (8),
`COUNTDOWN_MS` (4000), `RESULTS_MS` (12000), `FINISH_GRACE_MS` (1500), `LOG_LEVEL` (info|silent).
Health check: `GET /health`.

## Rebuilding the web build (developers)

Needs Godot 4.7.2 and its export templates (see CLAUDE.md):
```bash
tools/export_web.sh          # -> server/public
```
Tests: `cd server && npm test`, `tools/net_smoke_test.sh` (3 headless Godot clients), and
`tools/integration/online_browser_test.js` (N headless Chromium clients against a running server).
