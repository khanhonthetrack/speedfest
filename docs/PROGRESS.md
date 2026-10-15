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
- Spawned three cloud sessions (09:13 UTC): cars `session_01U5u2g2MGdocygvQu5vrKc2`,
  world `session_01VVtY7M5SnVMaLCbswNq3ku`, frontend `session_01CxwrXhBdpNbub4Uzv8brw7`.
  Each pushes to `visual/<key>` and keeps a Handoff section in its module doc.

## 2026-10-15 ~09:30 UTC — Owner feedback; parallel sessions stopped

- Owner sent six feedback items and asked not to run in parallel (TRANSCRIPT session 4). Interrupted
  and archived the three M5 sessions (none had pushed) and stopped the local review agents.
- New plan section **M4.5** (PLAN.md) with the six items. CLAUDE.md now has a "Work sequentially" rule.

## 2026-10-15 ~09:20 UTC — M4.5 item 1: the bumpy road was a bug (fixed)

- Probe `tests/physics/probe_road_bumps.tscn` (diagnostic): suspension high-frequency jitter was
  55 mm RMS (tick-to-tick second difference) on downtown versus 0.14 mm on a flat plane.
- Cause: the road deck was lofted with **one quad across the full 14 m width** every 1.5 m. Where the
  banking changes (bank ramps into banked turns and wall rides) each quad twists and folds along its
  diagonal: a ±11–13 cm ridge every 1.5 m at the road centre, a washboard at speed (collision and
  visual mesh alike).
- Fix (track_builder.gd): the deck profile is `DECK_CELLS` = 8 cells across and the ring step halves
  where the road twists (`deck_ring_ds`). Deck roughness p95 0.45 → 0.02 1/m on all tracks; jitter
  55 → 16 mm RMS, and what remains is at jump landings (expected). Compat arena ~220 draw calls
  (unchanged).
- New regression test `tests/tracks/test_road_smooth.tscn` (9 checks; fails 6/9 on the old deck).
- test_tracks 78/78, drive_test, scenery 45, weather 38, race logic 41 pass. Keyboard emulation with
  brute (the car that used to fall): arena 34.2 s, downtown 33.0 s, coast 30.1 s, **0 respawns**.
- Integration gate on `main` before this change: everything passed except
  `test_handling self_righting_kaze` (up_y=0.82), a regression from the handling-feel pass. Next.

## 2026-10-15 ~09:30 UTC — Two regressions from the handling-feel pass fixed (car.gd)

- `test_handling self_righting_kaze` (stuck at up_y 0.82): the new barrier-contact code treated the
  tilted body resting on the ground as a wall hit and cancelled 85% of the righting roll each tick.
  Barrier anti-spin now pauses while self-righting, and contacts facing world-up never count as walls.
- `test_wallride` fast veloce (airborne 38 ticks, 5.6 m off line): the +35% air gravity applied to
  any airtime, including the spawn drop, which tipped a marginal 250 km/h wall-ride exit. The extra
  gravity now applies only to jumps: speed > 15 m/s and taking off from road whose normal is mostly up.
- `game/tests/physics/run_all.sh` → PHYSICS_ALL_OK; test_feel 84/84 (barrier no-flip checks intact).

## 2026-10-15 ~09:30 UTC — M4.5 items 2, 3 (text), 4: HUD and fixed NOS

- HUD: minimap removed; no full-screen CHECKPOINT banner (the compact split pop-up stays);
  tachometer/NOS cluster at 70%. ARCHITECTURE HUD API: `set_minimap*` removed.
- NOS: fixed tank per run, no refill while driving (`NITRO_REFILL` removed). Tanks: kaze 5.5 s,
  brute 6.5 s, veloce 5.0 s (was ~4 s plus refills, ~9 s per run). Respawn keeps the tank, restart refills.
- Tests: test_hud 33/33, test_handling 32/32 ×3 cars (`nitro_no_refill_*` replaces `nitro_refills_*`),
  race logic 41/41, review fixes 7/7.

## 2026-10-15 ~09:40 UTC — M4.5 item 3: solid checkpoint gates

- Old gates were dark frames outlined with thin neon and no collision: at night only the outline
  read (a "see-through" hologram) and cars passed through the pillars. New gates: solid light
  pillars on footings with collision, crossbar with a backlit "CHECKPOINT n/N" sign (collision except
  near jumps/loops), light strips, and a road light on Forward+ q≥2. Checked on Forward+ (arena) and
  compat (downtown). Compat draw calls at a gate ~165 (downtown), unchanged in scale.
- test_tracks 78/78, drive_test, race logic 41/41, weather 38/38. Real-track matrix (default weather):
  analog 9/9 clean; keyboard emulation 7/9 clean (arena kaze stalls entering the loop; downtown veloce
  falls off between cp3 and the finish). Both also happen with the old gates and with nitro refills
  on, so they're the known keyboard-emulation margins, not the gates.

## 2026-10-15 ~10:10 UTC — M4.5 item 5 and the tuning half of item 6

- **Tuning removed**: no TUNE tab or RESET TUNING in the garage; `Profile.get_config()` always returns
  stock tuning (old saved values are ignored; `Profile.set_tuning` is a no-op). The CarConfig schema
  keeps `tuning` (all 0) so the network protocol and the physics tests are unchanged. The garage
  stat bars now show each car's stock character. garage_test 15/15 (checks tuning is always stock).
- **Lobby lineup** (`ui/menu/lobby_lineup.gd`, `LobbyLineup`): Rocket League-style 3D lineup in the
  room view. Every player's car parked side by side (own World3D sub-viewport), name + HOST/READY
  above it; a newcomer's car rolls in, leavers' cars disappear and the rest slide together; car or
  style changes from a player's garage show up live (the server already rebroadcasts profiles).
  Replaces the text player list. lobby_fake_test 23/23 (live update, newcomer, leaver).
  Screenshot helper: `tests/ui_menus/lobby_room_shot.tscn`.
- **No neon grids, static menus**: `menu_backdrop.gdshader` is a static graphite gradient (no grid,
  no animated streaks); the showroom turntable lost its pulsing neon rings (brushed metal, neutral
  studio rims); the car no longer auto-spins in the main menu or garage.
- **Stadium lawn**: the arena's ground (`env_terrain` mode 1 and `track_floor` style 1) is a mown
  lawn with 12 m stripes and a dark apron by the road; the arena light is a neutral night stadium
  (navy sky, white floodlights, neutral haze) instead of purple synthwave. Compat arena ~220 draw calls.

## 2026-10-15 ~10:30 UTC — M4.5 item 6: easy handling (car.gd), loop deck rings, live garage updates

- Easy handling (details: docs/modules/physics.md "Easy handling"): drift intent only from handbrake /
  brake-drift plus a mild per-car `power_oversteer`; hands-off stability assist (`STAB_YAW` ×
  `yaw_damp`) that damps a growing tail slide when the driver isn't steering. New
  `tests/physics/test_easy.tscn` (keyboard flick/slalom/lock): flick slip 43 → 7–12 deg, settle
  1.5 → 0.2–0.4 s; brake drift still 32–40 deg.
- Several assist variants were tried and rejected by the synthetic stunt tests or the real-track
  matrix (damping all yaw made cars run wide at wall-ride exits; the per-wheel ground normal made
  loop entries jumpy). Final variant: run_all PHYSICS_ALL_OK, test_easy 15/15, test_feel 56/56.
- track_builder: deck rings inside loops are 1 m per ring (`LOOP_RING`), also when a chunk only half
  covers the loop (arena: 1.5 m rings in the loop's first part let a 260+ km/h car catch a fold edge).
- Garage pushes the profile to the room 1 s after each change (others' lobby lineup updates live).
- Real-track matrix (default + storm) for this exact state: running at commit time; result in the
  next entry.

## 2026-10-15 ~10:30 UTC — Matrix follow-up: suspension end stop

- The matrix for the easy-handling commit (82bd701): physics/unit tests all pass; real tracks default
  16/18 (downtown veloce fell through the loop twice, coast brute fell once), storm 17/18 (arena kaze
  keyboard stuck six times at the wall ride). Traced: at 260–285 km/h loop entries (25–30 g) the
  body bottomed out on the deck, caught a fold edge or got a back-face contact.
- Tried and rejected: road backface collision off (4 + 3 failures, one car ejected 142 m up); a 40×
  hard-stop spring (rang at 60 Hz, the brute bounced out of loops).
- First fix (velocity end stop, ff618b4) failed the physics suite (cars slid off tight wall rides).
  Final fix: the body collision floor is lifted 0.12 m (`BODY_LIFT`) so the body can't bottom out;
  dynamics unchanged (docs/modules/physics.md "Body collision lift"). Wall rides 24/24 for all cars;
  the downtown loop and coast cases are clean. New guard test `tests/tracks/test_collision_faces`.
- Remaining known case: arena, kaze keyboard in storm, lands on the wall-ride entry at ~275 km/h after
  flying off the loop exit (track layout issue, session 3 open item #1).
