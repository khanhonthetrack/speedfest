# Progress log

Chronological, newest at the bottom. Every agent appends an entry after meaningful work:
date, who (module/agent), what changed, what's next or blocked.

---

## 2026-10-14 — Session 1 (orchestrator)

- **M0 bootstrap done.**
  - Installed Godot 4.7.2 + templates. Verified headless screenshots under Xvfb on both renderers
    (llvmpipe/lavapipe).
  - Owner answered the design questions: Time Attack only, one track per theme (city / stunt arena /
    coast), JDM coupe + muscle + supercar, browser + keyboard.
  - Wrote DESIGN, ARCHITECTURE (interface contracts), PLAN (module ownership), SWITCH, and CLAUDE.md.
  - Godot skeleton: Settings (quality tiers, env tuning, input map, audio buses), Profile (garage,
    PBs, ghosts), Game (scene flow), TestHooks (CLI test/screenshot hooks), CarDefs (3 cars,
    shared geometry, style schema, sanitizer), TrackDefs, TrackPath (road frames with working loops
    and banking, tested), and stubs for Net/Audio/Car/CarVisual/Tuning/Track/Race/main menu.
  - Tools: `tools/godot_import.sh`, `check_scripts.sh`, `run_scene.sh`, `export_web.sh`.
- **Next:** M1, 8 module agents in parallel (networking, car physics, car visuals, track builder,
  scenery, UI, audio, race), each on its own branch, then integration.

## 2026-10-14 ~23:10 — M1 launched (orchestrator)

- Started 8 module agents in parallel. Each builds in its own git worktree and pushes to
  `module/<key>`. An independent reviewer then audits and fixes the work on the same branch:
  `networking`, `audio`, `physics`, `race`, `visuals`, `scenery`, `tracks`, `ui`.
- The full per-module specs given to the agents are in the workflow script. The essentials are in
  docs/ARCHITECTURE.md and docs/PLAN.md. Each module documents itself in `docs/modules/<key>.md`.
- Next: merge all `module/*` branches into `main` (M2 integration).

## 2026-10-15 ~00:05 UTC — Takeover (orchestrator #2, session_01FScTiQ4vwQQ8wktXzQJ6Ey)

- The first orchestrator (session_01CMDh9pTv1h5xawNJJ9eFH2) stopped after pushing only
  `module/networking` (last push 23:25). The owner said it got stuck and asked this session to continue.
- Merged `module/networking`: Node server (rooms, round flow, static + gzip/br), real WebSocket
  `Net` client. Verified: `npm test` 10/10, `tools/net_smoke_test.sh` PASS (3 headless clients, 81 checks).
  Net also adds `player_checkpoint`, `finish_result` signals, `server_now_ms()`, `round_time_left_ms()`.
- Environment note: `downloads.godotengine.org` is blocked here; Godot + templates come from the
  GitHub release mirror (CLAUDE.md updated).
- Added core `game/ui/ui_theme.gd` (`UITheme`: palette, fonts, shared Theme, time formatting) so
  the UI work can be split into `ui_menus` and `ui_hud` without both touching a theme.
- Relaunched the remaining M1 modules as parallel cloud sessions (this container has 4 CPUs):
  physics, visuals, tracks, scenery, ui_menus, ui_hud, audio, race. Each starts from branch
  `ccr-49301774-b5a4ns`, works only in its owned files, documents itself in `docs/modules/<key>.md`
  and pushes to its own session branch. The orchestrator merges them into `ccr-49301774-b5a4ns`.
- Module sessions (spawned 00:11 UTC, each pushes to its own `ccr-*` branch; specs in `docs/M1_SPECS.md`):
  physics `session_01DrvZUyYAM3oczRVDW1o8Nf`, visuals `session_012FyHiPM6GP1ACSFBLqmWJV`,
  tracks `session_01XWgKiHbRtgKdaQBXSuzZm7`, scenery `session_019ZpoTQnjd2NsrKfAdGeECh`,
  ui_menus `session_018sRqzobba64dP5Ld7SByiE`, ui_hud `session_015JD5jMrvZQVTcVqfNyySq9`,
  audio `session_018yYJrBdZh6uuXVdUQqViJH`, race `session_01UXTHDb9Svwh7v9CKVysey7`.
- Next (orchestrator): web export pipeline check with stubs, HOSTING.md, ARCHITECTURE.md Net
  additions; then merge module branches as they land (M2).

## 2026-10-15 ~00:50 UTC — Networking review (orchestrator)

- Adversarial review workflow on the merged networking module (3 finders, verifier per finding):
  7 findings verified, 4 confirmed (2 were the same bug), 3 refuted. Fixed:
  - **Hidden web tab drops reliable messages**: Godot's web loop stops on a hidden tab while the
    browser keeps queueing frames; relayed 20 Hz state filled the 4096-packet queue after ~50 s
    (5 players), and then room/round_end/round_start were silently dropped. The server now
    skips lossy state relays to clients silent for > 5 s (`STALE_RX_MS`), and Net raises its
    inbound limits as a backstop.
  - Reloading the page mid-round (same name, old socket not yet reaped) split a player's times;
    the server now folds the old socket's times into the live player.
  - Static cache keyed by `realpath`, so case variants on Windows/macOS hosts share one copy of the wasm.
  - Server tests 12/12 (2 new regression tests fail without the fix), net smoke test PASS.
- Trial merge of all 7 pushed module branches (local only): 1 compile error (race's test track
  vs the real Track; sent to the race agent). The race scene runs with the real car/track/HUD,
  but the AutoDriver can't finish the real tracks yet. Results sent to the physics and tracks agents.

## 2026-10-15 ~01:10 UTC — M2 integration (orchestrator)

- Merged physics, tracks, scenery and race (first complete versions) on top of networking, visuals,
  audio, ui_hud and ui_menus. 103 scripts compile; every module test suite passes (physics
  run_all, tracks 70, race 41+10+4, scenery 24, audio 64, hud 34, garage 17, lobby 19, visuals 29,
  core 8).
- The real race scene with `--autodrive` finishes every track: arena 39.6 s, downtown 60.3 s,
  coast 54.0 s (PB saved, splits vs PB on the next run, auto-restart).
- Online, headless: `game/tests/race/online_round_test.sh 3 75 --autodrive --track=arena` PASS
  (3 clients finish 38.6/39.5/39.6 s, results, back to lobby).
- Online, real web build in headless Chromium (`tools/integration/online_browser_test.js`, 2
  clients): PASS for the flow (connect, join, round start, race scene with remote car, round end,
  lobby). SwiftShader is far too slow to drive, so web frame rate can't be judged here.
- New `res://tests/integration/perf_probe.tscn` (race scene + render stats). Compat, quality 1:
  arena ~140 draw calls / 95k tris, downtown ~200 / 134k, coast ~380 / 290k (coast is near the
  budget). Web builds default to quality 1.
- Visual note: a near-black car (brute's default paint) is hard to see at night on compat.

## 2026-10-15 ~01:40 UTC — Review of merged UI/audio/visuals (orchestrator)

- Adversarial review (3 finders + verifiers) of ui_menus, ui_hud, audio, visuals: 5 confirmed,
  all fixed by the integrator (owning sessions had finished), with `tests/integration/test_review_fixes`
  (fails 4/7 without the fixes):
  - Hovering a button while typing in chat stole focus, so Space/Enter could press START/LEAVE.
    `MenuKit.hover_focus` now skips while a text field is being edited; Esc in a room must be
    pressed twice (first arms Leave).
  - Garage/name changes made while connected but outside a room never reached the server.
    `Game.leave_garage` now sends when online, and `Net.create_room/join_room` send the profile first.
  - A hidden (stale) remote car kept droning at its last rpm: remote EngineAudio mutes while hidden.
  - `CarVisual.build()` twice lost the wheels/calipers (PB ghost after a new PB): stale refs reset.
  - A round started while returning from the results screen (hidden tab) is now joined automatically
    on lobby entry (`Game.last_round_id`); a deliberately quit round stays manual.
- New `tools/integration/check_all.sh` gate: CHECK_ALL PASS (24 suites + server + autodrive on 3
  tracks + online rounds). `lobby_smoke.sh` (real lobby UI, 3 clients, real server) PASS.

## 2026-10-15 ~06:20 UTC — Resumed after the usage limit (orchestrator)

- The account hit its usage limit ~02:20 UTC; this session and the module sessions paused (the
  visuals session failed before doing the night-visibility fix). The owner said "Continue".
- Night readability fix (integrator): `car_paint.gdshader` gets a `night_rim` term (cool self-lit
  edge rim + faint sky sheen on upward panels, no extra lights, both renderers). `CarVisual.night_rim`
  (static) is set by race.gd per theme (city 1.0, arena 0.5, coast 0) and reset on exit, so the garage is
  unaffected. Dark cars are now readable on Neon Downtown.
- Owner feedback: the tracks look like normal tracks, not Trackmania-style. See TRANSCRIPT.

## 2026-10-15 ~06:40 UTC — Handoff (orchestrator #2)

- Trackmania rework started ~06:15: physics (wall rides, super boost, jumps) and scenery (elevated
  decks) are done on their module branches; tracks pushed the new Pulse Arena (keyboard wall-ride exit
  still open); downtown and coast are not rebuilt yet. None of it is merged into the integration branch.
- race.gd uses `track.kill_y_at(pos)` when available (faster respawn after falls from high decks).
- Hosting: `render.yaml` + Render steps in docs/HOSTING.md.
- The owner hit ~90% of the usage limit: every agent stopped and wrote a Handoff section. Next agent:
  **docs/HANDOFF.md**.

## 2026-10-15 ~07:00–08:00 UTC — Session 3 (orchestrator #3): rework integrated + weather

- Picked up from docs/HANDOFF.md. Merged `module/physics`, `module/scenery` and `module/tracks`
  (Trackmania-style rework of all 3 tracks) on a trial branch. All test suites pass.
- Wall rides: roll ramps 62 → 95 m (the physics envelope asked for ≥ 80–100 m). TrackPath tilt is now
  linear (binary search) instead of a smoothstep per dense point. A clothoid option
  (`"clothoid": true`, curvature follows roll) was tried and made the keyboard runs worse at
  ~250 km/h entries, so it is off by default.
- **Weather (owner request): dry / rain / storm rounds with stage-designed puddles that cut grip.**
  See DESIGN §4.1 and docs/modules/weather.md. Server/Net/lobby carry `weather`. Solo has weather
  chips. PBs are per (track, weather). Puddles are in all 3 layouts. Rain, lightning, thunder,
  spray, splash sounds.
- Results: analog AutoDriver 9/9 clean in default weather and in storm; keyboard emulation 13/18
  (unchanged); online 3-client storm round PASS; server tests 12/12; weather test 38/38.

## 2026-10-15 ~08:40 UTC — M5 visual upgrade started (orchestrator #3)

- Owner: the graphics look trivial and the menus look "mobiley". Path tracing is parked until
  they're at their RTX PC; focus on real art + lighting (mainline Godot) and an NFSU2-style 3D front end.
- Baseline at Ultra (Forward+): faceted procedural cars with flat paint, box buildings with pasted
  window squares, a black wet road with no visible reflections, and a black-void showroom
  behind flat chip panels.
- Fixed on `main` for tonight (web build re-exported): tire-spray mist drew as grey squares (now
  soft round puffs), and the PB ghost filled the screen when right behind the camera (now fades
  within ~12 m).
- Tooling: Blender 5.2.2 as a Python module in `/opt/bpyenv` (headless Cycles renders + glTF export
  verified). CC0 sources ambientCG and Poly Haven are reachable. docs/ASSETS.md tracks every asset.
- Launched 3 parallel agents (own worktrees): `visual/cars` (Blender hero cars behind the
  CarVisual API), `visual/world` (reflections, PBR textures, facades, HDRI, GI/fog, grade and post,
  presets), `visual/frontend` (3D garage front end). Integration follows.


## 2026-10-15 ~09:20 UTC — Session 4 (orchestrator #4): M5 restarted as cloud sessions

- Owner: "Look at the current state of speedfest, read from memory and continue working."
- Found that orchestrator #3's three M5 agents (local worktrees) had never pushed: no `visual/*`
  branches exist, so that work was lost with the container. `main` (b76a750, handling-feel pass)
  is intact.
- Fresh container set up (Godot 4.7.2 + templates, mesa Vulkan): 117 scripts compile.
  Baseline Ultra (Forward+) perf_probe: arena ~320 draw calls / 195k tris, downtown ~410 / 385k.
- Wrote **docs/M5_SPECS.md** (per-track scope, file ownership, budgets, asset rules, verification,
  push-after-every-step rule). Web export preset now excludes `assets/hd/*`.
- Spawning three cloud sessions: `visual/cars`, `visual/world`, `visual/frontend` (IDs below).
