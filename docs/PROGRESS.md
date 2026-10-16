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

## 2026-10-15 ~11:00 UTC — High-load loop entries: physics experiments reverted

- Velocity end stop (ff618b4) broke tight wall rides; lifting the body collision floor (f81c036)
  made cars hop on loop exits (test_stunts) and the matrix got no better (default 14/18, storm 15/18).
  Reverted car.gd to the easy-handling state (82bd701: physics suite OK, matrix default 16/18, storm
  17/18). The remaining failures are loop/wall-ride entries far above the envelope after boosts
  (downtown loop at 284 km/h, arena loop exit landing on the wall-ride entry at 275 km/h): to be
  fixed in the layouts (downtown rework, arena tweak). docs/modules/physics.md "High-load loop entries".

## 2026-10-15 ~10:45 UTC — M4.6 item 3: dark-trap music

- `tools/audio/gen_trap.py` (replaces gen_music.py's synthwave): five original loops synthesized from
  scratch: gliding saturated 808s, punchy kick, layered clap, metallic 808-style hats with rolls, FM
  bell / felt piano / breathy flute / synth brass leads, formant choir pads, reverse cymbals and
  risers. Menu 140 BPM C# minor; arena 150 F minor (hype); downtown 142 A minor phrygian (piano);
  coast 136 E minor (flute); generic race 144 G minor. 32-bar seamless loops, ~550 KB each (Vorbis q2).
- `Audio.race_music(track_id)`: each track plays its own beat (fallback "race"). test_audio 64/64.
- I can't listen in this container: checked structure with a spectrogram (intro → drop → break →
  drop) and levels (intro −17 dB, beats −10 dB RMS, 808 sub-bass dominant in the beats).

## 2026-10-15 ~11:00 UTC — Safe web build for tonight (server/public)

- Built from ab1429a in a separate worktree: `tools/integration/check_all.sh` → **CHECK_ALL PASS**
  (all suites, server 12/12, autodrive finishes arena/downtown/coast, net smoke, 3-client online
  round). Web export: index.pck 4.4 MB (+1.3 MB music).
- Real-browser test (headless Chromium, WebGL2, 2 clients, Neon Downtown): **PASS** (connect, join,
  round start, race, round end; 0 script errors). The lobby lineup shows both cars on the web build.
- The lobby lineup now renders only while something changes (it starved a second software-rendered
  browser); `online_browser_test.js` times the round from its start (`LOAD_S`, default 420 s, for
  slow page loads on CPU-only boxes).
- Contains everything up to the dark-trap music. Not yet: the short surface maps and the downtown rework.

## 2026-10-15 ~11:15 UTC — M4.6 item 2: two short ground sprints (Infield Rush, Dune Dash)

- Ground patches: layout marker `{"surface": kind, "len", "x0", "x1", "at"}`; TrackSurface kinds
  grass / gravel / sand with grip x0.74 / x0.62 / x0.68 and rolling drag 2 / 3 / 7 m/s². Car applies
  them per wheel on top of the weather grip; AutoDriver plans corner speed with `centerline_grip`.
  `shaders/track_ground.gdshader` draws mown grass, gravel with ruts, rippled sand (ragged edges);
  `DirtSpray` throws clippings/dust/sand from the rear tires.
- **Infield Rush** (stadium lawn): banked 120° with a grass inside line vs. asphalt outside, a
  full-width gravel flick, a kicker over a sand trap. **Dune Dash** (beach at dusk): sand short cut
  on a sweeper, dune jump onto sand, banked gravel bend, grass verges on the clifftop straight, finish
  jump. Both ~430–470 m, 2 checkpoints, target ~11 s; each beat reuses the arena / coast music.
- Rain/storm puddles on both (on the asphalt lines, so rain changes the grass-vs-asphalt choice).
- UI: track select fits 5 cards on 1280 px (narrower cards, fixed-height art, "SPRINT" vs. "STUNT
  RUN" tag, lawn and dune poster art for the sprints). Lobby track chips use `TrackDefs.short_name`
  so they stay on one row; lobby action buttons slightly shorter so nothing falls off at 720p.
- Tests: check_scripts 0 errors; test_tracks 95/95; test_weather 48/48; nav 8/8, lobby_fake 23/23,
  garage 15/15. Real tracks infield+dunes: default 12/12 clean; storm 11/12 (brute keyboard
  emulation understeers on wet gravel, see modules/tracks.md).

## 2026-10-15 ~11:30 UTC — M4.6 item 1 (downtown rework) STARTED, stopped for the usage limit

- Done so far: `track_builder.gd` parses a new `{"building": "roof"|"through"|"facade", "len", "at", ...}`
  marker into `data["buildings"]` (scaled like puddles; "through" adds a tunnel zone). Nothing builds
  them yet and no layout uses them, so the game is unchanged.
- Plan (next agent, continue here; see HANDOFF "Next: downtown rework"):
  1. New `res://tracks/track_buildings.gd` (`class_name TrackBuildings`, run tools/godot_import.sh),
     `static func build(track, data, layout)`, called from `Track._build_geometry()` after the road:
     - "roof": tower under the road (top = min deck y over the piece − 0.9 m, width road + 2×margin),
       roof boxes + neon roof-edge strip, no collision (falling cars still reach kill_y).
     - "through": tower around the road; blocks left/right of the tunnel outer box (half width
       road/2 + 2.8), a top block from 9.4 m above the road, a bottom block below the slab
       (−0.6 m); the existing tunnel shell is the interior. Collision boxes on left/right/top.
       Neon sign over the entry portal ("sign"). Keep the road straight and level inside.
     - "facade": facet boxes every ~12 m along the road side, face at lateral
       half_width·cos(roll(d)) + gap so it follows a wall ride's raised edge; collision boxes.
     - Visuals: one SceneryMesh per building (boxes in building-local metres) committed to a mesh
       and drawn through `SceneryInstances(mesh, SceneryMat.shader_mat("building", ...), ..., custom=true)`
       with one instance, so env_building.gdshader windows line up across blocks.
     - `path.set_meta("reserved", [[center, x_axis, z_axis, hx, hz], ...])`; city_kit.gd `build()`
       claims those cells (`_claim(_cells_of(...))`) so random buildings don't overlap.
  2. New downtown layout (remove the loop: it was entered at ~284 km/h and the body bottomed out):
     start helipad roof → boost → rooftop gap jump (roofs under takeoff and landing) → drive THROUGH a
     tower with cp1 inside → banked right 90 → left wall ride along a crescent tower facade (facade on
     the right) → cp2 → "needle" gap jump between two towers (facades both sides) landing into a right
     wall ride around a tower ("bounce off a building"; no boost before it, wall rides want
     140–215 km/h) → cp3 → dive between towers + banked 75 → cp4 → super boost → finish jump onto a
     rooftop. ~1600 m, ~35 s.
  3. Verify: check_scripts, test_tracks (update downtown RANGES if needed), test_weather (puddles),
     test_collision_faces, test_road_smooth, run_real_tracks.sh downtown (default + WEATHER=storm),
     compat + Forward+ screenshots (tests/tracks/track_view.gd `cp:N`).
- Then M4.6-4: export (worktree check_all, tools/export_web.sh, browser online test, commit server/public).

## 2026-10-15 ~12:00 UTC — M4.6 item 1 DONE: Neon Downtown rebuilt around real buildings

- New `res://tracks/track_buildings.gd` (`TrackBuildings.build`, called from `Track._build_geometry()`
  after the supports) builds the `{"building": ...}` markers: "roof" (tower under the road, neon
  roof edge, rooftop clutter), "through" (wings + block over the tunnel + block under the road,
  collision on wings/top, neon portal frame and a sign over the entry), "facade" (12 m facets that
  stand just beyond the barrier at every point, so they follow a wall ride's raised edge; collision;
  neon bands). Drawn with the city facade shader (unit-box MultiMesh, same look as the city).
  Footprints go to path meta "reserved"; `SceneryCityKit._reserve_track_buildings()` claims them.
- New downtown layout: helipad-roof start → turbo → rooftop gap jump (roofs under take-off and
  landing) → through the HOTEL ORBIT tower with cp1 inside → banked right 90 → left wall ride along
  a facade → cp2 → "needle" gap jump between two towers → right wall ride around a tower facade →
  cp3 → dive between towers + banked 75 → cp4 → super boost → finish jump onto a rooftop. The loop
  is gone (it was entered at ~284 km/h after the boost).
- Verified: check_scripts 0 errors; test_tracks 117/117 (needle run-out lengthened to pass
  `jump_runout`); test_weather 48/48; test_collision_faces 10/10; test_road_smooth 15/15;
  test_scenery 45/45. Real-track matrix downtown, default + storm: **12/12 clean, 0 respawns**,
  30–37 s (was 25–27 s, now inside the 30–45 s target). Screenshots on Forward+ and compat look
  right (tower sign and portal, wall-ride facades, finish roof); compat ≤ 235 draw calls.

## 2026-10-15 ~13:30 UTC — Session 5: PBR textures, Rail Rush, static web build

- **Textures (M5 world, "CC0 PBR textures"):** ambientCG / Poly Haven are blocked by this
  environment's network policy, so the four sets are generated by our own script
  `tools/textures/gen_textures.py` (asphalt, concrete, metal, rock; 1024² seamless albedo / normal /
  roughness; listed in docs/ASSETS.md). Road deck: textured + normal-mapped (loft now emits
  tangents, `Acc.use_tangents`), wet roads flatten the normal map. Track materials (concrete, dark
  metal, barrier bodies, tunnels, sidewalks, rock): world triplanar. Coast terrain rock and city
  lots use them too. Albedo is divided by the texture's own 1×1 mip, because compat rendered the
  textured albedo ~3.6× brighter than Forward+ in the full scene (isolated probes matched; cause
  not found), and the ratio is the same on both renderers. Lossy WebP import: +2.2 MB web .pck.
  Skipped at quality 0 (`TrackBuilder.use_pbr()`).
- **Rail Rush (`rails`), new short stadium map:** start deck → turbo → cp → open ledge → 6 m of air
  → 90 m grind rail (straight, then a 30° left bend, gently downhill) → hop over a 12 m gap → finish
  platform. New `TrackRail` (res://tracks/track_rail.gd): captures a car that comes down onto the
  rail (≤ 1.8 m off it, heading along it), drives it via `Car.grind` in `_integrate_forces`
  (speed kept, gravity along the slope, 1 m/s² friction, no steering), sparks + sound, releases at
  the end with a 2.6 m/s hop. Layout flags `"rail": true` / `"nodeck": true`. The finish is 13+ m
  off the take-off line, so jumping alone falls. `tests/tracks/test_rail` 33/33: all cars +
  keyboard emulation finish (6.2–6.7 s, 0 respawns); launches at 90 / 130 / 250 km/h all grind
  and finish; with the rail switched off the car falls. Six track cards fit (narrower cards,
  shorter blurbs, Rail Rush card art). Weather puddles on the run-up and the platform.
- **Static web build:** `tools/publish_web_build.sh --push` exports the single-threaded web build
  (no SharedArrayBuffer / COOP/COEP) to the orphan branch `web-build`. `web_static_test.js` serves
  it from `/speedfest/` with a plain static server and plays Rail Rush in headless Chromium with
  `--auto_solo=rails --autodrive`: WEB_STATIC_PASS (finish 6.55 s, 0 errors, 0 404s,
  crossOriginIsolated=false). docs/HOSTING.md "Static web build".
- Gate: `tools/integration/check_all.sh` **CHECK_ALL PASS** (after switching the grind sound to a
  one-shot; test_audio requires non-looping SFX). `web-build` = 2133bb7 (from main@eac62e7).
  `server/public` intentionally not re-exported (still 339825c; see HANDOFF).
- ~13:45 UTC: orchestrator update: deploy = `server/public` on `main` (the owner's Pi runs the
  repo's Node server from `main` via Docker + Tailscale Funnel). Re-exported `server/public` with
  the downtown rework, textures and Rail Rush; `online_browser_test.js` (2 Chromium clients, Node
  server, Rail Rush round) PASS. docs/HOSTING.md "D. Raspberry Pi"; owner's messages in TRANSCRIPT.
  (The `web-build` branch stays as an extra static copy.)

## 2026-10-15 ~13:50 UTC — Session 5 (Pi): CC0 scanned textures, Pi can push

- **The Raspberry Pi pushes now** (deploy key for this repo; the orchestrating session on the Pi
  works in `~/speedfest`). Godot 4.7.2 linux.arm64 + the web_nothreads templates are installed
  there, so the Pi can import, test and export (`tools/export_web.sh` takes ~15 s).
- **Textures: CC0 scans replace the generated sets** (M5 world "CC0 PBR textures"). New
  `tools/textures/fetch_cc0.py` downloads ambientCG Asphalt031 / Concrete034 / Metal038 / Rock022
  (1K-JPG, plus 2K with `--hd`) and writes the same file names. Calibration: albedo scaled per
  channel to the generated sets' mean color, roughness to their mean (the materials were tuned
  against those), and asphalt (contrast ×1.6, normal ×2) and metal (×2, ×2.5) are boosted because
  the fine scans otherwise read flat at driving distance. `gen_textures.py` stays as the fallback.
- **2K desktop sets** in `game/assets/hd/textures/` (16 MB; normals as JPEG q95). The Web preset
  already excludes `assets/hd/*` (checked: 0 hd paths in `index.pck`).
  `TrackBuilder.pbr_texture()` prefers them on Forward+ at quality ≥ 2 and also accepts a
  `.jpg` normal map. Import: VRAM compressed, high quality, mipmaps. `project.godot` now sets
  `textures/vram_compression/import_s3tc_bptc` and `import_etc2_astc` to true, so the committed
  `.import` files work on x86 and ARM editors (and ASTC is ready for Switch).
- Checks on the Pi: check_scripts SCRIPT_ERRORS=0; test_tracks 130/130; test_rail 33/33. Before/after
  screenshots on compat: the road shows real fine aggregate instead of the round "pebbles", the concrete
  barriers and walls show real concrete. Forward+ (llvmpipe) renders with the 2K sets, no load errors.
- `server/public` re-exported with the scans: `index.pck` 6.6 → 8.4 MB (wasm unchanged). Live on the
  Pi. Headless Chromium (SwiftShader) on the Pi, through the public Funnel URL,
  `?arg=--auto_solo=rails&arg=--autodrive`: AutoDriver finishes Rail Rush 3× at 6550 ms, 0 errors
  (same time as the cloud static test).

## 2026-10-15 ~14:45 UTC — Session 6 (Pi), M6-1 DONE: LIVE map rotation

- **Server:** `server/lib/rotation.js` (playlist: every track once per shuffled cycle, never twice in
  a row, per-track round length 90–240 s, usual weather with a 25% wet twist). `lobby.js` keeps an
  always-on room `LIVE` (no host; `settings`/`start` → `live_room` error; capacity 12): the first
  join starts a round at once, `results` (10 s) roll straight into the next track, and it idles when
  empty. Room JSON gains `live` and `next`. Env: `LIVE`, `LIVE_RESULTS_MS`, `LIVE_ROUND_S`,
  `LIVE_MAX_PLAYERS`. Private rooms unchanged.
- **Client:** `Net.join_live()` / `is_live()`; main menu "ONLINE · LIVE" (joins the rotation as soon
  as the online screen is connected) and "PRIVATE ROOM"; the online screen has a JUMP IN panel above
  the room list and a host-free LIVE room view (NOW / NEXT, countdown); the race stays between LIVE
  rounds and the results footer shows "NEXT UP <track> · <weather> · N".
- Tests: server 16/16 (new `test/live.test.js`: rotation properties, drop-in, no host, rotation to
  the announced track, idle + restart, private rooms alongside); new `tools/live_smoke_test.sh`
  (2 headless Godot clients: 18 checks PASS; added to check_all); net_smoke 3 clients PASS;
  lobby_fake_test 23/23. nav_test's 2 menu-focus failures predate this (first-run name prompt has
  focus on a fresh profile).

## 2026-10-15 ~15:30 UTC — Session 6 (Pi), M6-2 DONE: four new 10–30 s maps

- **Rooftop Rush** (`rooftop`, city, rain): roof drop jump → through a tower (cp) → facade wall ride
  → open ledge onto a grind "cable" across to the finish roof. **Cliff Hanger** (`cliff`, coast):
  downhill sweepers with sand on the inside half, cliff wall ride, super boost bay jump through
  the finish. **Twister** (`twister`, arena): grass-cut banked 90, two loops drifting opposite ways
  with a left-only turbo between them, kicker through the finish. **Pipe Dream** (`pipes`, arena):
  three banked half-pipe 180s, gravel low line vs. clean high line, side turbos on the high side.
- Builder: boost pads take optional `"x"`/`"pw"` (side pads). TrackDefs: 10 tracks (targets
  14/15/14/18 s). Track select: horizontal carousel (follows focus, wheel scrolls). LIVE playlist:
  all 10 (150–180 s rounds for the new ones).
- Checks: test_tracks all 10 tracks 203/203; test_rail 33/33; AutoDriver (race.tscn --autodrive):
  rooftop 14.0 s, cliff 15.2 s, twister 14.2 s, pipes 19.6 s, 0 respawns each; server 16/16.
  Screenshots (compat) of each map look right.

## 2026-10-15 ~16:00 UTC — Session 6 (Pi): M6-3 started, stopped for the usage limit

- Branch `wip/m6-cars` (bec01f3): Kitsune R4 (AWD rally hatch, `loose_grip` 0.75), Pixie S (kei
  roadster), Goliath HD (pickup) with defs, physics, body shapes and front/rear parts. Compiles, not
  tested or reviewed visually; engine sounds not generated yet. Next steps listed in HANDOFF.
- The live Pi site still runs the 5236df9 build (before LIVE and the new maps).

## 2026-10-15 ~17:20 UTC — Session 7: air steering fix, weather test on the new maps

- **Air steering was inverted** (owner, session 3: "when in the air, when I move my car left it
  runs right"). The air yaw torque drove the yaw rate toward `+steer * AIR_YAW_RATE`, but steer
  +1 = right = negative yaw. It now uses `-steer`. `test_feel` checks the direction per car
  (right steer → -7.3° in 1 s) and is 87/87.
- **test_weather** failed on the session-6 maps. Cliff Hanger's and Pipe Dream's storm puddles sat
  on boost pads, so they moved onto the wall-ride exit straight and off the side pad (1 m overlap).
  Rooftop Rush had no storm-only puddle, so a 14 m pool now crosses the start of the last roof. The
  test counts a side pad (`"pw"`) only where the puddle overlaps it sideways. Result: 73/73.
  AutoDriver in storm with no respawns: cliff 16.2 s, rooftop 14.3 s, pipes 20.3 s.
- Checks: PHYSICS_ALL_OK; check_all --quick all suites OK except test_weather (fixed above).

## 2026-10-15 ~17:50 UTC — Session 7: M6-3 DONE, three new car types merged

Branch `wip/m6-cars` (session 6, untested) finished and merged into `main`:
- **Looks:** screenshots of all three on Forward+ and compat. Goliath's bed was a smooth bowl that
  read as a dome. `CarShape.deck_y` now takes an optional `dip_pow` where the deck dips below the
  belt (Goliath 14), so the bed has a flat floor and steep walls. Kitsune and Pixie were fine.
- **Engine sounds:** `gen_engines.py` adds Kitsune (turbo I4, anti-lag pops), Pixie (high-rev I3)
  and Goliath (low-revving cross-plane V8 with supercharger whine). Their loops start at the
  quietest sample (`zero_start`), because Vorbis left a click at the seam of the Goliath high loop.
  check_loops 0 failures. The existing engine files are byte-identical.
- **Stats:** `Tuning` display ranges widened for six cars: top 228–330 km/h, accel 5.65–4.2,
  handling 0.1–1.9, nitro time 2–9 s. test_tuning 9/9.
- **Physics fixes from testing:** Goliath damping 0.44 → 0.50, because it bounced on a rolled
  landing on Dusk Coast and the AutoDriver fell off once. Goliath grip 1.40 → 1.46, because it slid
  4.66 m sideways on the fast wall ride (limit 4.5; downforce and steer speed didn't help).
  **Loose-surface drag now fades in with speed** (full above 54 km/h, 15% at a standstill). Before,
  a road car that stopped on sand could not move: 1 km/h after 4 s at full throttle.
- **Tests:** new `tests/physics/test_loose` (8 checks). After 4 s of full throttle every car gets
  out of a sand trap (road cars 40–48 km/h, Goliath 84, Kitsune 99). Entering sand at 120 km/h,
  Kitsune keeps 82% of its asphalt speed, Goliath 76%, road cars 63–70%.
  `run_all.sh` runs every per-car test for all six cars, and PHYSICS_ALL_OK. Test fixes:
  test_straight spaced its cars 60 m apart, so the sixth spawned off the 400 m pad. Its top-speed
  floor is now 235 km/h (the Pixie is the slowest by design). test_stunts started timing the jump
  15 m up the ramp, so the light Pixie's skip on the ramp counted as the jump; it now starts at the
  lip. `run_real_tracks.sh` takes `CARS=` and `KB=`.
- **AutoDriver:** the 3 new cars × 10 tracks finish with 0 respawns (e.g. coast 28.6–29.6 s,
  rooftop 14.3–17.6 s, rails 6.2–6.4 s). CHECK_ALL PASS (--quick).

## 2026-10-15 ~19:15 UTC — Session 7: M6-4 step 1, photographed skies (CC0 HDRIs)

- `tools/textures/fetch_hdri.py` fetches three Poly Haven CC0 "pure sky" HDRIs: Kloppenheim 07
  (city, overcast night), Kloppenheim 02 (stadium, clear moonlit night) and Belfast Sunset (coast).
  It scales each so the bright clouds sit below white, encodes 8-bit sRGB JPEG equirects (1K for all
  builds, 40–60 KB; 2K desktop-only under `assets/hd/sky/`, 140–180 KB) and generates
  `tracks/scenery/sky_panoramas.gd` (encode scale, sun/moon position).
- `env_sky.gdshader` gains `pano_*` uniforms. The photo blends over the procedural sky (exposure
  relative to the photo's real brightness, tint, saturation, a zenith grade), and the procedural
  glow band, stars and sun disk are drawn on top. Below the horizon the procedural ground stays: the
  photo's bright lower half lifted the ambient light and turned the fog white.
  `SceneryEnv._panorama()` loads 2K on desktop High/Ultra and 1K elsewhere, and turns the photo so
  its sun or moon sits at the scene light's azimuth. The coast's sun light now uses the photo sun's
  elevation (2.4° instead of 4.3°). Quality 0 keeps the procedural sky only.
- Tuned against before/after screenshots on both renderers (track_view chase/drive/orbit). Coast:
  real sunset clouds with the deep violet zenith kept. City: violet-lit overcast between the towers
  instead of near black. Stadium: deep navy starry night instead of flat black.
  Lesson: the "real" HDR exposure is ~4× brighter than the hand-tuned procedural skies; match the
  average instead (coast 0.08, city 0.3, stadium 0.32 of real).
- Checks: test_scenery 45/45, test_weather 73/73, check_scripts 0 errors. Asset list: docs/ASSETS.md.

## 2026-10-15 ~19:35 UTC — Session 7: M6-5 web export (Pi deploy pending)

- `server/public` re-exported from `main`: new cars, air steering fix, sand drag fade, photographed
  skies, weather puddle fixes. The pck grows 8.41 → 8.74 MB (12 engine loops + three 1K skies).
- Web-only bug fixed: Orbitron (headings) has no "·", and the web has no system fonts to fall back
  on, so "ONLINE · LIVE" and "STREET · STUNT · TIME ATTACK" drew a box. `UITheme.font()` now gives
  the Orbitron faces Rajdhani as a fallback.
- Browser checks (headless Chromium, SwiftShader WebGL2, local server on this export): the menu
  loads with 0 console errors. `online_browser_test.js` with 1 client: connect → round → finish
  (Goliath on Rail Rush 6.183 s, accepted by the server; Kitsune drove the same map in an earlier
  round). The script takes `CARS=`. Two clients don't fit in this 4-CPU container: they hadn't
  loaded within 7 minutes. Software rendering also runs the race ~7× slower than real time, so
  browser rounds need ~90 s per 6 s of driving.
- **Not deployed:** the Pi serves `server/public` from its `~/speedfest` clone. To ship this build:
  on the Pi, `cd ~/speedfest && git pull && docker restart speedfest`.

## 2026-10-15 ~20:20 UTC — Session 7: owner request "more patterns", 10 new liveries

- `car_paint.gdshader`: 10 new procedural liveries in car-local space, so they fit all six bodies:
  flames, bolt, retro, camo, tiger, hex, gradient, race (7-segment number roundels; the number comes
  from the plate's digits via `CarVisual.race_number()`, else a default per car), drip and circuit.
  `CarDefs.LIVERIES` has 16 entries now, and older clients sanitize unknown ones to the default.
- Garage: a new **VINYL** tab (pattern + vinyl color) after PAINT, NFSU2-style; PAINT keeps color
  and finish. The screenshots script covers 6 tabs. Showcase `--style=alt` no longer crashes on the
  new cars.
- Checked on compat screenshots for all six cars. test_build 56/56 (3240 part combos, worst 22,862
  tris, budget 25,000), garage_test 15/15, nav_test 8/8, lobby_fake_test 23/23.

## 2026-10-15 ~20:50 UTC — Session 7: owner request "interiors suck ... put a driver inside"

- Why it looked weird: the body deck ran straight through the cabin at window height, painted in
  the body color. The seats were slabs sticking up through that shelf, the wheel was a solid disc,
  and nobody sat in the car.
- `CarShape.cabin()` lays out each car's cabin from its greenhouse: driver scale `k` so the helmet
  fits under the roof, recline, hip/shoulder/head/wheel positions, the dash face and rear bulkhead,
  tub floor and walls. Short cabs (the pickup) slide back so the wheel clears the windshield.
  Right-hand drive for the JDM cars, a rear bench on the 2+2s. `CarShape.shell_deck_y()` sinks
  the deck into a tub. `CarBody.section()` samples it at fixed fractions so every station keeps
  the same columns, and the shell paints everything under the glass as dark interior trim.
- New `CarCabin` (game/cars/visual/car_cabin.gd), ~1.5k tris: bucket seats with colored inserts,
  rear bench, binnacle with glowing gauges (new `car_lights` instrument type) and screen, console and
  shifter, door cards, rear-view mirror, steering wheel (rim/spokes/hub/column), and the driver
  (helmet in the body paint with a vinyl stripe and a smoked visor, suit per car, red harness,
  gloves on the wheel at ten and two, legs to the pedals).
- Glass: the windshield is its own clearer surface (`glass_front`), side and rear glass a bit
  lighter than before, so the cabin reads on the web renderer too.
- Checked with new showcase angles `cabin`, `cabin_r` and `cockpit` (and `--tint=`) on all six
  cars, both renderers. test_build 56/56 (worst 25,988 tris; budget raised 25k → 28k), draws ≤ 10.
- `server/public` re-exported (pck 8.76 MB). Chromium main menu: 0 errors, the driver shows
  through the Kaze's windows. Pi deploy pending: `git pull && docker restart speedfest`.

## 2026-10-15 ~21:40 UTC — Session 7: M7 recorded, research stopped at owner request

- Owner feedback "unplayable" (PC graphics + RTX, lag, TM physics, barriers, wall rides, magnetic
  rails, 30+ distinct maps) recorded verbatim in TRANSCRIPT and as milestone M7 in PLAN.md.
- A read-only M7 research workflow (6 topics + a planning agent) was started and then stopped on
  the owner's "STOP WHAT YOU'RE DOING AND WRITE DOWN HANDOFF" before any report was finished.
  The script is saved as docs/research/m7_research_workflow.js for the next session. No game code
  changed after ce4dc66.

## 2026-10-15 ~23:00 UTC — Session 8 (Pi): M7 physics rewrite (branch m7-physics)

- Trackmania-feel lab `tests/physics/test_tm` (acceleration, steering response, grip turns, slalom,
  drift, barriers 15/30/45/90 deg, 80 deg wall ride, loop, landing, air gravity; all 6 cars).
  Baseline kaze: 17/52 failed (13-19 deg slide in every turn, 41 deg slalom slip, wall ride slid
  8 m and went airborne, 15 deg barrier graze bounced off with the nose 20 deg out, 0-100 3.1 s).
- New handling in car.gd (yaw-rate steering + lateral grip cancellation + drift mode, glancing
  barriers, ground stick, fast keyboard steering, +35% power): lab 312/312, PHYSICS_ALL_OK.
  Kaze now: 0-100 2.3 s, turn-in 0.13 s, release 0.22 s, ~1 deg slip at 2.1-2.9 g, drift turns
  50 vs 34 deg keeping 95%, wall ride drift 0.5-0.7 m with ~99% speed kept, barrier graze keeps
  96% with the nose aligned, landings keep 99.6%.
- Pushed to branch `m7-physics` (87a4543); real tracks/AutoDriver not re-run yet (HANDOFF).

## 2026-10-15 ~23:20 UTC — Session 10: M7 physics verified and merged into `main`; rails non-magnetic

- **Real tracks with the new handling** (session 8's rewrite on `m7-physics`): AutoDriver 10 tracks
  × 6 cars, analog **60/60** and keyboard emulation **60/60** with 0 respawns (session 3 keyboard:
  13/18 on 3 tracks). Laps are faster: e.g. Rail Rush 5.6-6.0 s (was 6.2), Arena 28.8-30.5 s.
- **Fast-loop body slam fixed**: the one failure (Twister, Veloce) entered a loop at 273 km/h (~30 g),
  the springs ran out, the floor box hit the road, caught a triangle edge and the car stopped dead
  (273 -> 15 km/h in one step). `car.gd` now has a hard stop at the end of the suspension travel
  (`_hard_comp` = 4 cm before the floor would touch): no further velocity into the road, speed kept
  while rolling; on a touchdown the vertical speed is only removed (no free boost). TM lab: new
  `loop_fast` (r 18 m at 280 km/h: completes, < 15 km/h lost in any step, exit >= 85% of entry);
  **336/336**.
- **Rails not magnetic** (owner, M7-5): `track_rail.gd` catches only a car coming down onto the
  rail: <= 0.45 m off the line (was 1.8), within 0.35 m of ride height (was -1.1/+0.7), not rising
  (> 0.5 m/s; was 2.5), heading within ~26 deg (was 41). The catch blends the leftover offset out over
  0.15 s instead of snapping. `test_rail` probes (a car 1 m beside it / rising through it / landing
  0.3 m off-centre) fail on the old code and pass now; **37/37**, every Rail Rush run incl.
  keyboard still lands the rail; the no-rail controls still fall.
- **online_round_test** had been broken since session 6: autopilot guests joined the always-on
  LIVE room (listed first) instead of the test's room. Guests now skip LIVE unless `--code=LIVE`;
  3-client round PASS.
- Checks: PHYSICS_ALL_OK, test_tracks 203/203, check_all (full) all suites OK incl. online_round.
## 2026-10-15 ~23:30 UTC — Session 9: reverse engineering TMNF (owner request)

- Downloaded TMNF 2.11.26 from the official Ubisoft CDN (SHA-256 matches ModTMNF's list) and
  unpacked it (7-Zip SFX → Inno Setup). It ships `TmForever.map`, so every function has its name.
- REA (morluto/rea) + Ghidra 12.1.4 analyse `TmForever.exe` with the map as seeds; a small bridge
  keeps one REA MCP session alive (tools/research/tmnf/).
- Decrypted `StadiumCar.VehicleTunings.Gbx` from Stadium.pak (re-implemented GBX.NET's pak
  format; found the reader buffering that drives the cipher's IV re-keying) and parsed it with the
  chunk layout from `CSceneVehicleCarTuning::Chunk`. It holds 30 tunings, Nadeo's history of the
  Stadium car from 26Nov2002 to 20juin2006; the game uses the last one (index 29).
- That tuning selects force model 6 (`ComputeForcesModel6`). Decompiling it and its helpers next;
  the write-up goes to docs/research/tmnf_physics.md. Only our own description and the numbers
  go into the repo, no game files or decompiled code.

## 2026-10-16 ~00:15 UTC — Session 9: TMNF car physics reverse engineered

- `docs/research/tmnf_physics.md`: the Stadium car's force model 6 described from the code
  (`ComputeForcesModel6` and helpers, rigid-body and collision layers) with the real tuning
  (`20juin2006`, the last of 30 tunings in StadiumCar.VehicleTunings.Gbx), geometry from
  StadiumCar.Solid.Gbx (wheelbase 2.988 m, wheel radius 0.364 m), the surface table, turbo and walls.
- `tools/research/tmnf/tmnf_model.py`: runnable flat-ground reconstruction; prints 0-100 1.74 s,
  0-200 4.26 s, full-lock radius 15.8 m @ 100 km/h / 48 m @ 200 / 133 m @ 400, braking 3 g above
  60 km/h, 8 m drop in 0.8 s.
- Pack decryption: TmForever re-keys the cipher IV on every node read (parent class id; class ids
  read from each class's `GetMwClassId`, parents from ModTMNF's hierarchy), on tuning names and on
  `CPlugSurfaceGeom` boxes; its reader inflates 256-byte input blocks into a 1024-byte buffer and
  large reads bypass it, so `pak_search.py` backtracks; Adler-32 verifies. Inline nodes (no index)
  also re-key.
- Not done: porting the model into `car.gd` (owner decision, see HANDOFF / tmnf_physics §6).

## 2026-10-16 ~04:45 UTC — Session 9: TMNF port and Stadium remake started (M8)

- Owner: "Yes" (port TMNF's model as SpeedFest's default) + a separate TMNF remake in Godot; answers
  recorded in TRANSCRIPT and PLAN M8 (recreated assets only, campaign/TMX maps read at runtime from
  the player's files, Godot 4.7 Forward+).
- New project `stadium/` (Forward+, Jolt, 100 Hz physics, interpolation). `core/tm_tuning.gd`
  holds every TMNF constant and curve; `core/tm_car_model.gd` is the handling tick (steer slew,
  per-wheel side grip with slide states and the damper factor, uncapped axle yaw damping + steering
  torque, staircase drive with speedslide blend, brake caps that flag sliding, coasting drag, wall
  slow-down, slope adherence, turbo, dirt, air control and drag). Steering/drive/brake only run with
  a wheel on the ground, like TMNF.
- `stadium/tests/test_model_lab` 44/44: 0-100 1.74 s, 0-400 12.18 s, radius 15.75 m @ 100 km/h,
  48.2 @ 200, 132.6 @ 400, slip < 1.1°, brake 100 km/h -> 1 m/s in 1.36 s / 12.9 m, brake-tap drift
  heading 100° / exit 218 km/h, turbo 42 / 147 m/s², wall slow-down 500 ms, air 2.5 g / no steering.
- Decompiled `M6GetModulationFromDamperAbsorbVal`: side-grip cap × curve 0x224 at
  (len − 0.7)/(0 − 0.7), len = suspension length (1.0 at rest, 0.51 fully extended).

## 2026-10-16 ~05:30 UTC — Session 9: Stadium remake car body (M8-2, part 1)

- Decompiled the contact layer (`WheelAbsorbContact`, `AbsorbContact`, `SDynaMath::ComputeImpulse`,
  `CHmsZoneDynamic::PhysicsStep2`, `ComputeForces` order): every sub-step runs suspension ->
  force model -> integrate -> collide. Sub-steps n = round(dt·(|v|+|ω|)/0.3)+1. ComputeImpulse leaves
  `k` of the velocity along its direction: wheel on the ground keeps 0.8, wheel side and chassis
  keep 0.5; the chassis direction is the approach clipped to a friction cone (μ 0.3, metal 0.2);
  a wheel's penetration along the car's up axis goes into its suspension (up to its length), and
  when the spring can take the vertical approach only the rest is stopped (at the wheel centre).
- `stadium/car/tm_car.gd` (`TmCar`): our 100 Hz rigid body with those rules; wheels and chassis are
  convex ellipsoids queried with Jolt's `collide_shape` (contact pairs clustered per surface
  direction), surfaces from collider metadata (`surface`, per-face `surfaces`, `pad_dir`).
- `stadium/tests/test_car_body` 22/22 (settles at 0.44 m with 0.013 m suspension, 0-200 4.26 s,
  radius 15.7 m @ 100 / 48.2 @ 200, brake 200 km/h in 2.0 s / 39 m, 10 m drop lands on the wheels
  at speed, 15° wall at 200 km/h glances off without flipping). `stadium/tools/test_all.sh` runs
  both labs (STADIUM_TESTS PASS).

## 2026-10-16 ~06:30 UTC — Session 9: Stadium remake drivable test scene (M8-2, part 2)

- `stadium/race/drive_test.tscn`: TestArena (32 m block-grid floor, curved-base 15° kicker, helix
  loop r 16 m, wall-ride quarter pipe, wall), the TmCar with a placeholder look built from its
  collision ellipsoids (`car/tm_car_visual.gd`), keyboard/pad input (`car/tm_car_input.gd`, digital
  keyboard steering like TMNF) and a chase camera that follows the car's up axis on the ground
  (`car/tm_camera.gd`). Enter/Backspace respawns. `env/proc_geo.gd` builds ribbons/quads with
  matching render + collision winding.
- `stadium/tests/test_car_shapes` 11/11: kicker at 200 km/h flies 1.39 s level and lands on its
  wheels; the loop at 250 km/h (with a player-like steering controller following the offset)
  completes upright without chassis hits; at 180 km/h the car can't make the top (3 g on the
  ground), as expected; the quarter pipe at 220 km/h ends in a stable wall ride at ~51° tilt.
- Found while testing: a sharp crease from flat to 15° bounces the car into a nose-down spin
  (0.9 rad/s); with a curved base it flies level. Recreated TM ramps need curved bases too.

## 2026-10-16 ~07:15 UTC — Session 9: Stadium remake reads TMNF tracks (M8-4)

- The official campaign is 65 plain `.Challenge.Gbx` files in a TMNF install
  (`GameData/Tracks/Campaigns/Nations/<White|Green|Blue|Red|Black>/`), not in the packs: the remake
  can read them at runtime from the player's own install (nothing is copied into the repo).
- `stadium/gbx/`: `lzo1x.gd` (LZO1X decoder, hardened against truncated input), `gbx_stream.gd`
  (GBX reader with lookback strings, idents, file refs, inline nodes), `tm_challenge.gd`
  (`TmChallenge.load_file`: name, author, uid, decoration, medals from the challenge parameters,
  lap race, size, blocks with direction, 32x8x32 coord, ground flag (bit 12), skins). Parsing stops
  after the blocks chunk (media clips follow and aren't needed). Python prototype:
  `tools/research/tmnf/gbx_challenge.py`.
- `stadium/tests/test_gbx` (with `--tmnf=/path`, or `TMNF_DIR=... stadium/tools/test_all.sh`):
  65/65 campaign tracks in 0.33 s, 41,523 blocks, 242 block types; A01-Race author 24.54 s,
  gold 25.87 s. Next: the block library (M8-5); the campaign's block-type list is the target.


## 2026-10-16 ~04:10-08:00 UTC — Session 8 (Pi, auto-continue): M7-6 maps finished on `m7-maps`

- Batches 5-6: Skyline Hop (rooftop hops + rail), Drop Zone (stunt drops), Rally Stage
  (dirt/gravel), Spiral (banked climb), Neon Rush (speedfun), Zig Zag (tech, side pads),
  Coastline (fullspeed), Grand Finale (mixed). 24 new maps, 34 tracks. AutoDriver (m7 handling)
  6 cars × 24 maps, 0 respawns, 13-25 s. Fixes found on the way: rails need the car to arrive
  within 0.35 m of ride height, so a rail after a gap starts just below the ledge (Skyline);
  loops entered at 300+ km/h stall at the top (Grand Finale: no boost before its loop).
- Private-room track chips scroll (two rows visible) so the room view fits 34 tracks.
- Weather puddles for all new maps (bd65cbc): test_weather 193/193, test_tracks 649/649.
- These were merged by session 9 into `tmnf-physics` (except bd65cbc, see HANDOFF).

## 2026-10-16 — Session 9: SpeedFest port paused; remake continues on branch `stadium`

- On `tmnf-physics` (not merged): TmBody's phantom-wall fix (shallow contact pairs take the face
  normal: float32 world points made 0.01 mm contacts read as vertical), AutoDriver TMNF yaw-rate
  steering with curvature feed-forward and an integral term, physics suites retargeted to TMNF;
  AutoDriver 34/34 tracks with 1 respawn. Details in that branch's PROGRESS.
- Owner: "Focus on the TMNF port first. After that, port car physics to speedfest after my
  approval." The SpeedFest port waits for approval; the remake's files (stadium/ with the shared
  TmBody, the research doc's load-transfer fix) come to main through branch `stadium`.
  Stadium tests 80/80.


## 2026-10-16 — Session 9: Stadium block library (M8-5), branch `stadium`

- Measuring (local only, nothing from the packs is committed): the TMF pack decryptor now handles
  block infos and solids (re-key on typed inline nodes, parent-id exceptions, body-only scan with a
  node-index check, root re-key after the reference table): 239/242 campaign block types parsed and
  532 collision meshes measured as JSON in the scratchpad (`tools/research/tmnf/`: pak_generic,
  pak_search, blockinfo_dump, extract_surf, export_blockinfo; describe/section/section_loop print
  numbers from a measurement).
- `stadium/blocks/data/block_catalogue.json`: layout data only (296 blocks: footprint units, clips,
  spawn, waypoint, shape names per variant). `TmBlockCatalogue`: TMNF placement (dir rotates
  (x, z) -> (-z, x), the rotated footprint's min corner at coord x (32, 8, 32), Godot = TMNF with x
  negated), checked on the campaign: 96.8% of classic-block clips meet a clip. `TmMapBuilder` builds
  a map from the library (placeholders where a shape isn't recreated); `race/map_view` shows it.
- `TmGeo` (faces authored in TMNF coords, per-face surface ids for TmBody, wall sweeps with sheared
  ends and per-point section heights), `TmMaterials` (flat-colour palette).
- Families, checked by `tests/test_block_fidelity` (rays every 1 m vs the local measurements):
  - **Circuit** (base, borders, curves, diagonals, slopes): every measured shape 97-100%. Measured
    rules: ground variants lift only the wall below the 8 m ledge onto the terrain; curves (but the
    1x1 outer corner) lower the top to 13.81 m in the middle (ramps 5-10 m from each end, 2-6 m on
    the 1x1 inner corner); a curve's ledge fills only its footprint cells; diagonals are the
    straight section sheared along each cell edge, mitred in the middle; slope Top/Bottom walls use
    measured section tables (section_loop.py).
  - **Tube** (pipe roads, junctions, up/down/cross, pillars 1/4/8, caps, branches): 100% on every
    plain shape (hub collars mitred against the other arms reproduce TMNF's merged junctions);
    the decorated light/sound-system tubes are approximations (70-93%).
- `tests/test_blocks` (no install needed): builds every catalogued shape a family recreates (108 of
  578) and checks mesh, collision/surface ids and footprint bounds; in `tools/test_all.sh`.
  Stadium tests: lab 44, body 22, shapes 11, gbx 3, blocks 3. A01 builds 330 of 393 blocks.

- Later in session 9 (`stadium`): **Platform** (decks: a slab whose closed sides end in a lip over a
  fabric skirt, swept and mitred per side; turbo plate; checkpoint arch; grid/border/screen walls from
  a measured plan section): roads 99-99.5%, walls 99.7-100%. **Road/Main** (the measured road section
  swept along straights, slopes (sheared 8 m per block), corners and GT curves 2-5; T/cross junctions =
  deck + straight curbs on closed sides + the curb revolved round each open corner; crowned dead ends
  and base with a low nose; turbo/free-wheel pads with their U-frame and pods; checkpoint, start,
  finish, multilap gates): plain pieces 96.8-100%, decorated gates 89-91% (thin posts, sign plates).
  The start block wasn't decryptable; its ground variant's measurement gave its layout (road from
  z 8, line near z 28). **Terrain zones**: dirt/water fields; dirt hills, pools, dirt borders as our own
  bicubic surfaces through measured control heights (9 x 9, 4 m apart; `blocks/data/zone_heights.json`
  from `tools/research/tmnf/zone_heights.py`): hills 71-95%, dirt borders 95-100% (decorated dead ends
  use the plain one), pools 27-82% (the survey smears the basin walls). Placement: zone tiles at their
  terrain level (level 0 = 9 m), a hill at level L spans levels L-2..L; the map builder lays collidable
  grass on every cell without a zone tile. Pools are the banks round water cells.
- Campaign maps now build mostly from recreated shapes, e.g. A13 422/465, A06 430/450, E03 1010/1196.
- Later in session 9 (`stadium`, 9688fb7 .. 26bc002): **Control** (camera and glass galleries swept
  like roads, with corners, junction plans with rounded notches, the round pavilion base, half-round
  dead ends and ground plinths; the pub's pipes with screens): galleries 88-100%, pub 62-91%.
  **Inflatable** (scalloped cushion walls, straight and round corners, roofs; cactus, palm, snow tree
  and castles as simple primitives): walls 84-95%. **Platform loops** (the grid-wall plan swept round
  quarter circles, start and end sharing a centre): 84-92%. **Road slope transitions** from measured
  height profiles (bi-slopes, S-ramps, crest, valley): 93-99.9%. `tests/campaign_coverage`: 93.8% of
  the campaign's 41,523 blocks are built or empty. Most used missing shapes: Fabric (~550), Sculpt
  (~350, decoration), Road/Dirt (~300), Platform/ToRoad (~120), road tilt (~100), GTDiag (~100),
  Platform 2-unit slopes (92), GT-curve platform walls (~80), the vertical checkpoint ring (44).

## 2026-10-16 — Session 9: race flow (M8-6 step 1), branch `stadium`

- `race/tm_race.gd` (`TmRace`, pure logic): a 1.5 s countdown with the car held still, then the race
  clock in 10 ms ticks (one per physics tick); checkpoints in any order, each once per lap; the
  finish (or the lap line on the last lap) counts only with every checkpoint of the lap; laps
  (`nb_laps` when the map is a lap race); respawn at the last checkpoint or lap line (the clock keeps
  running), a restart when none is taken or after the finish; medals against the map's times.
- `race/tm_triggers.gd` (`TmTriggers`): checkpoint, finish and lap-line triggers as TMNF has them:
  thin gate-shaped slabs (0.4 m thick). Measured from the packs' 17 trigger solids (local only); the
  repo keeps our own description: each slab's mid-plane and its cross-section outline (road gates at
  z 16, the finish at z 12, platform gates at z 15.88, rings as 18-gons of radius 13.26). A car takes
  a trigger when its centre of mass crosses the mid-plane inside the outline between two ticks.
- `race/race.tscn`: a map from the player's files (`--map=` or `--tmnf= --track=`), the car on the
  start block (spawns are placed on the ground below them by a ray), the chase camera, the race HUD
  (`TmRaceHud`, TMNF's layout: clock bottom centre, speed bottom right, map and medal times top
  left, checkpoints/laps top right, countdown, checkpoint times and the result with its medal in the
  middle). The race steps the car itself after the clock (TmCar's own tick is switched off after
  add_child, which turns it back on). Keys: Enter respawn, Backspace/Delete restart.
  `race/tm_stage.gd` (`TmStage`) holds the map loading and the sky/horizon shared with map_view.
- `tests/test_race` (in `tools/test_all.sh`): rules and triggers always; with `--tmnf` it races
  tracks (`--tracks=A01,...`, default A01): the car rests through the countdown, launches, is driven
  through every checkpoint's trigger from its block and through the finish, which ends the race.
  All 65 campaign tracks pass (421 checks; 105 checkpoint blocks on 38 tracks are taken by hand
  because their shapes are not recreated yet: the vertical ring 44, grass 14, tilted road 19,
  tilted platform 15, dirt-high 8, sloped 5). Stadium tests: lab 44, body 22, shapes 11, gbx 8,
  blocks 3, race 37.
- A01 is not drivable end to end yet: the block after the start (Platform/ToRoad/ToRoadMainAir),
  the vertical checkpoint ring and the suspended bridge slope (plus its mirror, which the catalogue
  lacks) are placeholders.
- Block library, continued (`stadium`): **Platform/ToRoad** (Road/Main onto the road-level platform
  floor where loops begin: curbs turned out round the edge, or one running across on a measured 83 m
  arc; the ramp from a deck up to Road/Main: the road section swept through measured heights; 97.6-100%).
  **Vertical checkpoint ring** (measured section revolved over four arcs; 98.5%). **Platform slopes**
  (the lipped plate sheared through measured profiles on a central pillar; 99.5-99.7%) and **sloped /
  banked platform checkpoints** (the flat one sheared: `TmGeo.shear_y`). The **platform checkpoint**
  rebuilt from measurements (a closed deck; the arch is the ring's section revolved about a lower
  centre; leaning billboard, curved struts, legs; 93 -> 96.5%). **Dirt roads and dirt hills**
  (Road/Dirt, Road/DirtHigh: 53 shapes): TMNF's are hand-sculpted terrain, so each is our own bicubic
  surface through control heights surveyed every 2 m over its footprint (`blocks/data/dirt_heights.json`
  from `tools/research/tmnf/terrain_heights.py`, grass/dirt/asphalt per cell); dirt checkpoints = the
  straight's terrain under a gate. Plain pieces 89-100%, sculpted embankment sides ~90%; fences,
  signs and awnings on some dirt pieces are not recreated yet.
- Fixes: race waypoints are recorded even for blocks without geometry (the dirt checkpoint's empty
  shape name had dropped 23 campaign checkpoints from the race; the exporter now names the two
  mobils it couldn't resolve); `test_blocks` fails when a family script doesn't load (a parse error
  used to pass); respawns over jumps stay in the air (only 2.5 m of ground snap).
- Open question noted: the measured material table maps Stadium grass to surface 0 (concrete); the
  remake keeps grass = 2 (TMNF's slippery grass) for the ground, zones and dirt-road edges.
- A01's route is fully built (only Sculpt decorations left). Campaign coverage 95.7% built or empty;
  race test: all 65 tracks, 421 checks; 36 checkpoint blocks still taken by hand (grass 14, tilted /
  sloped road 22).

## 2026-10-16 — Session 9: drivable road pieces finished, curves at TMNF's resolution, hand-off kit (branch `stadium`)

- **Tilted roads** (`blocks/shapes/road.gd`): pieces lying in one tilted plane are their flat
  counterpart sheared by a fitted plane (`TmGeo.shear_y`: straight, corners, GT curves, tilted and
  sloped road checkpoints); banked curves sweep the section with the bank in the lateral; flat-to-tilt
  transitions run through separate measured ease tables for the bank and the centre's drop (95-99.7%).
- **GT diagonals** (S-curves, 2x2/3x2/4x3, mirror/slope/tilt variants), **grass checkpoint** (the road
  gate over the grass), **road holes** (the section clipped round the opening) and **hole pillars**
  (grate, round pillars through it).
- **Platform GT-curve walls** (`2Wall1Air`): the grid panel on the 32k-radius arc, full-depth rails,
  frame posts at the joints (100%).
- **Y junctions** (Road/Main/YShaped Curve2, Diag2, Diag2SlopeUp/Down): one branch (the 2-block GT
  curve or GT diagonal, both ending at the top centre) clipped at x 48 plus its mirror image; the outer
  curbs meet in a V exactly as measured (98-100%). New `TmGeo.clip(n, d)` (keeps n . p <= d, cuts
  crossing triangles) and `TmGeo.add_mirror_x(a)`. E02 is now fully built (907/907 blocks).
  Measurement quirk: Diag2SlopeUp's mesh sits offset by (40, 0, 80) under a location the extractor
  doesn't apply; the fidelity check used a local copy moved back (98%). The piece is unused in the campaign.
- **Curves at TMNF's resolution:** the measured meshes show TMNF's quarter circles in 16 (corner),
  32 (GT 2), 48 (GT 3), 32 (GT 4) and 96 (GT 5) segments; ours had 8-21, and the chords pulled the
  curbs in by up to 0.3 m. `CURVE_STEPS` fixes road and tilted-road curves: GT curves 95.3-99.5% ->
  99.9-100%, tilted curves 99.1-100%.
- **GT diagonals from TMNF's own frames:** each sweep frame leaves three asphalt vertices (left
  edge, centre, right edge); `tools/research/tmnf/sweep_frames.py` extracts them (33/65/41 frames for
  2x2/3x2/4x3: centre, lateral angle, width scale) into `blocks/data/gt_diag_frames.json`, and the
  diagonals sweep through them (94-98.8% -> 99.7-100%). The 2x2 centre line is the cubic Bezier
  (16,0) (16,32) (48,32) (48,64) at 32 even steps (within 0.05 m); the 3x2 and 4x3 are not single
  cubics (asymmetric), so the frames are kept as data.
- Catalogue regenerated from a from-scratch measurement run (7 names the old decrypt had corrupted
  fixed, 10 blocks added: tilt and tube clips, the bridges' mirrored and end halves): no unknown
  campaign blocks left.
- **Playable:** `race/race.tscn` is the project's main scene (press Play): it finds TMNF in its usual
  install folders (or `--tmnf=`, `TMNF_DIR`) and races A01; a message instead of quitting when TMNF
  isn't installed.
- **Hand-off kit for another agent:** `stadium/CLAUDE.md` (read order, rules, what is never in the
  repo, setup, tests, how a block family gets recreated, gotchas, current state);
  `tools/research/tmnf/setup_measurements.sh WORK` recreates the TMNF install and every measurement
  from public sources only (official installer checked by SHA-256, ModTMNF, GBX.NET; about 10 min,
  669 meshes, byte-identical to the earlier run).
- `map_view` `--view=near:<BlockId>[:index[:zoom]]`.
- Numbers: campaign coverage 96.8% built or empty (41523 blocks, 1309 placeholders, 0 unknown; the
  rest is almost all decoration: Fabric, Sculpt, inflatable tubes/adverts, airship); every campaign
  checkpoint is built: `test_race --tracks=all` (new: every campaign track found in the install)
  passes all 65 tracks, 421 checks, none taken by hand.
- `stadium/CLAUDE.md` now has a "Where things stand" section: the live to-do list for the next agent.

## 2026-10-16 — Session 12 (owner's Windows PC): Windows toolchain, slope turns, Stretch, turbo gates (branch `stadium`)

- **Runs on the owner's Windows PC:** Godot 4.7.2 from `C:\dev\godot-4.7.2` (`/c/dev/bin/godot`
  wrapper; `GODOT=` also works); `stadium/tools/run.sh` opens a real window where there is no
  `xvfb-run`. `setup_measurements.sh` works in Git Bash: `PYTHON=<venv python>` (pycryptodome,
  py7zr), `innoextract.exe` on PATH, `sfx7z.py` unpacks the installer's 7-Zip SFX without 7z;
  `decrypt_all.py` uses `sys.executable` and a subprocess timeout (no `python3` / `timeout`
  binaries), `campaign_blocks.py` takes track names with `os.path.basename`. Full run from scratch:
  669 meshes (same as the cloud run), about 18 min. Baseline on Windows: STADIUM_TESTS PASS,
  coverage identical (96.8%).
- **Circuit slope turns** (Circuit/Slope/Corner, GTCurve/2, Diag; In/Out x Left/Right x
  Top/Bottom, 24 shapes): `radial_section.py` (new) shows every radial section is the flat wall's
  once y -= 0.5 z is taken off, so each piece is the flat border (wall + ledge) turned by quarter
  turns about the footprint's centre (In: RightBottom 0, LeftBottom 1, LeftTop 2, RightTop 3; Out:
  LeftBottom 0, LeftTop 1, RightTop 2, RightBottom 3), sheared y += 0.5 z, and dropped onto the unit
  under its lowest point (the Out Bottom pieces sit 8 m lower). Fidelity equals the flat walls':
  Out 99.3-99.7%, GT2 out 99.1-99.2%, GT2 In 98.1-98.2%, In corners 97.6-97.7%, In diagonals
  97.3-97.6% (flat In corner 97.9%). New `TmGeo.turn_y`, `TmGeo.min_y`.
- **Road/Main/Stretch** (Air, Ground, SlopeAir, TiltAir): a straight whose curbs close in to the
  middle (7.479 m each side at z 16) and open out again; the section only translates, through
  TMNF's 21 frames (`STRETCH`: every shift a multiple of 7.479 / 62). 99.4-99.8%. New `p_at` hook in
  `TmGeo.wall_sweep` (per-frame section points).
- **Turbo gates rebuilt from measurements:** the road turbo's sides are a booster pod (collar round
  the fan r 1.95, body r 1.72 through the frame, cap behind it; revolved with the new
  `TmGeo.revolve_z`, moved from platform.gd) and a grid tray between two thin translucent panels,
  level over the pod and frame, then down to the curb. Flat turbo 91.1% -> 99.7%. Up/Down/Left/Right
  (Air, Ground) = the pad sheared like the checkpoint of that slope/tilt, the sides kept rigid
  (lifted with the road at their axis, only the slope shears them; on an up-slope the tray's level
  part stays at its height over the frame): 98.5-99.5%. Platform/Turbo/Up/Down/Left/RightAir = the
  flat platform turbo sheared like the platform checkpoints (94.5-97.4%; the flat one is 96.3%,
  both miss some structure under the deck).
- Numbers: STADIUM_TESTS PASS (with TMNF_DIR: gbx 8, race 37); campaign coverage 96.8% -> 97.2%
  (placeholders 1309 -> 1183).
- **All drivable campaign shapes built** (same session, second batch):
  - **Ramp** (Ramp/Air, Ground, LowAir, LowGround): the dead-end road plus a thin plate (0.207 m;
    grid with 2 m metal edges; trapezoid plan, half-width 8 m at the lip to 10 m at the road)
    rising through TMNF's 33 frames to 7.95 m at z 1.985 (Low: half the lift), two struts under
    it. 98.5-99.0% (the misses are the dead end's rounded curb ends, shared with Road/Main/Deadend).
  - **Zone clips** (Zone/Grass/Clip, Zone/Dirt/DirtClip): the triangle TMNF sets where terrain
    meets other blocks, on the terrain (probe: world y 9 on the ground, the zone's top on a dirt
    zone). 100%.
  - **Loop** (Loop/Left|Right, Air|Ground): half a vertical loop per block: base circle radius 44
    about (y 44, z 0), 64 frames of 180/64 deg, 1 m sideways per frame (64 m: the loop clears
    itself), lateral along x; road section for the first and last 4 frames, then the loop's
    section (the road's curbs, grid between, a shallow keel). 97.6% (the struts inside the loop
    and the outer underside are not recreated).
  - **Tilt transitions along a GT diagonal and round a GT curve** (Road/Tilt/Transition/2Diag*,
    2Curve*): TMNF's 25 frames each (`TILT_DIAG`, `TILT_CURVE`: centre, lateral angle, bank; both
    use the same bank per frame), Right = Left mirrored. 98.9-99.4%.
- Numbers after the batch: STADIUM_TESTS PASS; test_race --tracks=all 65/65 (421 checks, 1.5 min
  on the RTX 2060 PC); coverage 97.3% (1111 placeholders, all of them
  decoration: Fabric, Sculpt, inflatable tube/advert pillars, airship, camera lights/pubs).
- **Fabric grandstands** (`blocks/shapes/fabric.gd`, new family; 14 shapes, ~590 campaign blocks):
  the white wave roofs. Straight (ground): the roof shell, 0.3-0.4 m thick, swept along the block
  through its measured section (foot at x 60, top 48 m over x 0), the stands (quarter-pipe front,
  seats at 8.26 m) and the rubber lip at the foot; Air: its own shorter shell on an 8 m deck and one
  support wall. Pillars: the fabric wall carrying a raised roof down (open post in the middle, as
  TMNF's posts have no caps) and the one-cell ground stands; Cross1x1: the flat roof plate.
  Corners: the straight's sections revolved through 90 deg in 18 steps, In about (0, 0), Out
  about (64, 0) with the radius 64 - x and the rest roofed flat at 48 m; the raised In corner has
  its own taller shell (to 1.5 m) on a low deck. In pillar corners run each section point round an
  arc about (5.533, 5.533) meeting both block edges (17 steps). The fabric is a road surface in
  TMNF (asphalt, 16): cars can drive on the roofs. Fidelity: Straight 98.7%, Air 96.3%, Cross and
  PillarGround 100%, PillarAir 97.4%, Out corners 99.3-99.5%, In 95.5%, In Air 89.7%, pillar
  corners 86.7-99.3% (trusses, screens and spotlights not recreated yet).
- Coverage 97.3% -> 98.8% (517 placeholders: Sculpt, inflatable tube/advert pillars, airship,
  camera lights, Fabric/FabricPillarCornerOutAir, Cross3x3); test_race all 65 tracks, 421 checks.
- **Sculpt landmarks (A01 fully built)** (`blocks/shapes/sculpt.gd`, new family): hand-sculpted
  pieces are lofts. `tools/research/tmnf/loft_sections.py` (new) slices a measured mesh by planes
  every 1 m (horizontal, or across z for leaning pieces), follows each closed loop up the piece,
  resamples it to a fixed ring (start matched to the ring below, so twisting blades stay smooth),
  closes ground-standing sections, and ends each tube at an apex, a base point or a flat top; the
  rings (our own resampled numbers, cm) go to `blocks/data/sculpt_lofts.json`
  (`tools/research/tmnf/sculpt_lofts.sh MEAS` regenerates it). Sculpt/A (two twisted blades to
  92.6 m), B (two blades to 97.3 m), C (six columns to 92 m) on their shared plinth (rubber pads,
  a double curb round each blade's foot): 92.8%, 93.3%, 99.1%. The suspended bridge pair
  (BridgeSuspendSlope2 and its x-mirror: a slab falling from 200 m to the ground, a strut rising
  back, side struts): 90.0-90.1% (the crest road bits and see-through awnings not recreated).
  A01 now has no placeholder (373 built, 24 empty). Coverage 99.1% (386 placeholders).
- **All Sculpt pieces** (23 shapes): the rest of the bridges (straights, slope starts/ends,
  pillars, the suspended end; bodies with the slab section, side struts, rails) and the arch rings
  (rising curves 130 x 106 x 185 m) lofted across z; pillars up y with flat tops; every Mirror
  piece is its partner mirrored in x (98-100% of vertices; the arch rings about x 64). The loft
  rings now keep corners (the nearest sample snapped onto each vertex turning more than 20 deg):
  blocky sections keep their edges (bridges 83 -> 94%, Sculpt A 92.8 -> 98.3%). Fidelity: Sculpt
  A/B/C 98.3/97.2/98.5%, suspended pieces 95.3-95.9%, arch rings 93.0-95.8%, straights 94%,
  slopes 87.5-91%, pillars 80.7-81.7% (their stepped heads). test_blocks: OVERHANG for pieces TMNF
  builds past their footprint (Sculpt/B, arch rings). Loft data 657 KB.
- Coverage 99.8% (100 placeholders: inflatable tube/advert pillars, airship, camera lights and
  pubs, three Fabric pieces, one bump); test_race all 65 tracks, 421 checks.
- **Last decorations: campaign coverage 100%** (0 placeholders on all 65 tracks):
  inflatable tube T-pillar (the cushion wall, a flared box, its frame and the tube's pipe with a
  rubber ring; 94.6%) and advert T-pillar (a 64 x 32 m cushion wall carrying a billboard frame and
  posts; 91.6%); the airship (a z-loft of the blimp, gondola and fins; 95.6%); camera lights (the
  rig's measured section along z, 93.2%, and its right half revolved for the round base, 83.1%)
  and camera pubs (a rounded block with side screens, 98.9-100%); Fabric: the Out pillar corner
  post (98.5%), the 3 x 3 roof (flat plate round a 35 m opening, the tilted canopy, the advert
  boards; 94.5%) and its screen variant 32 m higher with the big screen lofted under it (95.0%);
  Road/Main/Bump (the curbs level, the asphalt dipping 1.86 m; 81%).
- Numbers: STADIUM_TESTS PASS; test_race all 65 tracks, 421 checks; coverage 100.0% built or empty.

## 2026-10-16 — Session 12: ghosts and best times (M8-6 step 2), branch `stadium`
Owner: "Start M8-6: ghosts and best times first, then the stadium environment, our own car model,
menus and sounds."
- `race/tm_ghost.gd` (`TmGhost`): a run as poses every 20 ms (position, rotation, steer, speed),
  played back between samples (lerp/slerp), held at its last pose; saved as a small binary file
  ("TMGH", version 1; 1.8 KB per second of driving).
- `race/tm_records.gd` (`TmRecords`): the best time per track (its uid; the name for maps without
  one) with its splits as JSON plus its ghost, in `user://records` (`--records=<dir>` for tests).
  Only a strictly faster finish replaces the record.
- `race/race.gd` records every run while racing; at the finish it submits the run, and a new record
  becomes the ghost at once. The record's ghost (a translucent blue `TmCarVisual`, no shadow;
  wheels spin and steer from the recorded speed and steer) waits at the start through the countdown,
  drives with the race clock and goes 1 s after its finish.
- HUD (`race/tm_race_hud.gd`): "Best" under the medal times; at each checkpoint, lap and the finish
  the difference to the record's split (-0.12 blue = ahead, +1.05 red = behind, as TMNF shows it);
  "New record!" at the finish.
- Tests: `tests/test_ghost` (19 checks: sampling, save/load, records, deltas); `test_race` checks
  per track that the finish saved a record and its ghost and that the ghost waits at the start
  after a restart. STADIUM_TESTS PASS; test_race all 65 tracks, 616 checks (421 before).

## 2026-10-16 — Session 12: stadium environment, step 1: Day sky and sun (M8-6), branch `stadium`
- `env/tm_stadium_env.gd` (`TmStadiumEnv`) and `env/tm_sky.gdshader`: TMNF's "Day" mood from our
  own numbers read off its files (decrypted locally: `ConstructionDecorationMood/Day`, the
  `Moods/Day/*.tga` colour tables at its day time): latitude 48 deg, day time 0.65 (15:36, an
  equinox sun: 23 deg up in the south-west, TMNF north = +z), sun white at intensity 1 with shadow
  intensity 0.4, ambient (94, 96, 108), the sky gradient (17 stops, zenith (62, 105, 159) to horizon
  (213, 229, 240)), clouds between (196, 209, 218) and (250, 251, 251). The sky shader draws the
  gradient, the sun's disc and glow and an fbm cloud layer; linear tone mapping (the mood's colours
  as they are), light haze, SSAO and a little glow. `TmStage.add_environment` uses it.
- The stadium surround found: `Zone/Square32.Solid.Gbx` (10.5 MB, visual only) holds the whole
  Stadium around a 32 x 32 map: two lens-shaped grandstands on the long sides (a 20 m wall, a
  seating rake to a 46 m deck, a roof from 130 m at the field down to 84 m, masts on the midline),
  terraces on the short sides with the big screens, six flagpoles a quarter and a floodlight tower
  at each end, then roads, forecourts and parking down to an edge 100 m below the field. New tools:
  `visual_mesh.py` (visual meshes and lights of a solid), `vsection.py` (vertical and plan cuts as
  PNGs). Next: rebuild it from our own measured profiles and outlines.

## 2026-10-16 — Session 12: stadium environment, step 2: the Stadium around the map (M8-6)
- `env/tm_stadium_build.gd` (`TmStadiumBuild`): the Stadium rebuilt from our own measurements of
  TMNF's surround (tables in the script; one quarter, mirrored in x and z):
  - two lens-shaped grandstands on the long sides: the inner wall line at 10 m (17 points to the
    tip at x 644), the section swept along it and clipped at the midline (z 746.1), mirrored for
    the outer half. The section: a 20 m wall, a ledge, the seating rake to the 46 m deck, a glass
    screen behind it; a ribbon of LED boards along the inner face;
  - the roof band over each grandstand's inner half: a visor from the field edge (z 528.8), a
    thick main part to the back (z 785), arched along x from 120.5 m at the middle to the wings
    dipping past the tips (table every 100 m to x 725); a tube along its front edge, beams under
    it every 45 m;
  - masts at x 0, 430 and 876 on the midlines (270 m) with cables;
  - terraces on the short sides (the section at z 100 swept along the inner wall line), the big
    screens (x 822, 158 x 81 m), six flagpoles a quarter (229 m) with flags in our own colours,
    and four floodlight towers with lamp heads facing the field;
  - the apron at the field's level inside the bowl, the ground falling to the outer level
    (-19.5 m) outside it, the edge down to -100 m and a plain beyond.
  351 ms to build, 25k triangles. `TmStage.add_environment` adds it around 32 x 32 maps (all of
  TMNF's Stadium maps); other sizes keep the plain grass.
- Not yet: the outer roads, forecourts and parking (the outer ground is plain concrete), the
  roofs' light panels, textures (flat colours, like the blocks).
