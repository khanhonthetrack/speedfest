# HANDOFF: start here

## Latest (~13:30 UTC, session 5)

- **Done (on `main`):** M4.6-1 downtown rework around real buildings (`TrackBuildings`), generated
  PBR textures (asphalt/concrete/metal/rock, `tools/textures/gen_textures.py`), new short stadium
  map **Rail Rush** (`rails`: ledge jump → grind rail → finish platform; `TrackRail`,
  `tests/tracks/test_rail`), static web build on the orphan branch **`web-build`**
  (`tools/publish_web_build.sh --push`, docs/HOSTING.md "Static web build").
- **`server/public` re-exported (M4.6-4 done)** with everything above, per the orchestrating
  session: the owner's Raspberry Pi runs the repo's Node server from `main` (docs/HOSTING.md
  "D. Raspberry Pi"; update = `git pull && docker restart speedfest`). Verified: CHECK_ALL PASS,
  `online_browser_test.js` 2 clients PASS on this build, static build WEB_STATIC_PASS.
- The repo is PUBLIC: never commit secrets, hostnames or URLs of the Pi.
- `web-build` branch = static build of main@eac62e7 (2133bb7).
- Open: textures could be swapped for real CC0 scans (ambientCG/Poly Haven are blocked here; keep
  the file names). Why compat rendered textured albedo brighter in the full scene is unexplained
  (worked around with the 1×1-mip normalization). Rail Rush has no ghost-specific handling (ghosts
  replay transforms, fine). Online play on the static build needs the Node server.
- Next: M5 visual tracks (docs/M5_SPECS.md), sequentially.

## Latest (~11:30 UTC, session 4): STOPPED for the usage limit, continue here

- Done today (all pushed): M4.5 (all six owner items), M4.6-3 dark-trap music, M4.6-2 two ground
  sprints (Infield Rush, Dune Dash) with grass/gravel/sand physics, 5-card track select, lobby fix.
- **server/public is the safe build from 339825c** (no sprints, no music changes after it). It
  is still what's deployed; the sprints need a new export (M4.6-4).
- **Next: downtown rework (M4.6-1)**, only started: the builder parses `{"building": ...}` markers.
  The full plan is in docs/PROGRESS.md (~11:30 UTC entry). Then export (M4.6-4).
- Work sequentially (owner rule). Commit and push after every step.

## Latest (2026-10-15 ~10:30 UTC, orchestrator #4, session 4)

**Rule from the owner: no parallel sessions or subagents.** Work one item at a time and push
after each step (CLAUDE.md "Work sequentially").

**Done today on `main`** (owner feedback list = PLAN.md "M4.5"; details in PROGRESS.md):
1. Bumpy road fixed (twisting full-width deck quads made a washboard; deck now 8 cells across with
   finer rings on twists and 1 m rings in loops). `tests/tracks/test_road_smooth`.
2. HUD minimap removed. 3. Small checkpoint feedback + solid Trackmania-style checkpoint gates.
4. Compact tachometer; NOS is a fixed tank per run (no refill).
5. Stadium lawn instead of the neon grid, static menus (no grid, no spinning car), Rocket
   League-style live car lineup in the online lobby (`LobbyLineup`).
6. Tuning removed (garage + Profile). **Easy handling**: drift only when asked + hands-off stability
   assist, per-car character (`power_oversteer`, `yaw_damp`), `tests/physics/test_easy`.
Also fixed two regressions from session 3's handling pass (self-righting, fast wall-ride exits).

**Next:** re-run `tools/integration/check_all.sh`, export the web build (`tools/export_web.sh`),
run the browser online test, commit `server/public`. Then M5 (docs/M5_SPECS.md), sequentially.

- **Game night is tonight.** If the host uses Render with Auto-Deploy on, every push to `main`
  redeploys. Re-export `server/public` only with verified changes, and not late in the day.
- Web export now excludes `assets/hd/*` (desktop-only large assets).
- Still open: web frame rate on a real GPU, downtown length (~26 s), adversarial review.

---|---|---|
| cars | `visual/cars` | session_01U5u2g2MGdocygvQu5vrKc2 |
| world | `visual/world` | session_01VVtY7M5SnVMaLCbswNq3ku |
| frontend | `visual/frontend` | session_01CxwrXhBdpNbub4Uzv8brw7 |
| orchestrator #4 | `main` | session_01B2557cfMsCmUR7NCyj37k8 |

- The orchestrator merges `visual/*` into `main` after checks (order world → cars → frontend), and
  re-exports `server/public` only after the upgrade is verified on both renderers.
- **Game night is tonight.** If the host uses Render with Auto-Deploy on, every push to `main`
  redeploys. Don't push `server/public` changes to `main` late in the day unless they're verified.
- Web export now excludes `assets/hd/*` (desktop-only large assets).

Open items from session 3 (below) still apply: keyboard-emulation falls, downtown length, web
frame rate on a real GPU, and the adversarial review.

---

## Session 3 (2026-10-15 ~08:00 UTC, orchestrator #3)

**State:** branch `ccr-49301774-b5a4ns` has the **Trackmania-style rework of all three tracks**
merged (tracks + physics + scenery module branches). It also has the new **weather** system:
dry / rain / storm rounds with stage-designed puddles that cut grip (owner request; DESIGN §4.1,
docs/modules/weather.md). The web build in `server/public` is re-exported from this state.

- Gate: `tools/integration/check_all.sh`. Weather: `tests/weather/test_weather.tscn` (38 checks).
  Matrix: `[WEATHER=storm] game/tests/physics/run_real_tracks.sh` (analog bot 9/9 clean in default
  and storm weather; keyboard emulation 13/18).
- Online: `game/tests/race/online_round_test.sh 3 40 --autodrive --track=downtown --weather=storm` PASS.
- Lobby host picks track + length + **weather** (picking a track selects its signature weather;
  downtown = rain). Solo: AUTO/DRY/RAIN/STORM chips on the track select. PBs are per (track, weather).
- **`main` now has everything** (owner asked, ~08:10 UTC; fast-forwarded from `ccr-49301774-b5a4ns`).
  Work on `main` from here (or a branch merged back into it). Deploy from `main`.

**Open items (priority order):**
1. Keyboard-emulation falls (5/18 runs need 1–2 respawns). They're mostly at wall-ride exits and
   jumps entered at ~250+ km/h after boosts (outside physics' 140–215 km/h wall-ride envelope).
   Options: move or trim the boost before each wall ride, add a slight climb before the wall
   ride, or lower roll. `"clothoid": true` on a wallride segment was tried and was worse.
2. Downtown runs ~26–28 s, below the 35–45 s target (DESIGN §4). Add a piece (e.g. a second
   rooftop jump).
3. Real-GPU web frame rate is still unmeasured. The weather adds rain particles (CPU on web),
   spray and puddle meshes. Check with the perf probe on `--compat`.
4. Adversarial review of race/physics/tracks/weather never ran.
5. Housekeeping: the remote branch `integration/weather-trial` is a leftover backup (an ancestor of
   this branch). It's safe to delete; this environment's git proxy refused the delete.

---

# Earlier handoff (orchestrator #2, ~06:35 UTC), kept for history


The owner is near the account usage limit, so all agents stopped and recorded their state. This page
is the entry point for the next agent. Read it first, then `CLAUDE.md`, `docs/PLAN.md`, the end of
`docs/PROGRESS.md`, `docs/TRANSCRIPT.md` (owner requests, verbatim) and `docs/M1_SPECS.md` (all module
specs, plus the **"M3 rework"** section at the bottom).

## 1. What works right now (playable)

Branch **`ccr-49301774-b5a4ns`** is the integration branch. Every module is merged, and the web
build is committed in `server/public/`.
- Game: menus, garage (tuning + NFSU2 styling), 3 cars, 3 tracks, solo time attack (PB + ghosts +
  splits), online rooms (2–8 players, countdown, live leaderboard, results), HUD, synthesized audio.
- Tests: `tools/integration/check_all.sh` → **CHECK_ALL PASS** (compile, 24 suites, server 12/12,
  AutoDriver finishes all tracks, net smoke, 3-client online round). `game/tests/ui_menus/lobby_smoke.sh`
  PASS. The keyboard-player emulation finishes all 3 tracks with all 3 cars (0 respawns).
- Hosting: `docs/HOSTING.md` (Render.com step by step, `render.yaml` blueprint; or PC + Cloudflare
  tunnel). Deploy from this branch. **Turn off Render Auto-Deploy during game night** (a push
  redeploys and drops players).
- `main` is NOT updated (this session may only push to `ccr-49301774-b5a4ns`). Ask the owner before
  merging into `main`.

## 2. In progress: Trackmania-style track rework (NOT merged yet)

The owner wants **all three tracks Trackmania-style**, with the themes kept as the setting: floating
platform roads with open edges, big gap jumps, loops and wall rides, turbo pads (yellow boost, red
super boost), short 30–45 s tracks. Spec: `docs/DESIGN.md` §4 and `docs/M1_SPECS.md` → "M3 rework".
The current (old-style) tracks on the integration branch are the playable fallback until the new
ones pass.

State per module branch (each one's `docs/modules/<key>.md` has a "Handoff" section at the top with
details; check `git log origin/module/<key>` for the latest commit):

| branch | state at handoff |
|---|---|
| `module/tracks` | **New Pulse Arena** done (start-tower dive, yellow turbo, walled banked turn, red super boost into a loop, 75° wall ride, gap jump, half-pipe 180, final jump through the finish arch, ~1.47 km point-to-point). AutoDriver 31–39 s, 0 respawns, all cars. **Open:** the keyboard emulation falls off at the wall-ride exit for brute/veloce (roll ramp 62 m vs ~245 km/h entry after the super boost). The fix per physics' envelope is a roll ramp ≥ 100 m and entry ≤ ~215 km/h. **Update 06:42: tracks pushed new downtown and coast layouts too ("part 2", de1b225 or later).** Physics measured all 9 car×track runs: the analog AutoDriver finishes with 0 respawns (arena 32–37 s, downtown 25–27 s, coast 31–33 s). The keyboard emulation is clean on 4/9 and needs 1–2 respawns on the rest, mainly the wall-ride geometry (62 m roll ramp with the curve at full curvature from roll 0; exact spots and fixes in docs/modules/physics.md and tracks.md). Matrix script: `game/tests/physics/run_real_tracks.sh`. Downtown at 25–27 s is shorter than the 30–45 s target. New API: `track.kill_y_at(pos)` (race already uses it). Must also set `path.set_meta("ground_y", …)` and mark the "elevated" and "wallride" zones for scenery. |
| `module/physics` | Rework support done (wall rides, super boost capped at ≤ 60 m/s² for ≤ 4 s with a 450 km/h hard cap and no tunnelling, big jumps, AutoDriver full throttle in wallride zones). `game/tests/physics/run_all.sh` → PHYSICS_ALL_OK; new `test_wallride`. |
| `module/scenery` | Elevated-deck support done (props on the ground, nothing inside the deck or pillar volume, downtown towers above and below the deck, coast cliffs and sea under the deck). Needs a screenshot check on the new layouts. |

### How to finish the rework (next agent)
1. Resume the sessions with `send_message` (they keep their context; IDs below) or do it yourself.
   Tracks: fix the arena wall-ride exit, then build the new downtown and coast per DESIGN §4.
2. Integrate on a local scratch branch:
   ```bash
   git fetch origin
   git checkout -B trial ccr-49301774-b5a4ns
   git merge origin/module/physics origin/module/scenery origin/module/tracks
   tools/godot_import.sh && tools/integration/check_all.sh            # must print CHECK_ALL PASS
   for t in arena downtown coast; do for c in kaze brute veloce; do
     tools/run_scene.sh res://tests/physics/test_real_tracks.tscn --headless -- --track=$t --car=$c --keyboard | grep -E "RESULT|TEST_"
   done; done                                                          # 0 respawns everywhere
   tools/run_scene.sh res://tests/integration/perf_probe.tscn --compat -- --track=downtown --autodrive --frames=420 --shot=/abs/dt.png
   ```
   Look at the screenshots on both renderers (drop `--compat` for Forward+). On web, keep about
   ≤ 400 draw calls (perf_probe prints PERF lines).
3. If everything passes: `git checkout ccr-49301774-b5a4ns && git merge --ff-only trial`, then
   `tools/export_web.sh`, commit `server/public`, push. Update PLAN/PROGRESS.

## 3. Other open items
- An adversarial review of race, physics and tracks never ran: the workflow died on the usage limit.
  Two earlier reviews (networking; ui/audio/visuals) found and fixed 9 bugs, all covered by tests
  (`server/test`, `game/tests/integration/test_review_fixes`).
- Web frame rate is unmeasured on a real GPU (the containers have none). Compat render stats: arena
  ~165 draw calls, downtown ~190, coast ~310 at quality 1.
- Nice to have: README screenshots; merge to `main` (owner decision).

## 4. Sessions (all spawned by orchestrator #2; resume with send_message, they keep their context)
| module | session |
|---|---|
| orchestrator #2 | session_01FScTiQ4vwQQ8wktXzQJ6Ey |
| physics | session_01DrvZUyYAM3oczRVDW1o8Nf |
| visuals | session_012FyHiPM6GP1ACSFBLqmWJV |
| tracks | session_01XWgKiHbRtgKdaQBXSuzZm7 |
| scenery | session_019ZpoTQnjd2NsrKfAdGeECh |
| ui_menus | session_018sRqzobba64dP5Ld7SByiE |
| ui_hud | session_015JD5jMrvZQVTcVqfNyySq9 |
| audio | session_018yYJrBdZh6uuXVdUQqViJH |
| race | session_01UXTHDb9Svwh7v9CKVysey7 |

Module sessions push only to `module/<key>`. The orchestrator merges into `ccr-49301774-b5a4ns`.
Environment notes: `downloads.godotengine.org` may be blocked, so use the GitHub release mirror (CLAUDE.md).
Containers have only 4 CPUs (local workflows run 2 agents at a time), which is why modules ran as
separate cloud sessions.
