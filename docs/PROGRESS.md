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

## 2026-10-16 — Session 12: our own car model (M8-6), branch `stadium`
- `car/tm_car_visual.gd` rewritten: our own open-wheel Stadium car instead of the placeholder
  ellipsoids. Proportions measured from TMNF's car visual locally (`visual_mesh.py` on
  `StadiumCar.Solid.Gbx`: 3.94 m long, 1.64 m wide body, 1.1 m tall, the driver just behind the
  middle, guards over the front wheels, pods over the rear ones; the visual's origin sits 0.441 m
  below and 0.29 m behind the physics origin); the shapes are ours: lofts of superellipse sections
  (Catmull-Rom between our stations) for the nose tub, the engine body, the sidepods and the
  airbox; the helmet with its visor; front guards that steer with the wheels, rear pods; wishbones
  and driveshafts; lathed tyres with five-spoke rims; floor, splitter, spoiler and rear lights;
  our livery (red, white pods and airbox, carbon parts). The ghost uses the same model,
  translucent blue. The TmCarVisual API is unchanged.

## 2026-10-16 — Session 12: TMNF-like menus (M8-6), branch `stadium`
- `ui/menu.tscn` (`ui/tm_menu.gd`, `TmMenu`) is the project's main scene: the Stadium behind,
  our car on the field with the camera circling it, and the pages: main (Play, open a track
  file, options, quit), the campaign (the five series as tabs in TMNF's colours, each track's tile
  with your best time and a medal-coloured border, the selected track's name, author, medal
  times, your best and medal, Race; a second press on a tile races it), options (fullscreen,
  shadows, race against your best ghost, clear all records) and, without a TMNF install, what to
  do (or open a track file). Keyboard and pad work through focus; Escape goes back.
- `ui/tm_race_menu.gd` (`TmRaceMenu`): Escape pauses the race (resume, restart, menu); 1.5 s
  after the finish a panel under the HUD's result offers retry, the next campaign track and
  the menu (back on the campaign page with the track selected).
- `ui/tm_ui.gd` (`TmUi`): the theme (dark glass panels, white capitals, cyan accent) and the
  settings (`user://settings.cfg`). `TmChallenge.load_file(path, header_only)` reads only the
  header (name, uid, medal times) for the lists.
- `tests/test_menu` (12 checks with TMNF, 6 without): the pages, 65 campaign tracks, 15 tiles a
  series, the header-only load equal to the full one, details, a record on its tile and medal,
  Race handing the track over, pause/resume, the finish menu, retry. STADIUM_TESTS PASS.

## 2026-10-16 — Session 12: sounds (M8-6), branch `stadium`
- `audio/tm_sounds.gd` (`TmSounds`): every sound synthesized at start (our own, no sound files;
  0.3 s once): the engine under load (a harmonic stack of 110.25 Hz, odd harmonics stronger, a
  firing buzz, a little noise; one second of whole periods so it loops seamlessly) and off the
  throttle (softer), tyre skid (band noise with a squeal), wind (dark noise), and the cues:
  countdown beep and go, checkpoint, finish and record arpeggios, respawn whoosh, wall thud,
  turbo whoosh, menu click and move. `TmSounds.rpm(kmh)`: virtual gears (55, 105, 160, 220,
  290 km/h) each sweeping 5200-9800 rpm, so the note climbs and drops at every shift.
- `audio/tm_car_audio.gd` (`TmCarAudio`, in the race): the two engine loops crossfaded by the
  throttle and pitched by the rpm, skid while wheels slide on the ground, wind with speed, the
  countdown's beeps and go, checkpoints and laps, wall hits (from `wheel_hit_wall`), turbo
  starts; the race cues the finish (or the record), respawns. Menu buttons click; a Sound option
  mutes everything.
- `tests/test_sound` (12): streams exist and aren't silent, loops wrap whole, rpm in and across
  gears, the engine follows throttle and speed, the countdown. STADIUM_TESTS PASS; test_race all
  65 tracks with the menus and sound in the race: 616 checks.

## 2026-10-16 — Session 12: HD graphics: procedural textures and materials (M8-6), branch `stadium`
Owner: "Yes, continue with HD graphics: textures and materials for the blocks, the stadium and the car."
- TMNF's look measured locally (its textures viewed as a contact sheet, never copied): the
  Stadium's road is light concrete (165, 164, 161), not dark asphalt; platforms (166, 165, 162);
  grass (52, 75, 40); dirt (67, 61, 49); circuit panels dark with orange strips; parking blue.
- `blocks/tm_surface.gdshader`: one procedural surface shader, patterns drawn in world space
  (noise blended over the three planes, lines and tiles on the nearest plane; no UVs, so they run
  on across blocks): concrete (grain, stains, panel seams), grass (mown stripes), dirt (lumps,
  pebbles), perforated grid, brushed metal, turbo stripes, seat rows, animated screens and LED
  boards, fabric, louvres (the stadium roof's underside), wall panels, paving; bump-mapped from a
  height (screen-space derivatives), seams fading with distance. `TmMaterials` gives each key its
  pattern, colour and scale (`SURFACES`); two seamless noise textures feed it. Water: glossy deep
  teal with a world-space ripple normal.
- `car/tm_car_surface.gdshader`: paint with metallic flakes under a clearcoat and a white stripe
  along the top, carbon fibre twill, tyres with tread grooves, sipes and a lettering band.
- Sky clouds from a seamless noise texture (the hash noise showed blocks).
- Options: "HD graphics" (on by default; off = the flat colours, for slow machines; `--hd=0`).

## 2026-10-16 — Session 12: polish (owner's list, step 1), branch `stadium`
- The Stadium's outer ground now follows TMNF's: `tools/research/tmnf/stadium_ground.py` samples
  the measured surround's ground surfaces into our own coarse grid (one quarter: heights on 16 m
  cell corners, classes forecourt / road / grass / parking on 8 m cells;
  `blocks/data/stadium_ground.json`, 78 KB). `TmStadiumBuild._ground` builds the terrain from it
  (mirrored), and with HD graphics `env/tm_ground.gdshader` blends the classes from a smoothly
  filtered class map (curved borders, not steps): mown grass, asphalt roads, blue parking with
  white bay lines, paved forecourts.
- Lamp strips under the grandstand roofs (the visor's front and the main roof's edge, where TMNF
  has its glows); brake lights that flare when braking.

## 2026-10-16 — Session 12: menus restyled, fonts, online play (owner's list, step 2), branch `stadium`
- Menus and HUD in Orbitron (titles, times) and Rajdhani (everything else), both SIL OFL, from
  SpeedFest's own assets (`stadium/assets/fonts`): a styled title with an accent line, buttons
  with an accent bar when focused, a dark gradient behind the menu, pages fading in, key hints.
- **Online play like TMNF's time-attack servers.** `stadium/server` (Node.js + ws): an always-on
  room; 5-minute rounds on random campaign tracks (never one of the last 12), players restart as
  often as they like and their best time counts, live ranking, cars relayed 10 times a second,
  15 s of results, chat; a JSON status page for the server list; input cleaned and limited;
  `npm test` (5). The tracks stay on the players' own TMNF installs (the server sends only ids).
- Game: the `Online` autoload (`net/tm_online.gd`, WebSocketPeer) and `race/tm_race_online.gd`
  (other players' cars in their colours with name tags, our car sent 10 Hz, finishes reported,
  round clock and ranking on screen, chat on T, results, the next track loaded when the server
  moves on; Escape overlays the menu without pausing, "leave server"). Menu → Online: your name,
  your car colour (also your car offline), "join the official server" (its address is read from
  `stadium/server/official.json` in the repo, with a live status line) or any address.
- `tests/test_online` (8, needs Node; skipped without it): starts the server with short rounds,
  joins, races in online mode, sees a second player's car, its finish ranked, results, next
  track. The gate also runs the server's `npm test`. STADIUM_TESTS PASS.

## 2026-10-16 — Session 12: the official server, RTX graphics (owner's list, steps 2-3), branch `stadium`
- **The official server runs** on the owner's PC: `stadium/server/run_official.ps1` starts the
  server (bound to 127.0.0.1) and a Cloudflare quick tunnel (cloudflared from Cloudflare's GitHub
  release, signature checked, in `C:\dev\tools\cloudflared`); its address is published in
  `stadium/server/official.json`, which the game's "Join the official server" reads. Checked from
  outside: the status page answers through the tunnel and a game client joins over wss.
  `server/README.md` lists other hosts (a permanent one: Render, the Pi, any VPS).
- **RTX** (`stadium/RTX.md`): graphics presets Low / High / Ultra (Ultra: SDFGI, SSR, SSIL,
  volumetric haze, 4 shadow splits; checked in screenshots: bounce light and water reflections);
  on NVIDIA's fork (`env/tm_rtx.gd`, ported from SpeedFest's m7-rtx branch) DLSS with the Fast
  model on RTX 20/30 and experimental path tracing, all tested on this PC's RTX 2060 with the fork
  built in `C:\dev\godot-rtx`: DLSS renders correctly; path tracing renders the stadium and, with
  the standard materials it switches to, the car (soft shadows, reflections). `env/rt.gdshaderinc`
  makes our shaders compile as hit shaders. Settings can be forced per run with `--set_<key>=`.

## 2026-10-17 — Session 12: music (owner's list, step 4), branch `stadium`
- Eight instrumentals downloaded from OpenGameArt under open licences (no music of our own, as the
  owner asked): dark trap and hip hop: Trappist (Axton Crolley, CC BY 3.0), Friendly Trap mix
  (Of Far Different Nature et al., CC BY 4.0), the Instrumental Hip-Hop theme (Gichco, CC0),
  Cauliflower - Day 27 (Zane Little Music, CC0), ZeWrungVergeun, WiFi Trasherino and
  Baeddle;Ceity (Sudocolon, CC0), Dark-Waves-Hip-Hop (Dogers, CC BY-SA 3.0). Licences checked on
  each page; converted to OGG Vorbis (14 MB) with `soundfile` (in blocks: libsndfile's Vorbis
  encoder overflows its stack on one big write); credits in `stadium/audio/music/CREDITS.md`.
- `audio/tm_music.gd` (autoload "Music"): a menu playlist and a race playlist, shuffled,
  crossfading between tracks and across scenes, a "now playing" toast; options: music on/off and
  volume (quieter while racing, under the engine).

## 2026-10-17 — Session 12: recorded sounds (owner's list, step 5), branch `stadium`
- Our synthesized sounds replaced by open-licensed recordings (`stadium/audio/sfx`, credits in
  `CREDITS.md`, Kenney's licence files beside them): the engine under load is qubodup's rally-car
  loop (CC BY 3.0, about 7500 rpm), coasting domasx2's loop (CC0), tyre squeal audible-edge's loop
  (CC BY 3.0), wind SketchMan3's loop (CC0); cues and menu sounds from Kenney's Interface and
  Impact Sounds (CC0): countdown bong (pitched up for GO), confirmation chimes for checkpoints and
  the finish, a rising one for a record and turbo, a falling one for a respawn, a metal impact for
  wall hits, click and tick in the menus. `TmSounds` loads them (loops set to loop) and keeps the
  synthesized ones only as stand-ins for a missing file; the engine's two layers each have their
  own rpm reference. `tests/test_sound` (12) checks the recordings are used.

## 2026-10-17 — Session 12: exports and sharing (owner's list, step 6), branch `stadium`
- Godot 4.7.2 export templates downloaded from Godot's GitHub release (SHA512 checked against
  `SHA512-SUMS.txt`) and the Windows and Linux ones installed on this PC.
- `stadium/export_presets.cfg` (Windows, Linux: one executable each, data embedded; tests,
  tools and the server left out), `stadium/tools/export.sh` (exports and zips each build with
  `PLAYING.txt`, the music and sound credits and the font licences): Windows zip 52 MB, Linux
  42 MB. The exported Windows build checked: menu, a race (C03) with HD materials, HUD, music.
  `--race=B05` on the menu goes straight into a track (exported builds can't be given a scene).
- CI: `.github/workflows/stadium.yml` builds both zips on every push to `stadium` (artifacts) and
  attaches them to a GitHub Release on a `stadium-v*` tag. How to share: `stadium/README.md`
  "Share it with friends".

## 2026-10-17 — Session 12: standalone game, our own tracks (owner), branch `stadium`
Owner: "No, I want this to be a standalone game!!" and "But still, in the end if someeone wants to
load trackmania maps, such as gbx, then it should be doable in this game".
- **Our own tracks** (no TMNF needed): `stadium/tracks/SF01..SF10.json`, each a list of pieces
  (start, straights, road corners, GT curves 2-5, checkpoints, turbos, one- and two-level slopes,
  jumps, loops, any two-clip block) that `race/tm_track_builder.gd` (`TmTrackBuilder`) lays end to
  end on the block grid: each piece's entry and exit come from the block catalogue's clip sides,
  turned to fit; errors name the piece that collides or leaves the map. Raised road gets TMNF's
  pillars (a `StadiumTube` under the road, `StadiumTubePillar`s to the ground, under every other
  one-block piece, as the campaign does). Loops are laid like TMNF's (B13): two loop blocks, the
  second turned round behind and beside the first, the exit 4 blocks to the side.
- `race/tm_tracks.gd` (`TmTracks`): the list (file names = ids). `TmStage.load_from_args`:
  `--track=SF01` (the default), `--track=A01` from a TMNF install, `--map=` any .Challenge.Gbx.
- **The driving bot** `race/tm_bot.gd` (`TmBot`, race scene `--bot`): follows the line the builder
  lays through the track (`TmChallenge.path`: arcs through the curves, a helix through loops,
  blind over jumps), steering at a point ahead and braking for the turns ahead at a cornering grip.
  `tests/test_tracks` (in the gate): every track lays out, builds without placeholders, has its
  checkpoints and one finish, and the bot finishes it within gold at the track's `bot_grip`.
  `--write_medals`: the bot races at grips 30-75, its best time is the author time, gold +6%,
  silver +20%, bronze +50%. Author times: Kickoff 24.19, Drift King 33.98, Highline 34.77,
  Switchback 43.33, Full Send 26.61, Skyway 23.95, Night Shift 34.95, Corkscrew 34.71,
  Rush Hour 30.22, Last Call 39.44 (its checkpoint moved three blocks past a climb the bot
  flew over).
- Lessons from the bot: a two-level slope (SlopeBase2) launches the car over a checkpoint right
  after it; the high ramp at 340 km/h throws the car sideways (low ramps are fine at 270, flying
  about 110 m); **loops don't work yet**: in the loop the car decelerates at ~9 g with the wheels'
  contact flickering (not slip: lateral speed stays under 5 m/s; not the bot: the loop is a sheared
  helix, the bot follows it), even entering at 330 km/h; it falls before the top. The campaign's
  loops (B13, C04) are affected too. No shipped track has a loop until that's fixed.
- Menu: the campaign's first tab is ours (SPEEDFEST, tiles with the track names), TMNF's five
  series follow when it's installed, else a "+ TMNF TRACKS" page explains how to add them; Open a
  track file races any .Gbx. `tests/test_menu` covers both.
- Online: the server rotates our tracks by default (`stadium/server/lib/rounds.js` reads
  `stadium/tracks`; `--tracks=tmnf` or `TRACKS=tmnf` for TMNF's campaign); online play no longer
  needs TMNF. `stadium/server/restart_server.ps1` restarts just the node process (the tunnel and its
  address stay); the official server was restarted with the new code.
- `PLAYING.txt` and `stadium/README.md` (play, make a track, share) say the game is standalone.
- **Released `stadium-v0.1`** (the owner's earlier "Yes, tag stadium-v0.1 and push it", held until
  the game was standalone): tag on `befd60e`, CI built both zips and made the GitHub Release
  https://github.com/khanhonthetrack/speedfest/releases/tag/stadium-v0.1 (SpeedFestStadium-windows.zip 53 MB, -linux.zip 44 MB;
  release notes = PLAYING.txt). The exported Windows build was checked locally without TMNF:
  the campaign page lists the 10 tracks, Drift King races with its medals.

## 2026-10-17 — Session 12: loops fixed (the bot gets round them), new track SF11 Full Circle, branch `stadium`
- **Cause of the "9 g in loops"**: not the contact physics. TMNF's loop (measured `Loop/RightAir`:
  the curbs move 1 m sideways per 180/64-deg frame from frame 0 on) is a helix on a cylinder about
  the lateral axis: its road turns ~25.5 deg off the straight that leads in (unrolled), and back at
  the exit. A car going straight follows the cylinder's straight line, a vertical circle; the road
  drifts away and the outer wheel meets the curb ~13 m sideways (6 m up). The curb is a wheel side
  contact, so TMNF's wall slow-down (~60 m/s^2 for 500 ms, `WALL_SLOWDOWN`) brakes the car: the
  "9 g with wheel contact flickering" (the flicker is normal impulse contact under ~20 g). The bot
  steered, but its gain (2.2 x angle) is ~3x too low at 360 km/h, where TMNF's full lock only turns
  the car at ~0.86 rad/s (a ~116 m radius), and it aimed at the raw kink.
- Checked with the car put on the helix at the loop's entry (no steering, gas): 300 km/h goes round
  with 203 km/h at the top and no curb contact; wheel impulse losses are small (5-8 m/s^2 at the
  bottom, the persistent ~3 m/s approach the 0.8 impulse leaves); 30 m/s^2 ground gravity costs the
  rest. A loop needs about 280 km/h or more: at the top the car needs >= 129 km/h (30 x 42.7 m) to
  stay on the ceiling (269 km/h in: 85 km/h at the top, it falls).
- **The line** (`TmTrackBuilder`): the loop's helix now lies on the road (radius 44 - 1.345 m, it
  was the base circle) and `ease_loops` (after laying out) eases it into the drift over 40 m either
  side of the entry and the exit: in the loop unrolled flat, a parabola between the two straight
  lines, at most 4.6 m inside the corner, ending at 52 deg (still full grip). A loop needs a
  straight block before and after it (layout error otherwise). Points carry their mode: `LOOP`
  (the eased stretches, the loop's floor and ceiling), `WALL` (|cos tilt| < 0.32: no side grip
  there, hold straight), with the road's normal `n` and the line's curvature `k` about it.
- **The bot** (`TmBot`): on LOOP points it steers in the road's own frame (aiming at a 3D point on
  a cylinder reads the helix's twist as a turn): the line's curvature plus a pull back from its
  offset and heading (2 rad/s, damping 0.8), as a share of the yaw rate full lock gives at that
  speed (TMNF's steady yaw rate, tmnf_physics 3.4). The heading, not the velocity: up the steep
  side gravity bends the velocity, not the heading, and the grip at the top brings them together.
  In the air (5 ticks without a wheel on anything) it steers with the car's spin (TMNF damps it 3x),
  so it lands straighter. Straight-and-curve driving (STEER points) is unchanged.
- **A contact bug under high load** (`TmBody._contacts`), found at a loop's exit: a wheel 43 mm into
  the road at a block seam also grazes the straight block's end cap under the seam (a 1 mm pair at
  the edge). Shallow pairs take a face normal from a short ray, and if that pair came first in the
  query's results the ray found the cap: normal (0, 0, -1), against the travel, and the "ground"
  impulse took 20% of 83 m/s (-47 km/h in one tick). Now the deep pairs go first (a shallow pair
  joins the contact it belongs to), and a face edge-on to the contact (> 60 deg off) gives way to
  the faces either side of it. This could hit any seam: with only this fix the bot's times
  dropped on most tracks (Drift King 33.56 vs its 33.98 author time, Night Shift 34.41 vs 34.95,
  Last Call 38.58 vs 39.44). Shared core: sync
  `game/cars/tm` on `tmnf-physics` when that branch moves on. model lab 44, car body 22, shapes 11.
- Loop test runs (tracks made for it, then deleted): entries 279-404 km/h all go round with no curb
  contact, the car within 3-6 m of the line (279: 137 km/h at the top; 361: 270; 404: 311).
- **New track SF11 Full Circle**: a right loop after a turbo (in at 324 km/h), a checkpoint, a GT3,
  a left loop after a turbo (381 km/h), a GT3 and the finish. `--write_medals`: the bot finished at
  every grip (30-75), best 22.48 s at grip 60: author 22.48, gold 23.9, silver 27, bronze 34.
- The shipped tracks' medals are unchanged; all ten still finish within gold. Known weakness (not
  new): the bot weaves at 250+ km/h on STEER points (its 2.2 gain), so a flight off a slope crest
  (Kickoff, right after the GT3) takes off with a yaw rate and lands sideways; Kickoff finished by
  luck before and still does. Fix for later: the road-frame steering for STEER points too, then
  re-medal.

## 2026-10-17 — Session 12: quality pass (owner), branch `stadium`
Owner: "the tracks looks bad, not many ornaments and background. second, the checkpoints looks
very cheap, not like in TMNF, ale also it doesnt show which one is start and which one is finish.
The car looks weird, like where is the human? Car parts dont looks connected. When driviing, the
car looks blurry. 1. Run an indpeendent review of the game. 2. Fix my concerns and the review
comments". An independent reviewer agent (read-only, screenshots) was started; its findings are
handled below as they come.
- **Gates** (`blocks/tm_gate_dress.gd`, from `road.gd` `_gate`): TMNF's measured arch painted light,
  its inner face tinted in the gate's colour with thin lamp strips along its inner edges (green
  start, red finish, cyan checkpoint, amber lap), a lit START / FINISH / CHECKPOINT banner on the
  crown facing both ways (chequered bands on the finish), the side screens lit, a white start line
  and a chequered finish band on the road. Sheared with sloped and banked checkpoints
  (`TmGeo.sheared`). A full-bright inner face filled the screen with bloom as the camera passed
  under it: now a tint (emission 0.3) and the strips carry the light (2.2).
- **Car** (`car/tm_car_visual.gd`): the engine cover and airbox moved behind the driver (the helmet
  was buried in them), an open cockpit (dark well, rim, windscreen) with the driver (helmet with a
  stripe and visor, neck, shoulders, arms, gloves on the steering wheel), the airbox low and narrow
  enough that the chase camera sees the helmet, a front wing with end plates instead of the loose
  splitter, brackets from the front guards to the uprights, the rear guards reaching in over the
  engine cover, thicker wishbones.
- **Blur**: the chase camera is placed every rendered frame from the car's interpolated transform,
  but Godot's physics interpolation smoothed it again between ticks, so it trailed the car and
  shook against it; TAA turned that into smear. Measured with a throwaway probe (on-screen
  frame-to-frame shake of the car at 144 fps): 1.7-2.4 px before, 0.9-1.4 px after. The camera and
  the wheel pivots are no longer interpolated a second time; TAA off, 4x MSAA (`project.godot`,
  `TmRtx.apply_viewport`).
- **Track decoration** (`race/tm_track_decor.gd`, called by `TmTrackBuilder.build` after the
  pillars; seeded by the track id): rows of glass booths, advert structures and camera booms (TMNF's
  Control road blocks, the campaign's most-used decoration after inflatables) beside every straight
  of 3+ blocks, a cell away from the road; 18 inflatable palm trees, cacti and snow trees near the
  track; two sculptures further out; the airship over the field. Lessons: right next to the road
  (as TMNF places them) the bot, landing a jump slightly off the road, got stuck on a booth; and a
  sculpture beside raised road caught the car: nothing tall in a column the track uses at any
  height. All 11 tracks still finish within gold with the new contact physics (45/45).
- **Screens**: the shared "screen" material had no emission, so every display (advert structures,
  Fabric and platform boards, camera booths, in TMNF's tracks too) was a black slab; now lit LED
  boards like the stadium's big screens.
- **The independent review** (a read-only agent with its own screenshots; its report, summarised):
  tracks bare and tiny (5-15% of the field), placeholder-looking screens (a blue zig-zag),
  floodlights blank, the driver hidden by the airbox, paint flakes sparkling like frost without
  TAA, a "jelly" metallic body, the carbon weave like bricks, washed-out light, aliasing once TAA
  was off, the car flying off the finish block's nose into the grass, no sense of speed, respawn
  stopping the car dead, records keyed by the track id (a stale record from an older layout),
  the campaign listing every file in tracks/, a misaligned HUD, clipped menu texts. Done since:
  - Finish: our tracks finish on TMNF's through start/finish line block with up to three
    straights and a rounded dead end after it (the map builder keeps the start line as the start
    when both exist); after the line the car brakes by itself (`TmCar.auto_brake`) and the camera
    cuts to a trackside spot by the line and watches it (`TmCamera.freeze`); the result text sits
    high. Medal times re-set (below).
  - Screens: `env/tm_adverts.gd` (autoload Adverts) draws a strip of our own fictional ads once
    with the UI fonts; every screen material scrolls it (read the right way from the front, LED
    grid; 3x on the big screens). Floodlights: a lamp grid. Inflatables: striped and puffed.
  - Light graded (sun 1.1, ambient 0.75, exposure 0.85, saturation 1.25, contrast 1.12, shadows
    0.85); SMAA on top of 4x MSAA; the finish chequer mipmapped and filtered.
  - Car: flakes only where they cover a pixel and none on the white parts; painted, not chrome
    (metallic 0.12, clearcoat 0.5); a fainter, finer carbon weave; a dark race suit; sidepods in
    the body colour; brake lights clear of the tail.
  - Race feel: the field of view widens with speed (72 deg to 84 at 350 km/h); respawn puts the
    car back at the checkpoint as it crossed it, speed and heading kept, like TMNF
    (`tests/test_tracks` respawn_keeps_checkpoint_speed); `--bot` uses the track's grip.
  - Records keyed by the layout (`SF-<id>-<hash of start and pieces>`); the campaign is the list in
    `tracks/campaign.json` (menu and server; other track files still race by id); the HUD's medal
    times in an aligned grid in medal colours; menu texts that ran into their controls shortened;
    a ring on every car-colour swatch (the black one vanished).
  - Not done from the review (next): bigger tracks using more of the field with more elevation and
    more kinds of decoration (Fabric stands at the start and finish, inflatable rows outside
    curves, lights by the checkpoints), a seat pattern in the stands, a result panel, the leaks
    reported at exit, `map_view near:` ignoring rotation.

  - Medals re-set for the new finish and contact physics (`--write_medals`; author = the bot's
    best): Kickoff 23.85, Drift King 33.60, Highline 34.09, Switchback 43.34, Full Send 25.89,
    Skyway 24.01, Night Shift 35.26, Corkscrew 35.42, Rush Hour 30.15, Last Call 37.60,
    Full Circle 22.53.
- **Released `stadium-v0.2`** (owner: "Yes, tag stadium-v0.2 and push it"): tag on `6f35e4f`, CI built
  both zips (Windows 53 MB, Linux 44 MB) and made the GitHub Release https://github.com/khanhonthetrack/speedfest/releases/tag/stadium-v0.2.

## 2026-10-17 — Session 12: bigger tracks with more elevation (review), branch `stadium`
From the independent review ("tracks bare and tiny, 5-15% of the field"). All 11 tracks re-laid
across the 32 x 32 field, each keeping its character:

| Track | box of the field | road cells | line | levels | cps | author |
|---|---|---|---|---|---|---|
| SF01 Kickoff | 82% (was 35%) | 16% (5%) | 3.9 km (1.4) | 1-3 | 4 | 54.44 |
| SF02 Drift King | 76% (59%) | 16% (11%) | 3.3 km (2.3) | 1 | 3 | 48.08 |
| SF03 Highline | 74% (43%) | 15% (7%) | 3.8 km (1.9) | 1-6 | 4 | 53.46 |
| SF04 Switchback | 68% (20%) | 10% (6%) | 2.8 km (1.8) | 1-3 | 4 | 59.25 |
| SF05 Full Send | 77% (61%) | 12% (8%) | 3.1 km (2.2) | 1-3 | 3 | 41.04 |
| SF06 Skyway | 66% (22%) | 12% (6%) | 2.8 km (1.6) | 1-5 | 3 | 40.37 |
| SF07 Night Shift | 69% (76%) | 15% (8%) | 3.6 km (2.3) | 1-3 | 3 | 46.87 |
| SF08 Corkscrew | 79% (23%) | 15% (7%) | 3.6 km (1.8) | 1-6 | 3 | 46.63 |
| SF09 Rush Hour | 69% (29%) | 11% (5%) | 3.0 km (1.6) | 1-3 | 4 | 54.86 |
| SF10 Last Call | 69% (63%) | 15% (10%) | 4.1 km (2.6) | 1-6 | 4 | 53.82 |
| SF11 Full Circle | 79% (25%) | 13% (6%) | 3.3 km (1.6) | 1-11 (loops) | 3 | 38.35 |

- Elevation: long hills up to level 6 (Highline, Corkscrew, Last Call), Skyway's raised lap at
  level 5 with a jump between two raised roads (Rush Hour has one at level 3), Night Shift's road
  passing under its own bridge, Corkscrew's dive under its raised side, Last Call's long straight
  under its high road. Raised roads stand on pillars, and now raised GT curves too
  (`TmTrackBuilder.add_pillars`: every other cell whose middle the line passes within 8 m of).
- New pieces `["climb", n]` / `["dive", n]` (`TmTrackBuilder._hill`): TMNF's way up a hill, the
  slope start (`BiSlopeStart`, 2 blocks), n slope blocks (`SlopeStraight`; with `"cp"` or `"turbo"`
  the middle one is `CheckpointUp/Down` or `TurboUp/Down`) and the slope end (`BiSlopeEnd`, 2
  blocks): n + 2 levels over n + 4 blocks. `up`/`down` (SlopeBase, an S-step in one block) launch
  the car at speed; the long hills don't, up to ~315 km/h.
- The bot slows for crests as it does for curves: the slope end's line points carry the crest's
  radius (`rv`, 256 m) and `TmBot` keeps under sqrt(30 m/s^2 x rv) (~315 km/h) with room to brake.
  Found by tracing DNFs at some grips: at 350+ km/h the car flew off a crest (1.5 s in the air),
  landed sideways (27 m/s lateral) and left the road at the next curve (Full Circle, Last Call).
  Other lessons: a low ramp at 447 km/h after a turbo flies 230 m, past its landing straight (Full
  Send: the turbo moved after the jump); a jump just before a curve throws the car off (Night
  Shift: the jump moved two blocks earlier). Every track now finishes at all five grips (30-75).
- A checkpoint every ~12-15 s (3-4 per track), so a respawn doesn't send the car far back.
- `tests/tmp/track_dump` (untracked) recreated: prints each track's map (highest road level per
  column, S/F/C/T/J, / slopes; `--decor`), the share of the field's box and cells it uses, the
  line's length and levels. README "Make a track" lists the new pieces and the lessons.
- Medals re-set with `--write_medals` (author = the bot's best of grips 30-75; table above).

## 2026-10-17 — Session 12: more kinds of decoration (review), branch `stadium`
From the review ("more kinds of decoration"). `race/tm_track_decor.gd` adds three kinds, all built
from blocks already recreated, placed before the booth rows and the scattered inflatables:
- **Fabric grandstands framing the start and the finish** (`StadiumFabricStraight1x1`): a row on
  each side of the gate two cells out, facing the road, the roofs arching over the cell between
  (48 m up), from a cell behind the gate to two past it. The start and the finish now sit in a
  white wave tunnel (13-16 pieces a track). The shells' undersides were the dark steel colour;
  now a light membrane (`fabric_under` in `blocks/shapes/fabric.gd` and `TmMaterials`; TMNF's
  tracks get it too).
- **An inflatable wall with a billboard beyond each curve** (GT 3+ on the ground, straight on from
  where the line comes in, a free row between): TMNF's cushion wall (`StadiumInflatablePillar`),
  two cells deep and as wide as the curve, laid round its rectangle the editor's way (read off
  B09 and A04: the T piece's variant index is 4 / 1 / 2 / 3 on the -z / +x / +z / -x side, the
  corners 5-8 at (+x,-z), (+x,+z), (-x,+z), (-x,-z); the direction is index % 4 for a T piece,
  index - 5 for a corner; 0 is the inside), with the inflatable billboard
  (`StadiumInflatableAdvert`, four levels, ads on its screen) on the side facing the curve where
  no raised road passes within two cells.
- **Camera booths and light rigs by the checkpoints** (on the ground): a `CameraPub` (two screens)
  a cell out on each side of the gate, a light rig (`ControlLight`; its raised piece set on the
  grass, the only one recreated) either side of it along the road.
- The rules learned so far hold (`_clear`, `_try`): a free cell between any decoration and the road,
  nothing on a column the track uses at any height, billboards away from raised road. The bot's
  times are unchanged on all 11 tracks.

## 2026-10-17 — Session 12: seats in the stands (review), branch `stadium`
From the review ("a seat pattern in the stands"). The long sides' seating rake (27.6 m rising to
45.9 m, `env/tm_stadium_build.gd` LENS_SECTION) was hidden from everywhere on the field: the LED
face measured in front of it ran from 25.1 m to the rake's top (46.1). It is now a ribbon two ads
high (23-31 m, on the ads' 4 m grid), and the rake shows above it. The rake's surface (`stands`,
`blocks/tm_surface.gdshader` pattern 7) is drawn as seating: rows of seats by height (0.45 m, the
backs darker, a seat every 0.5 m), sectors 20 m wide in two blues with concrete stairs between
them, a walkway every 12 rows; each detail fades to its average where a pixel covers half of it
(the old rows faded out from 50 m), and flat tops using the material (booth roofs, the Fabric
stands' decks) stay plain.

## 2026-10-17 — Session 12: a result panel at the finish (review), branch `stadium`
From the review ("a result panel instead of the stacked HUD text"). At the finish the HUD flashes
the time in its medal's colour with the difference to the record for 1.5 s
(`TmRaceHud.FINISH_FLASH`), then `TmRaceMenu.show_finish(result)` opens one result panel in the
middle of the screen, on darker glass: the track's name, the time, the medal it earns (a disc in
the medal's colour, or "NO MEDAL"), NEW RECORD and the difference to the record before this run,
the four medal times (beaten ones bright; the others dim with the time still to find), and RETRY /
NEXT TRACK / MENU in a row. `race/race.gd` passes {name, time_ms, prev_ms, record, medals}; the
panel comes back with its result after the pause menu. `tests/test_menu`: race_menu_result,
race_menu_result_after_pause. Note for screenshots: `race.tscn --bot` records its finishes like a
player's; pass `--records=<scratch dir>` so the player's records stay theirs.

## 2026-10-17 — Session 12: the bot's weave fixed, v0.3 (owner: "continue and incorporate in v0.3")
- The follow-up session's work checked by eye first (bigger tracks across the field, Fabric stands,
  billboard walls, camera booths, seats, the result panel): fine.
- **The bot's steering on ordinary road** (`race/tm_bot.gd`): over 100 km/h it now steers in the
  road's frame like on loops (`_frame_steer`: the line's curvature taken 0.25 s ahead, plus a pull
  back from the car's offset and heading, wn 1.6 rad/s, damping 0.95, as a share of the yaw rate
  full lock gives at that speed); below, the old aim-at-a-point steering. Road arcs now carry their
  signed curvature `k` (`TmTrackBuilder._segment`). A sweep over grips 30-75 on all 11 tracks
  (`tests/test_tracks --sweep`, new: every grip, no medals written): the old steering finished all
  55 runs but got slower at grip 75 (the weave); the new one is faster at every grip (best times
  5-15% lower on 10 tracks) and fails 4 runs at grips 60-75 (a crest flight landing just before a
  raised curve, too fast to turn in), which `--write_medals` skips. Medals re-set: Kickoff 48.47,
  Drift King 41.81, Highline 50.95, Switchback 55.09, Full Send 36.76, Skyway 35.26, Night Shift
  42.85, Corkscrew 45.61, Rush Hour 56.91, Last Call 47.31, Full Circle 34.94.


## 2026-10-17 — Session 13 (M9): reference renders, a new car (branch `claude/tmnf-replica-graphics-nb1kcg`)
Owner (TRANSCRIPT, session 13): "a 1:1 TMNF replica"; the car "sucks (the rims dont touch the wheel)".
- **Reference renders (local only):** `tools/research/tmnf/ref_visuals.py WORK OUT` writes every
  decrypted solid's visual meshes with texture coordinates (`visual_mesh.py --uv`), each
  material's textures and the install's .dds images as PNG, outside the repo. With `--ref=OUT` the
  remake draws blocks with them (our collision stays; `blocks/tm_ref_visuals.gd`), and
  `race/map_view.tscn --car=ours|ref|both --car_ahead=40 --view=car:yaw:dist[:x,y,z]` shows TMNF's
  car and ours from the same camera. TMNF's textures are plain .dds in `GameData/Stadium`
  (D/N/S/O/L maps: diffuse, normal, specular, occlusion, light); its v runs up. Seen on the first
  renders: TMNF's own text reads mirrored under our x negation (START reads TRATS): the remake's
  world may be TMNF's mirror image (to check before relying on it; it matters for .Gbx tracks).
- **New car** (`car/tm_car_visual.gd`, helper `car/tm_mesher.gd`): modelled to TMNF's measured
  proportions with our own shapes, compared side by side with the original at every step:
  - wheels that hold together: a lathed tyre whose bead sits under the rim's flange (the lip
    overlaps the sidewall), five broad spokes into the barrel, a large hub with studs and a
    centre-lock nut, a ventilated disc and a caliper on the upright (steers, doesn't spin);
    subtle moulded lettering on the sidewall;
  - a slim tub and low nose lofted through rounded-trapezoid sections whose top opens into a U
    for the cockpit (rim, walls and floor are one surface); low angular sidepods with raked dark
    inlets; a roll hoop that is the engine's intake; a flat engine deck with a glass strip and a
    fin; front wing with a flap, rear wing (two elements, pylon, end plates); floor;
  - wishbones, push and track rods, drive shafts re-aimed every frame to the moving wheels;
    small guards over the front wheels (they steer with them) and over the rear ones;
  - the driver (helmet with visor and stripe, collar, shoulders, arms on the wheel), windscreen,
    mirrors, rain light (brake light). Geometry is built once and shared by all cars (ghosts,
    online players); materials stay per car. Same public API (race, ghosts, menu unchanged).

## 2026-10-18 — Session 13 (M9-2): the look, first pass (textures, gates, adverts, stadium)
Compared with TMNF's own look at every step (reference renders, local only: `--ref=<dir>`, now
also TMNF's surround `Zone/Square32`). Our own art throughout, generated by Python scripts in
`stadium/tools/texgen/` (numpy + Pillow + our OFL fonts) into `stadium/assets/tex/`
(`<name>_albedo/_normal/_orm.jpg`, Godot ORM layout; `TmMaterials.TEXTURED` maps material keys to
them, mesh UVs or world triplanar):
- **UVs on sweeps** (`TmGeo.sweep`): u = metres along the path per section point (a whole number
  of 8 m tiles per sweep, no seams between blocks), v = metres along the section from its bottom
  centre, restarting per material run; the right half's u runs backwards so text reads from the
  road on both sides; `add_mirror_x` mirrors u. Checked numerically (`tests/tmp` probe) and on
  renders (air and ground blocks, curves).
- **Road** (`texgen/road.py`): weathered light concrete (world-mapped, 8 m slab joints), the
  curb's face (dark moulded rubber with our SF emblem, SPEEDFEST, STADIUM, a blue stripe, scuffs),
  the shoulder (perforated steel plates in bolted frames with a blue line, as TMNF's grid), the
  curb's light top. Road sections split into visual keys (curb_outer, curb_top, curb_face,
  shoulder, road_lip); the surface ids are unchanged.
- **Gates** (`texgen/gates.py`, `road.gd _gate`): TMNF's arch with its faces a rubber band with
  START / CHECKPOINT / FINISH repeated along the arch (UV strips between the arch's outer and inner
  lines), a dark underside with lit strips in the gate's colour, light rigs on the shoulders, the
  gate block's curbs carrying the word; start and finish pads (colour, chequered band, word) and
  the checkpoint line painted on the road (`TmGateDress`); the floating LED banner is gone. A
  start/finish line ends our races, so it shows FINISH.
- **Adverts** (`texgen/adverts.py`, `env/tm_adverts.gd` now loads `assets/tex/adverts.png`): our
  own fictional sponsors in a restrained monochrome style (SPEEDFEST, GRIPLINE, VOLTAGE, APEX,
  NORTHWIND, TIME ATTACK, the emblem) instead of the saturated multicolour boards.
- **Fabric roofs** (`texgen/fabric.py`): membrane panels on top, steel ribs and X bracing below.
- **Stadium** (`texgen/stadium.py`): the grandstands' field-side walls are a facade (precast
  panels, a glazed band of boxes per floor, railings), decks precast concrete, roofs membrane;
  inflatable cushion walls red vinyl; the tube network's pillars and pipes painted steel.
- Control galleries' supports dark metal. Texture budget so far ~10 MB (JPEG).
- Next in the look: tube/control/platform/dirt/circuit families for the A-E campaign, the
  airship and palms, then the engine (M9-3).

## 2026-10-18 — Session 13 (M9-3): the engine like TMNF's
TMNF's SoundEngine (read from its tuning and sound files, numbers only) plays six layers, four
under load and two coasting, each with an rpm window and a pitch curve, over a six-gear model.
Ours now works the same way, with our own sounds:
- **Gears and rpm** (`audio/tm_sounds.gd`): TMNF's gear tops 85/110/160/220/370/400 km/h, its
  up-shift points (0.95/0.9/0.95/0.95/1.0 of a gear's top) and down-shift points, 11000 rpm max,
  1200 idle; `gear_for(kmh)`, `rpm(kmh, gear)`. `TmCarAudio` keeps the gear with hysteresis, lets
  the rpm rise at a set rate, dips the load layers ~70 ms at an up-shift with a clunk, flutters at
  the limiter and revs freely in the air on throttle.
- **Layers** (`tools/sfxgen/engine.py`, numpy + scipy, writes `audio/sfx/engine_*.wav`): a
  four-cylinder racing engine synthesized from its firing pulses (2 a revolution, so 11000 rpm is
  TMNF's top fundamental), exhaust ring and thump through a short pipe, intake roar under load,
  valvetrain whine and crackles off load; idle 1200, low 3600, mid 6600, high 9600 under load,
  coast 3600 and 9000; seamless loops pitched by rpm / base rpm and crossfaded by rpm and
  throttle (`TmCarAudio.LAYERS`). Band energies checked against TMNF's own engine samples.
  `tools/sfxgen/preview.py OUT.wav` renders a standing start offline for listening.
- `shift.wav` (a dull knock and a tick) and `turbo.wav` (a rising rush with a turbine whine) are
  synthesized too; the old engine_load/coast/turbo recordings are gone. `tests/test_sound`: rpm
  drops at each shift, gears follow speed, the engine follows speed.

## 2026-10-18 — Session 13 (M9-4): menus like TMNF's
TMNF's menus (surveyed from its menu pack: names, layout, the look of its skin; nothing copied)
are dark green glass over a blurred Stadium, white capitals, lime green for what's selected,
glossy sphere checkboxes and medal discs. Ours now has that structure and look, our own art:
- **Structure** (`ui/tm_menu.gd`): a bar across the top with our logo, where you are (SOLO /
  CAMPAIGN) and your nickname and zone; main = SOLO, ONLINE, PROFILE, OPTIONS, QUIT (EDITORS comes
  with the track and replay editors, M9-5/6); Solo = CAMPAIGN, OPEN A TRACK FILE; the campaign has
  a tab per series (`TmTracks.series()`: `tracks/campaign.json` is a list or
  `{"series": [{"name": "White", "tracks": [...]}, ...]}`, TMNF's series colours by name), a card
  per track (its map from above, number, name, medal, best time) and the selected track's panel
  (map, the four medal times with medal discs, your best, a lime RACE); Online = a server list
  (the official server's name, track, players, time left), JOIN, REFRESH, join by address;
  Profile = nickname with TMNF's $-codes previewed as you type, zone (`data/zones.json`, stored
  as "Continent|Country"), car colour (the camera moves in on the car), your medal counts;
  Options as before. Esc goes back one page. The TMNF-install campaign tabs and the "TMNF tracks"
  page are gone (owner: the campaign is our own); single `.Challenge.Gbx` files still open.
- **Look**: `ui/tm_glass_box.gd` (TmGlassBox, a StyleBox drawn as vectors: gradient fill, a gloss
  band from the top, an antialiased border brighter on top, a glow for focus, a stripe; crisp at
  any resolution) for panels, buttons, tabs, fields; `TmUi.glass(kind)` presets and `TmUi.go()`
  (the lime race/join button); `tools/texgen/ui.py` draws the icons into `assets/ui/` (medal discs
  author/gold/silver/bronze/none with our raised SF emblem, sphere checkboxes, star, play, the
  SPEEDFEST STADIUM chrome logo, the countdown's 3 2 1 GO!). The backdrop: camera depth of field
  keeps the car sharp and the Stadium soft, a shader grades the edges dark green.
- **Nicknames** (`ui/tm_nick.gd`, TmNick): $RGB, $o $i $w $n $m $s $t $g $z $< $> $l $h $$ parsed
  into runs; `to_bbcode()` for RichTextLabels (`TmUi.nick_label`), `strip()` for plain text (the
  online name tags, ranking and chat strip the codes for now). The server keeps 75 characters
  (TMNF's limit) instead of 16.
- **In race**: the countdown shows TMNF-style figures popping in (`TmRaceHud._figure`), the
  result card uses the glass and the medal discs. The track cards' map is `ui/tm_track_map.gd`
  (our tracks' line, or a .Gbx's road blocks; start green, checkpoints blue, finish red).
- `tests/test_menu` rewritten (27 checks: the pages and their order, back, campaign tabs and
  cards, records and medal counts, profile nickname and zone, online, options, $-codes, the race
  menu). Screenshots: `tools/run.sh res://ui/menu.tscn -- --page=<page> --frames=90 --shot=...`.

## 2026-10-18 — Session 13 (M9-5): replays
TMNF records every run: after the finish you can watch it or save it, your best run on each track
is kept, and a replay list and viewer with several cameras show them. Ours now does the same:
- **Recording** (`race/tm_replay.gd`, TmReplay): every run in the race scene, a sample every
  20 ms of race time: pose, velocity, steering, gas, brake, the four suspension lengths, the wheels
  touching, grounded/sliding, and events (wall hits, turbos, respawn cuts) gathered between
  samples; plus the track (our id or a `.Gbx` path, its uid and name), the player's nickname and
  colour, the date, the finish and the checkpoint times. Files in `user://replays` (zstd, ~130 KB
  for a 48 s run); `autosave/<track key>.replay` is your best run on each track (written with a
  new record); `to_ghost()` turns one into a TmGhost.
- **Finish menu**: REPLAY watches the run (kept as `_last.replay`, Esc comes back to a new
  attempt), SAVE REPLAY keeps it ("<track> <time> <date>.replay"; the button turns to SAVED).
- **Viewer** (`race/replay.tscn`, TmReplayView): the track built as for a race; the run played on
  a puppet TmCar (never simulated: its state is set from the replay each tick, so TmCamera,
  TmCarAudio, TmCarVisual and the HUD work unchanged, wall hits and turbos replayed as events),
  the 3 2 1 GO! before it, the HUD's checkpoint times and finish; cameras CHASE, CLOSE, COCKPIT
  (at the driver's eyes), TRACKSIDE (TV spots every 120 m beside the run, zoomed to keep the car's
  size), FREE (WASD, Q/E, right mouse); a glass bar: play/pause, speed x1/8..x4, the time line
  (drag to seek), camera; keys Space, Left/Right 5 s, Up/Down, C or 1-5, Home, H, Esc.
  `--replay=<file> --replay_at=<ms> --cam=<name>` for screenshots.
- **Menu**: Solo > REPLAYS lists them (track, time, nickname with its codes, date, BEST for the
  autosaves), newest first; WATCH, DELETE (press twice).
- `tests/test_replay` (in the gate, 19 checks): the bot races SF01, the replay matches the run's
  ghost to 1 cm, has the inputs, is autosaved and saved, loads back identical, lists; the viewer
  follows it, seeks past the checkpoints, reaches the finish, plays at x4, pauses, has five
  cameras; the menu lists and hands over a replay.

## 2026-10-18 — Session 13 (M9-6): the track editor
TMNF's Stadium editor, our own: the blocks of the recreated library on TMNF's 32 x 8 x 32 m grid.
- **Editor** (`editor/editor.tscn`, TmEditor; rules in `editor/tm_editor_model.gd`, testable
  headless): the Stadium around a 32 x 32 field, a grid at the cursor's level (fading away from
  it), the cursor's cell, a ghost of the chosen block on it (green: fits; red: why not, e.g. "the
  space is taken", "outside the stadium", "a track has one start"); a palette by family (ROADS,
  PLATFORM, DIRT, CIRCUIT, TUBES, DECORATION, WAYPOINTS: every catalogue block whose shape is
  recreated, no terrain zones or auto clips, TMNF's most used first) with icons rendered from our
  geometry (`tools/icons/block_icons.tscn` + `shrink.py`, 258 icons in `assets/ui/blocks/`,
  1.2 MB); place, turn (R/Q), level (Page Up/Down, Shift + wheel), erase (X, Del; picks the block
  under the mouse by a ray), pick (I), undo / redo (200 steps), save, TEST (F5), orbit / pan /
  zoom camera. Only what changed is rebuilt (block keys: shape, place, variant).
- **Roads join by themselves** (`TmUserTracks.road_variant`): a road block (TMNF's "road" kind:
  main road, platform road, tube and control rows) opens each side where the next cell shows its
  clip facing back, and takes the dead end, straight, corner, T or cross shape turned to fit
  (`road.gd`'s open sides per shape). Raised one-cell road gets pillars (a tube under the road and
  tube pillars down to the ground, every other block, where free).
- **Files** (`race/tm_user_tracks.gd`): `user://tracks/<name>.sftrack`, our own JSON (id, name,
  author, laps, medals, the layout they belong to, blocks as [id, dir, x, y, z]); a track loads
  as a TmChallenge anywhere (`TmStage.load_from_args` takes `--map=<file>.sftrack`; Open a track
  file too); uid "U-<id>-<layout>" so records belong to a layout.
- **Validation**: TEST saves and drives the track (`race.tscn --map=<file> --back=editor`);
  finishing it sets the medals from the time (TMNF's rule: gold +6%, silver +20%, bronze +50%),
  the result card says TRACK VALIDATED, the menu button reads EDITOR and goes back. Any change to
  the blocks or laps clears the validation.
- **Menu**: EDITORS on the main page: your tracks (name, author time or "not validated", blocks,
  date), NEW TRACK, EDIT, PLAY, DELETE.
- `tests/test_editor` (in the gate, 31 checks): road joining (every shape, clips of non-road
  blocks), the rules, undo/redo, the file and its names, the challenge (ground variants,
  pillars, laps, uid), validation and its loss on edit; a straight test track driven at full gas
  from the editor validates its file; the editor scene opens it, places a road beside it (the
  straight becomes a T), undoes, refuses a taken cell, saves; the Editors page lists, edits,
  plays.

## 2026-10-18 — Session 14: independent review against Trackmania (branch `claude/trackmania-stadium-review-lds3no`)
Owner (TRANSCRIPT, session 14): reverse engineer Trackmania (2020) with REA "to have a fully
functioning version"; how to improve the remake's textures (gates "with 2 horns", the car, the
dated look); an independent review of how close `stadium` is to the real game.
- **Not done: a working Trackmania (2020) from its decompiled code** (account-only online game; a
  copy of Nadeo's program; REA's own disclaimer excludes it; the project's "recreate only" rule).
  TMNF's physics was already reverse engineered with REA (session 9). No Nadeo file was downloaded
  or used for this review.
- **Review: `docs/research/stadium_review.md`.** Scorecard per area against TMNF (and TM2020):
  physics 9/10, blocks 9/10, but gates 3, car 3, surfaces 3, light 3 on `stadium`; with session
  13's M9 branch the car reaches about 6 and the gates 5, light is unchanged. Findings:
  - the "horns" are TMNF's measured sign boards (`road.gd` `GATE_SIGN`) built as solid 0.3-0.45 m
    prisms with adverts on every face, floating ~1.5 m above the arch (the arch's outer line is at
    y ~6.6 under their bottom at 8.17), plus (on `stadium`) a banner on posts between them. M9
    removed the banner but still builds the boards the same way;
  - light: no GI/AO at the default quality (SDFGI/SSR/SSIL are Ultra only), ambient 0.75 against
    sun 1.1, linear tonemap with saturation 1.25, sky-only reflections (no ReflectionProbe
    anywhere), hard 90-degree edges, no decals; the same on M9 (its "light and atmosphere" is
    still open);
  - fidelity checks to add: drive TMNF replays' inputs through `TmCar` and measure the drift; check
    the world's handedness (session 13 saw TMNF's text mirrored under our x negation).
- **Ranked fix list** in the review (§3-4), ordered by what the prototype renders showed: the
  gates first (dropping the boards for a crown screen beat rebuilding them as framed screens),
  then local depth (a contact shadow under the car, a per-map sky-occlusion volume as TM's
  "Compute Shadows" our way, bevels in `TmGeo`, decals), car AO/paint/livery, the remaining
  surface families. Tested and *not* a win on their own: AgX (greys the sky, as session 12 found),
  a stronger sun against a weaker ambient (dims the frame), a reflection probe (subtle), SDFGI as
  tuned now (tints blue, darkens).
- Renders (local, Forward+ on llvmpipe, `tests/tmp/review_view` = M9's map_view `car:`/`gate:`
  views copied into a scratch checkout): `stadium` and M9 gates, car, overview; a scratch
  prototype of the top fixes (light, probe, framed-screen and no-board gates). The prototype is
  not committed to any game branch; its diff is `docs/research/stadium_review_prototype.diff`
  (against M9 @ 77bb43c) for whoever implements §3.

## 2026-10-18 — Session 14: the review's fix list (owner: "go with option B and implement the fix list")
Branch `claude/trackmania-stadium-review-lds3no` with M9 merged in. One commit per step.
- **Gates, option B** (`blocks/tm_gate_screen.gd`, `blocks/tm_led_screen.gdshader`, `road.gd`
  `_gate`, `TmGateDress.crown`, `race/race.gd` `_gate_time`): TMNF's two sign boards are gone; each
  gate has an LED screen in its arch's crown on both faces (the gate's word, START / CHECKPOINT /
  FINISH in its colour; when you pass, your time and the difference to the record's split, blue
  ahead / red behind, as TM2020 does; the word again on restart) and a spotlight in its colour on
  the road under it. Dirt checkpoints get the screen too. One SubViewport per gate, redrawn only
  when its text changes. Lesson: blocks are built once per shape and `duplicate()`d
  (`TmBlockLib`), which drops script variables, so the screen keeps only exported settings and
  builds itself in `_ready` (the first try showed the template's never-drawn, white viewport).
  `tests/test_tracks`: gate_screens_SF01 (one per road gate), gate_screen_shows_time,
  gate_screen_word_after_restart.
- **Contact shadow under the car** (`car/tm_car_visual.gd` `contact_shadow`): a Decal projected
  straight down from just below the floor (3.0 x 5.6 m, a soft rounded footprint reaching ~0.45 m
  past the wheels, 80% dark at the core), faded on surfaces that don't face up, so it never shades
  the car; it fades out with distance and is gone in the air. Not on ghosts. Lesson: the first
  size (the car's own footprint) hid under the body; a contact shade has to spread past the car
  to read. Also `race/map_view.gd`: the cars of `--car=` now stand on the road (a ray down from
  the start transform, which is the spawn point 0.87 m up; the review's "the car floats" in the
  M9 renders was partly this).
- **The map's sky occlusion** (TM's "Compute Shadows" done our way; `env/tm_occlusion.gd`,
  `env/tm_occlusion.gdshaderinc`, `[shader_globals]` in project.godot): when a map loads
  (`TmStage.add_environment`: race, map view, replays) one ray per 2 m straight down over the field
  records the highest collision surface (513 x 513 rays, ~0.65 s on llvmpipe's CPU, 2.3 us a ray);
  the heights are a float texture every surface shader samples (14 taps at 0 / 3 / 8 m around the
  point pushed 0.75 m off its surface) to darken ambient light and reflections where something is
  well above: under bridges, roofs, loops and arches (AO, ambient only). Applied in
  `tm_surface.gdshader`, the car's shader, and a new `blocks/tm_textured.gdshader` that replaces
  the ORMMaterial3D textured materials (same maps, mesh-UV or world-triplanar mapping with
  ORMMaterial3D's axis flips, its additive emission and defaults; it also applies the ORM maps'
  own AO, which ORMMaterial3D left off). `--occlusion=0` turns it off for comparisons.
  `tests/test_tracks`: occlusion_sees_the_gate_arch (5-12 m of arch over the first crossing).
- **Smooth shading, bevels, upright lettering** (`blocks/tm_geo.gd`): sweeps had flat normals per
  segment (the `smooth` flag was never implemented), so every measured round section (curbs,
  arches, tubes, pillars) shaded as facets; now each vertex averages the quads round it where the
  section bends less than 35 degrees (and along the path), real corners stay sharp, never across a
  fold (visual normals only). `box(..., bevel)`: a chamfered visual mesh (inset faces, 45-degree
  edge strips, corner triangles) over the plain box's collision, opted in for free-standing parts
  only (gate feet and light rigs, platform pillars, control booths and screens, tube and Fabric
  screens, inflatable posts), never boxes that tile into a driving surface (seams would show).
  The M9 bug from the review is fixed: the curbs' outer faces, read from outside the road, showed
  their lettering turned 180 degrees (u ran for the road side, and the run's v starts at the
  face's foot); faces that look away from the centre line now get u and v turned round.
- **Road decals** (`blocks/tm_road_decals.gd`, textures by `stadium/tools/texgen/decals.py`, our
  own): laid out from the map's built road blocks (`TmMapBuilder.road_blocks`), seeded by each
  block's place: 2-4 tyre-mark decals along the racing line through every GT curve and corner
  (outside at the entry, the apex 6 m inside, outside at the exit; tangent to it), a rubber scuff
  on the inner curb at the apex of half the curves, the burnout behind the start (two tracks at
  TMNF's 1.77 m), an oil stain on 12% of the straights. Decal nodes projecting down, faded on
  surfaces that don't face up and beyond 90 m; HD graphics only. Lesson: thin tyre tracks at a
  quarter opacity vanish at grazing angles; they are drawn near-opaque (70-100%).
- **Car shading and livery** (`car/tm_car_surface.gdshader`, `car/tm_car_visual.gd` `_livery`,
  stickers by `stadium/tools/texgen/livery.py`): the body's paint and carbon get ambient occlusion
  from their height over the road and from facing down (the road blocks their sky), on top of the
  map's occlusion; the clearcoat is glossier (0.85, roughness 0.06). Livery as decals that move
  with the car: the race number on a white board on the nose (read from in front), our emblem and
  SPEEDFEST on both sidepods (each read from its own side). The sponsors' stickers come with the
  Polish brands (adverts step).
- **Reflection probe** (`race/tm_stage.gd` `field_probe`): one probe over the whole field (map
  size + 80 m round, 400 m tall), captured once from 20 m over the ground when the map is in the
  scene; the car's rims, paint and the gates' metal reflect the Stadium instead of only the sky.
  **SDFGI stays off on High**: tried at Ultra with energy 0.9 and 1.5 against High (now with the
  occlusion, contact shadow and probe), it greys and darkens the scene at both (the facades go
  near black) and adds cost; High without it looks best in this review's renders. SDFGI on
  Ultra is unchanged; tuning it needs a real GPU (it never settled on llvmpipe in 60 frames).
- **The remaining surfaces textured** (`stadium/tools/texgen/surfaces.py`, our own): the field's
  mown grass (8 m stripes, blades, clumps, worn and lush patches), the dirt roads' packed earth
  (pebbles, cracks, damp hollows, wheel streaks), the platforms' 4 m concrete panels (chamfered
  joints, bolt plates), the structures' painted steel (2 m plates, seams, bolt rows, wear, rain
  streaks), light wall panels (also `wall_dark`, tinted). That covers the platform, dirt,
  circuit, tube and control families' main keys. `tm_textured.gdshader` gained a `tint` and a
  two-scale **macro variation** (the shared coarse noise at 173 m and 41 m over world xz), on the
  big surfaces (asphalt 10%, grass 16%, dirt 14%, platform 8%) so the tiles don't read as a grid
  from afar.
- **The physics check harness** (`race/tm_input_script.gd`, `race.gd --inputs / --record_inputs`):
  a run's inputs as TMInterface-style text (press/rel, steer -65536..65536 + = right, analog gas
  and brake lines); `--inputs=<file>` drives the car from it and prints `INPUTS_RUN splits finish`.
  With a TMNF run's inputs on a TMNF track (`--tmnf=... --track=A01`) the times can be compared
  with the game's; a car turning the wrong way at the first corner would show the world is TMNF's
  mirror image (the review's open handedness question; README "Check the physics against
  TrackMania"). Not run against TMNF here: it needs the player's install and runs (this session
  downloaded nothing of Nadeo's). Proved on our own track: `tests/test_tracks`
  input_script_replays_the_run_SF01 (the bot's run written as a script and driven without the bot:
  identical splits 12.57 / 15.91 / 28.80 / 41.17 / 48.47 s) and steer_left_turns_left.
- **Real national flags on the Stadium's 24 flagpoles** (owner: "put the flags of actual
  countries"; `stadium/tools/texgen/flags.py`, `env/tm_flag.gdshader`, `env/tm_stadium_build.gd`
  `_flags`): 24 flags drawn from their geometric definitions into one atlas (Poland, Germany,
  France, Italy, the United Kingdom, the USA, Japan, Sweden, Finland, Norway, Denmark, the
  Netherlands, Belgium, Austria, Czechia, Ukraine, Hungary, Spain (civil flag), Ireland,
  Switzerland, Greece, Estonia, Lithuania, Latvia). Poland flies on the pole nearest the field's
  middle in each corner, twenty others on the rest. Each flag is its own 26 x 17 m subdivided
  plane waving in the wind (vertex wave growing to the free end, a slight sag, the sun showing
  through; mirrored from behind like a real flag), one shared material with the atlas cell and
  wave phase per flag (instance uniforms). The plain-colour flag materials are gone.
- **Adverts: famous Polish brands under parody names** (owner: "instead of stupid looking logos,
  put the logos of famous polish brands ... e.g. ZABKA with RZABKA"; `stadium/tools/texgen/brands.py`,
  `adverts.py`): sixteen panels of our own design (our lettering in six OFL fonts with Polish
  letters, `stadium/tools/texgen/fonts/` with their licences, generator inputs only; simple marks
  and each brand's colour feel; no real logo, mascot or slogan copied): RZABKA (Żabka), ORLAN
  (Orlen), allegrro (Allegro), INPOSZT (InPost), LOTT (LOT), BIEDRONEX (Biedronka), TYMBARG
  (Tymbark), E. Wedler (E. Wedel), PRINCE POLLO (Prince Polo), CD PROJEKTOR (CD Projekt), 5F (4F),
  ŁACIATKA (Łaciate), GRZEŚKO (Grześki), PKU BANK (PKO BP), SOLARYS (Solaris), ŚNIEŻNA (Śnieżka),
  with Polish taglines. The strip is 16 panels now (`env/tm_adverts.gd` COUNT, `tm_surface`
  AD_PANELS: a 128 m cycle on the boards). The car's title sponsor on the sidepods is ORLAN
  (`livery_sponsor`), our emblem moved to the engine cover's flanks.
- **`stadium-v0.4`** (owner: "merge it into stadium and tag stadium-v0.4"): `stadium` fast-forwarded
  to the review branch (session 13's M9 work + session 14's); CI built it (success). The tag could
  not be pushed from the cloud session (HTTP 403 on refs/tags; branch pushes work): the owner pushes
  it (HANDOFF has the command), then CI makes the GitHub Release with the Windows and Linux zips.
- **Adverts on rotation, as in a football stadium** (owner: "Change the ads not to be next to each
  other and one duplicate below another, but like in football stadiums, be a few of them, and
  changin on rotation. Similar with billboard. Just one but changing from time to time."). The
  screens showed the 16-ad strip tiled in world space (ads side by side all along, the strip
  repeated every 4 m up a tall screen: two rows on the stands' LED ring, a 4 x 3 grid on the big
  screens). Now every screen's UVs lay out its own ads (`TmGeo.SCREENS`, `screen_uv`,
  `screen_rect`, `screen_box`; sweeps, revolves, extrusions and the lofted video cube
  (`SculptShapes._screen_uvs`) give each screen face its own): one row of 2:1 slots fitted to the
  screen's height, never stacked; billboards (`screen_on`: the stadium's two big screens and the
  inflatable advert walls) one ad over the whole screen. `tm_surface.gdshader` `advert()` turns
  the UVs to read upright from the front (screen-space derivatives, so mirrored and turned pieces
  read right), and picks the ads: a board shows a set of 3 in turn along it, every board the same
  set, all changing to the next set together every 8 s (16 ads, so every ad comes round);
  a billboard shows one ad and changes every 12 s, each at its own moment and on its own ad (seeded
  by its block's position). The new ads roll up into view over 0.5 s, slot after slot. A
  board's ends, chamfers, caps and rims show an unlit panel; screen boxes' frames are steel.
  Narrow tall screens (the Platform pub wall, the sound system's speakers) show their ad centred.
  `tests/test_blocks`: the layout (slots, letterbox, unlit strips, a screen box's two rows) and
  every one of the 85 shapes with screens shows ads.
- **One ad per board, fitted, rotating** (owner: "i dont like banners with multiple (3-5) banners as
  in your example. Just show 1 (by nicely adjusting sizes) and let them rotate"). Every screen now
  shows a single ad: at full height and centred on a board longer than it, with the ad's own
  background carried out to the board's ends (`assets/tex/adverts_fill.png`, made by
  `tools/texgen/adverts.py`: each ad's background per row, its full-width bands kept, so TYMBARG's
  strip and GRZEŚKO's stripes run on); stretched up to 25% to fill a screen of about its shape;
  at full width with its background above and below on a tall screen. Its edges fade into the
  fill. Boards all show the same ad and change to the next together every 8 s (the change spreads
  over the LED cells in 0.6 s); billboards change every 12 s, each at its own moment and on its own
  ad. The stands' LED ribbon (over a kilometre a side) is split into boards of about 44 m
  (`TmStadiumBuild.LED_BOARD`), each with the ad centred. UVs: `TmGeo.screen_uv` (u =
  `SCREEN_SLOT` x screen + the ad's x, v = the ad's y); the AD_SET sets and the roll are gone.
- **Merged into `stadium`** (owner: "Merge"): fast-forward to the review branch with the advert
  changes (STADIUM_TESTS PASS at 5f5df96). `stadium-v0.4` is still to tag (HANDOFF).

## 2026-10-18 — Session 13 (M9-7): online like TMNF's
TMNF's online, our own code (`docs/research/m9_online.md` is the design): one Node.js process on
one port is both the master server and the official game servers.
- **Master** (`stadium/server/lib/master.js`, HTTP `/api`): accounts (`lib/accounts.js`: login and
  password with scrypt and a salt, a 60-day token whose SHA-256 alone is stored, nicknames with
  $-codes up to 75 characters, zones from `stadium/data/zones.json`, logins rate-limited), ladder
  points (`lib/ladder.js`: Elo over every pair of a ranked round's finishers, K = 32 / (n - 1),
  start 1000; world, zone and continent ranks), online records per track uid (`lib/records.js`),
  the server list (official servers in the process; community servers by heartbeat with their
  host's token). Data: one JSON file written atomically (`lib/store.js`).
- **Game servers** (`lib/game.js`, `/ws/<id>`; `/ws` the first): TMNF's modes (`lib/modes.js`):
  TimeAttack; Rounds (start = now + 3 s for everyone, one finish each, the round ends when all
  are in, 15 s after the first finish or at its limit; 10 6 4 3 2 1 points; the map ends at the
  points limit or after its rounds); Team (blue and red, balanced on join, each finisher scores
  racers - place + 1 for the team, the round to the higher team, first to 5); Laps (one race per
  map). Votes (next map, restart, kick; more than half of the racers in 30 s; one at a time, a
  minute between a player's calls), spectators, chat; official servers send ranked results to the
  ladder (TimeAttack each round, Laps each race, Rounds/Team at the map's end) and finishes to the
  records. Protocol 2 (the game's `Online.VERSION`). Players who join during a round's pre-start
  countdown race it.
- **Process and hosting** (`server.js`): `--config=config.json` (`config.example.json`: four
  official servers) or the old arguments; `Dockerfile` (built from `stadium/`: the server, the
  track list, the zones; data on `/data`), `docker-compose.yml` (the server and `cloudflared` with
  a named tunnel's token from `.env`), README "The official servers" (the one-time Cloudflare
  steps, updating, backing up the accounts).
- **Game**: `net/tm_master.gd` (autoload `Master`: the token in the settings, never the password;
  register, log in, log out, refresh, profile push, servers, rankings, records, solo finishes);
  the Online page (`ui/tm_menu.gd`): your account (log in / register with the Profile's nickname
  and zone; ladder points, world/zone rank, log out), SERVERS from the master (name, mode, track,
  players; JOIN, SPECTATE) and RANKINGS (world / your zone), join by address; the Profile's
  nickname and zone pushed to the account; the campaign's details show the world record and your
  place; solo finishes go to the online records when logged in.
- **In the race** (`race/race.gd`, `race/tm_race_online.gd`, `net/tm_online.gd`): synced modes
  hold the countdown on the server's clock (everyone starts at the round's start, whatever the
  frame rate), no restarting mid-round (respawn before a checkpoint puts you back at the start,
  clock running), late joiners wait for the next round; the scoreboard shows points (Rounds/Team)
  or times, team tags and colours; results show the round's points, team scores, the map's
  standings and your ladder points won or lost; the next round of a map restarts in place; votes
  (V: next map, this map again, kick a player; F1/F2 on the running vote, shown at the top);
  spectating (F3; Left/Right: whom to follow) with a follow camera.
- Tests: `server/test/master.test.js` (accounts, rate limit, ladder, rankings by zone, records,
  the server list, the store), `server/test/modes.test.js` (Rounds, Team, Laps, TimeAttack votes,
  a room with accounts, spectators, votes, ranked results and records, the ladder after a map):
  18 server tests; `tests/test_online` (27 checks: addresses, register/log in/wrong password,
  server list, records, rankings, joining as the account, a finish as a record, then a Rounds
  server: the held start, starting together, no restart mid-round, points, the next round in
  place, a vote to the next map, spectating). Tests use their own settings file
  (`--settings=`), so they never touch the player's login or nickname.
- Open: the owner deploys it on the Pi (README: create the named tunnel, put its token in `.env`,
  `docker compose up -d --build`, put the hostname in `official.json`). Not built here: LAN
  discovery (join by address works), a hotseat mode.

## 2026-10-18 — Session 13: the M9 code review's findings, fixed one by one
The review (`docs/research/m9_review_findings.md`, 42 findings; its status column says what was
done for each) is checked against the code finding by finding, fixed, tested and pushed in batches:
- **Batch 1** (498d83a): `TestHooks.is_testing()` only from the command line (a res://tests/ scene
  or --frames/--shot), so Master finds the server in real play and a track or replay that fails to
  load shows a message with Esc back instead of quitting; tracks without a start refused; menu lists
  select on press (DELETE names what it deletes, JOIN takes the picked server); lists scroll with
  focus; races return to the page they came from.
- **Batch 2** (97d6f23, editor): ground-only blocks turn in their own box and stay on the ground;
  32 levels; a lap track starting on its line needs a checkpoint; file names never hidden; the
  ghost and the messages refresh; key repeats only move; the race redraws the medals after
  validating.
- **Batch 3** (replays): replays keep the race's laps and checkpoints per lap, so the viewer
  counts lap lines as laps (lap_done, "Lap 2 / 2") and each lap's checkpoints; the car's roll for
  2.5 s after the finish is recorded (`TmReplay.TAIL_MS`; the record's autosave is written again
  with it); a paused or ended replay stands still (no speed, wheels, engine: `TmCarAudio.set_paused`);
  the viewer's keys are read in `_input`, so a hovered bar button or the time line can't take
  Space or the arrows, and the time line seeks as it changes (wheel, drag); the viewer's sound
  follows its race (countdown, GO, checkpoints); a turbo is one event (`F_TURBO` and the turbo cue
  on its rising edge, not every tick a pad renews it; a seek back cues again); only `_last.replay`
  is hidden from the list, and file names lose $-codes and a leading `_`; Esc from watching the
  run comes back to the finish menu as it was (SAVE REPLAY still there, or SAVED).
  `tests/test_replay`: 29 checks (8 new).
- **Batch 4** (menus, music, server): canvas textures sample their mipmaps (project setting
  `default_texture_filter` = Linear Mipmap: the medals and the logo, drawn 2-5x their size, no
  longer alias); a guest name that shows nothing without its $-codes becomes "Player" on the
  server (test); CLEAR ALL RECORDS is disarmed on every visit to Options; the race menu removes
  its old content before it takes its size (the second pause panel no longer doubles), and its
  deferred focus skips a button a second fill took away; picking a colour or a zone on Profile
  keeps the focus there; the Editors page's CHANGED column is local time; LOG OUT rebuilds the
  Online page only if it is still shown, a rejected token shows the log-in form, and the account
  is asked for once per visit (no refresh loop); no NOW PLAYING toast with the music off; Master
  doesn't parse an empty answer. Also: the campaign cards are tall enough for their best time
  (it was cut off at the bottom). `tests/test_menu` 31 checks (4 new), server tests 19.
  With this, all 42 findings are fixed (the doc's status column).

## 2026-10-18 — Session 13 (M9-8): the campaign's research, and the builder lays TMNF's surfaces
- Research (`docs/research/m9_campaign.md`, our own `tools/research/tmnf/campaign_stats.py` and
  `track_ascii.py` on a local install): TMNF's A-E series, kinds (Race, Speed, Acrobatic,
  Obstacle, Endurance), times, checkpoints, laps and surfaces. Its tracks are mostly platform and
  circuit, not the tarmac road our SF tracks use: that is much of why ours looked cheap.
- `race/tm_track_areas.gd` (TmTrackAreas) + `race/tm_track_builder.gd`: surfaces in a track
  spec: `["circuit", w]`, `["platform", w]` / `["platform", w, "walls"]` (lanes w cells wide:
  the cells within w * 16 m of the line, filled with plates once laid; platform plates take their
  variant from their neighbours), `["dirt"]` (dirt road on the ground), `["road"]`; the joins
  (`StadiumPlatformToRoadMain` a level below the road, `StadiumRoadDirtToRoad`); on a lane: s, l,
  r, gt, cp (the platform gate, on a one-cell lane), turbo (a row of platform turbos), up, down,
  climb, dive (slopes: 2 levels a straight, 1 over each end; platform straights a level higher
  than circuit ones). Then TMNF's editor's work: circuit borders in the empty cells round the
  circuit (straight facing the plate, inner corners, outer corners), slope borders beside circuit
  slopes, platform walls over a walled lane's open edges; pillars under raised plates (not under
  walls and borders). Orientation rules measured from the official tracks (which side a border,
  gate, slope or join faces). The builder's units of ground-only blocks now turn in their own box
  (the review's finding 10, here too). `race/map_view.gd --view=path:<0-1>`: a driver's view
  along our track's line. `tests/test_track_areas` (9 checks, in the gate): the lanes lay out,
  circuits are closed by borders that face them, walled platforms have their walls, slopes climb
  as TMNF's, a gate on a wide lane is refused, dirt roads lie on the ground, and the bot drives
  an area track and a dirt track to the finish (the turbo row boosting it).

## 2026-10-18 — Session 13 (M9-8): the White series (A01-A15)
- Our own 15 White tracks in TMNF's structure (`tracks/A01..A15.json`; kinds as TMNF's slots:
  Race, Acrobatic A04/A10, Obstacle A06, Endurance A08 (3 laps), Speed A12/A15), mixing circuit
  (A01, A08, A13, A15), walled platform corridors (A06, A07, A13), wide platforms with turbo rows
  (A04, A12), dirt (A02, A05, A11, A14) and road with hills, jumps and a loop (A03, A09, A10).
  Medals from the bot (author = its best of five grips; gold +6%, silver +20%, bronze +50%):
  authors 6.4 s (A04) to 48.5 s (A08, 3 laps); most 15-23 s (TMNF's White: 6-29 s, A08 1:04).
- `tracks/campaign.json` lists series (`{"series": [...]}`): White, then the old SpeedFest tracks
  until the other series exist (the menu shows a tab per series). The server reads the series too
  (`server/lib/rounds.js ownTracks`, test).
- Builder: lap races (`"laps": n`, the start is the start/finish line, `["close"]` ends the lap
  on it; the bot's line repeats per lap); lane cells now come from the line by piece (straight:
  the cells beside it; turns: every cell within w*16-4 m of the line between the turn's faces, so
  no wall stands where the car goes); a hole a border can't close (a one-cell gate inside a wide
  lane) is an error that says what to do. Dirt roads cut the stadium grass under them (they were
  hidden under it: `blocks/tm_map_builder.gd`, also for TMNF's maps).
- `tests/test_tracks`: every campaign track lays out and builds; the bot drives each series' first
  track (it drives at about real time; `--series=White`, `--tracks=all` or a list drive more);
  a time limit from the line's length for long tracks. Road-gate checks (crown screens, respawn,
  replay turbo) run on SF01. `tests/test_track_areas`: a lap race (11 checks).
- **Green B01-B15** (same day): in the campaign with medals from the bot: authors 11.7 s (B09) to
  30.6 s (B12), B08 1:27 (5 laps of dirt and road); 1-6 checkpoints; more joins between surfaces,
  loops and jumps, walled-platform obstacles (B06, B13), wide-platform dives (B14). B03's loop on a
  high road became a jump (the bot fell out of the loop: too slow after the platform).
- **Blue C01-C15**: authors 11.6 s (C10) to 33.5 s (C09), C05 55.7 s (2 laps), C14 48.5 s (3
  laps); 2-6 checkpoints. What the bot taught the layouts (the rules for every series now): a loop
  needs speed (a turbo and two straights before it, never straight off a join or a landing); no
  gate within ~4 blocks after a fast crest (an area slope's top launches the car 150-200 m over
  it); no tight turn just after a crest. Builder: area slopes mark their crest (where the car
  slows) at the top both ways (going down it was marked at the bottom).
- **Red D01-D15 and Black E01-E05**: the campaign is complete, 65 tracks in TMNF's five series
  (`tracks/campaign.json`; the SpeedFest tab is gone, SF01-SF11 stay raceable by id). Red: authors
  13.0 s (D11) to 42.4 s (D05), laps D01 1:39 (5), D06 50 s (3), D14 1:21 (3), D15 4:51 (10);
  3-9 checkpoints. Black: E01 38.1 s (6 gates), E02 1:02.7 (one long lap through three rings
  climbing inward, 15 gates), E03 1:52.8 (3 laps of everything: road, circuit, walled platform,
  loop, dirt), E04 52.1 s (a walled platform spiral down, 10 gates), E05 6:34.7 (20 laps).
  The layouts were planned with an untracked turtle (the builder's cell moves in Python, for lap
  closures: with four right turns of the same size, opposite legs move the same number of cells)
  and checked by the builder and the bot.
- Online: a track spec with `"online": false` stays off the servers' rotation (D15, E05: too long
  for a Time Attack round); `server/lib/rounds.js`, test. Docs: README "Make a track" (the
  surfaces, laps, the layout rules), `stadium/CLAUDE.md`, PLAN M9-8 checked,
  `docs/research/m9_campaign.md` (our series).

## 2026-10-18 — Release `stadium-v0.4` (owner's Windows PC): `stadium` + M9
- Owner: "release the most up to date version ... of the stadium", then chose "stadium + M9
  branch" (TRANSCRIPT "Release"). `stadium` (23b5e2f: v0.4's session-14 work and the rotating
  adverts) merged with `claude/tmnf-replica-graphics-nb1kcg` (8772c31: M9-7 online, the M9
  review's 42 fixes, M9-8 the five series A01-E05). The code merged without conflicts; PROGRESS
  and TRANSCRIPT conflicted only where both sides appended (both kept, `stadium`'s first).
- STADIUM_TESTS PASS on the merge, on the owner's PC (Godot 4.7.2, `TMNF_DIR` set): model_lab 44,
  car_body 22, car_shapes 11, gbx 8, blocks 8, ghost 19, replay 29, editor 35, menu 31, sound 13,
  online 27, race 40, track_areas 11, tracks 148, server npm test. (The script's `--import` step
  segfaults on exit on Windows; the import itself completes and every suite runs.)
- `stadium/PLAYING.txt` rewritten (it goes into both zips and is the Release's notes): the 65-track
  campaign in five series, SOLO / ONLINE (accounts, servers, rankings) / EDITORS / PROFILE,
  replays, the online keys (T, V, F1/F2, F3), `--race=A01`.
- Tag `stadium-v0.4` on the merge commit, pushed from the PC; CI "Stadium builds" makes the
  GitHub Release with the Windows and Linux zips. Session 15's unfinished branch
  (`ccr-1ce252fc-wl7p3m`) is not included.
- The official server was down (no node / cloudflared on the PC). Owner: "Yes, start the official
  server on this PC with run_official.ps1 -Publish so v0.4's ONLINE finds it." Started with M9-7's
  server (master + one Time Attack server on the A-E campaign; data in the gitignored
  `stadium/server/data/`); the new quick-tunnel address is in `official.json` (b150220). Checked
  through the tunnel: `GET /`, `/api/servers`, and a spectator's `hello` on `wss://.../ws/main`
  answered with `welcome`.

## 2026-10-18 — Session 13 (M9-2): the decks, walls and dirt roads in TMNF's look
What the campaign shows most, compared side by side with TMNF's own meshes and textures at the
same camera (`map_view --ref=<local dir>`, research only, nothing of it committed):
- **The reference renders were wrong until now**: TMNF keeps a normal map's x in the alpha
  channel (red is empty), so every reference surface leaned along -x and its brightness was off
  (the decks looked 40% brighter than ours). `blocks/tm_ref_visuals.gd` moves alpha into red;
  with that, TMNF's deck and ours render alike (127 vs 115 in the same light).
- **Decks** (platform and circuit, key "platform"): our own `platform_plate` (one texture per
  32 m block, world-mapped so its edge is the block's seam; light steel with smears and skid
  marks along x, no more 4 m tile grid) and a **detail map**, `tread_plate` (diamond tread, 1 m),
  through a new detail layer in `blocks/tm_textured.gdshader` (`TmMaterials.DETAIL`).
- **Platform walls** (`Platform/Wall/*`, the builder's wall borders): dark charcoal concrete panels
  (`platform_wall`, joints every 8 m and halfway up), as TMNF's, instead of light cladding.
- **Circuit walls**, mapped from where TMNF puts each material on the section: outside, a black
  rubber foot, a light band, a blue band with our name (`circuit_band`), plain white cladding
  (`circuit_panel`), a blue top lip (`circuit_trim`); lane side, the dark blue floor strip
  (`circuit_floor`), a black bumper, the screen, dark steel truss (`steel_truss`). The red rubber
  and the gridded white panels are gone.
- **Dirt roads**: a packed track lighter than the berms, combed by tyres along the road
  (`dirt_road`, UV-mapped along the piece), blending into the loose dirt (darker now, TMNF's
  tone) on the berms and slopes: `blocks/tm_dirt.gdshader`, key "dirt_road" (`blocks/shapes/dirt.gd`).
- Textures: `stadium/tools/texgen/decks.py` (new) and `surfaces.py` (dirt road; the old
  `platform_panels` removed).
- Next in M9-2: fences and signs along the dirt roads, tube pillars, decoration for the area
  tracks, light and atmosphere, the RTX preset. Open question for the owner: TMNF's circuit
  screens are dark; ours show the adverts.
- (same day, next step) **Control booths** (`blocks/shapes/control.gd`): TMNF's materials there
  are a dark steel roof (its dark truss texture), white sides and smoked windows; ours had blue
  seats on the roof and pale blue glass. Now "truss" on top, "control_panel" white sides,
  "glass_dark" windows and light-rig tops. **Grandstand trusses** (`blocks/shapes/fabric.gd`,
  TRUSS): the arches TMNF hangs under the roof (measured: light ones 1.45 m deep at z 0.3,
  12.5, 19.5, 31.7; the main one at z 16, 5 m deep at the foot to 4.4 m at the top) as real
  geometry following the underside (white chords, dark lattice, visual only); the underside's
  ribs now every 16 m to meet them. `map_view --view=gate:...:look_y` looks up (under a roof:
  `gate:StadiumFabricStraight1x1:0:20:3:14:30 --gz=30` on A03). Both new shaders render on the
  web renderer (Compatibility) too. **Boards** (`BOARDS`, measured): two advert screens hung on
  cables from the main truss facing the field (turned 3 deg steeper than TMNF's so the screen
  shader shows adverts on them) and one on the back of the roof's foot.
- (same day) **Ultra (SDFGI) left the roofs black underneath**: with SDFGI on, a fabric roof's
  underside gets only the light that bounces off the dark grass (doubling SDFGI's energy or its
  bounce barely changed it; the baked sky occlusion and more frames neither). Real membrane roofs
  let 10-15% of the sun through, and TMNF's lightmaps show them light: a membrane glow on
  surfaces facing down, for the fabric keys (`TmMaterials.TRANSLUCENT`: grandstand roofs, the
  stadium's roofs), through a global shader parameter `tm_membrane` (env/tm_occlusion.gdshaderinc)
  that `TmRtx` sets to 0.35 on Ultra and 0 otherwise. High is unchanged (checked side by side).
- (same day) **Grandstands at raised gates** (`race/tm_track_decor.gd` `_stands`): the platform and
  circuit tracks start and finish up to 14 levels up, and the decoration put stands only by gates
  on the ground, so those tracks had none (a probe of all 65: no stands, booths or rows on any
  area track). TMNF's A07 shows how it dresses a raised track: the raised stand
  (FabricStraight1x1's air variant) on a stack of fabric pillars, the ground piece and then pieces
  three levels tall. Raised gates now get that, the stand at the pillar step nearest the road's
  height, both sides, placed all or nothing (`_try_all`); area tracks now have 6-16 stand blocks
  (C14: no room).
- (same day) **M9-0's research notes**: `docs/research/m9_look.md` (TMNF's materials per block
  family with the measured colours and heights, how its maps are laid out, the Day light, how to
  compare locally), `m9_sound.md` (the gear model and the engine's six layers), `m9_menus.md`
  (look, structure, in-race). With `m9_online.md` and `m9_campaign.md` the research step is done;
  PLAN M9-0 and M9-2 checked (M9-2's polish listed there): **M9 is complete.**

## 2026-10-18 — Session 13 (M10): the owner's five requests after M9
Owner (TRANSCRIPT): keep the circuit screens dark; tyre marks when drifting or braking hard like
TMNF's; the physics off asphalt and in jumps against TMNF; the look, UI, menus and sound identical
to TMNF, compared side by side with screenshots. Worked in that order.
- **M10-1 dark circuit screens**: the circuit walls' lane-side screens are "screen_dark" (glossy
  black, off), as TMNF's StadiumCircuitScreen; the adverts stay on the boards and other screens.
- **Circuit wall foot** (owner: "on the right there is a blue line/blue kerbs, on the left just a
  dark tile"): from TMNF's material placement, the lane-level strip along the wall is its bright
  blue border texture, the rubber above it black with small logos and a grey line, a thin blue line
  under the light cap at the top. Ours now: `circuit_kerb` (blue painted plate, fine grooves, a
  joint plate every 16 m, world-mapped), `circuit_bumper` (black rubber, grey edge lines,
  SPEEDFEST every 16 m) and the blue trim on the lane side's top edge; checked side by side.
- **M10-2 tyre marks** (owner: "When you drift or brake hard, i want to see scratchmarks like in
  TMNF"): `race/tm_tyre_marks.gd` (TmTyreMarks). While a wheel slides on the ground (a drift, or
  the wheels locked by hard braking: `TmCarModel.sliding`) and moves over it faster than 3 m/s, it
  lays a mark one tyre wide (0.3 m) behind it, a segment every 0.4 m joined end to end, of its
  surface's kind: black rubber on the road, decks and concrete, grooves in dirt and dirt roads,
  torn turf on grass and snow, none on ice or water. Each kind is one MultiMesh of quads with a
  ring of 3000 (rubber) / 1500 segments (the oldest quarter fades out as it is reused;
  `race/tm_tyre_marks.gdshader`, textures from `stadium/tools/texgen/marks.py`). Light grey smoke
  puffs off sliding wheels on the road, dust on dirt, bits of grass on grass. The marks stay for
  the run and clear on a restart. Replays lay them too: a sample now records which wheels slide
  (`TmReplay.F_SLIDE0`, bits 9-12; older replays fall back to "the wheels on the ground slid"),
  the viewer finds the surface under each wheel (`TmBody.surface_under`) and clears them on a
  seek. `tests/test_tyre_marks` (in the gate, 12 checks): kinds by surface, none while gripping
  or in the air, laid while sliding, segments join, none across a respawn, the ring reuses the
  oldest, clear; on SF01 the bot lays none pulling away, some by the finish, none after a
  restart. Checked in renders: a hard brake into a turn leaves two curving black streaks.
  Also `race.tscn --trace=<file>`: the car's state every 100 ms as JSON lines (for M10-3).
- **M10-3 the physics off asphalt** (owner: "Revisit the physics on grass or dirt or anything else
  than asphalt, it feels a bit different than TMNF"): measured against TMNF's own runs. Every
  campaign replay holds four ghosts, TMNF's simulation sampled every 100 ms with each wheel's
  surface and sliding flag, and the run's inputs: `tools/research/tmnf/ghost_dump.py` reads them
  (record chunk 0x0303F005, inputs 0x03092019), `accel_curve.py` / `lateral_grip.py` /
  `air_check.py` measure TMNF's accelerations by surface and speed, and `stadium/race/ghost_fit.tscn`
  puts our car in a ghost's state and drives it 0.5 s with the run's own inputs (README of the
  toolkit, "TMNF's own runs"). Found on the way: **our world is TMNF's mirror image** (x negated):
  A01's author run drives our car along TMNF's line only with left and right swapped (0.5 m apart
  after 2 s). On asphalt the model agrees to centimetres (0.16 m, 0.2 km/h median after 0.5 s).
  **Grass and dirt were wrong: the surface table's columns were misread.** TMNF accelerates on
  grass at exactly 0.4x asphalt's curve at every step and brakes at 30 x 0.05, on dirt 0.9x and
  0.4x: column 2 is the drive, column 3 the brakes; started from ghost states, our car follows
  TMNF best with column 1 as the grip (grass 1.08 -> 0.24 m apart, 3.4 -> 0.7 km/h; dirt 1.47 ->
  0.44 m, 12.7 -> 1.9 km/h; the other readings tried are in `docs/research/tmnf_physics.md`
  §3.10). So on grass the car now keeps 40% of its drive (was 15%) and 15% of its grip (was 5%)
  and barely brakes (5%, was 40%); dirt drives at 90% (was 25%) with 25% grip (was 40%) and 40%
  brakes (was 90%). `TmTuning.SURFACES` keeps the file's order, read through `S_TOP`, `S_GRIP`,
  `S_ACCEL`, `S_BRAKE`. `test_model_lab`: grass 0-100 in 4.35 s, dirt 1.93 s, braking on grass at
  220 km/h 20.8 m/s^2 (TMNF 20.7), ice drives slowly. Also: a ghost records the car's model
  origin, not its centre of mass (the recorded positions move like a point 0.29-0.40 m behind
  the recorded velocities' in turns; StadiumCar.Solid puts the centre of mass 0.4385 above and
  0.288 ahead of the origin): with that offset the asphalt fit tightens to 0.10 m.
- (same day) **Tyre smoke fix**: freshly emitted puffs drew as black blobs in Forward+ (an
  alpha-blended CPUParticles3D in index draw order; probe: plain colour or opaque drew fine, depth
  order fixed it): puffs are now drawn back to front, light grey on the road, tan dust on dirt,
  green bits on grass, on both renderers; and they grow as meant (a Curve's range is 0..1 unless
  widened first: the growth to 2.6x was clamped to 1). `ghost_fit`: the start velocity now comes
  from the neighbouring positions (a ghost stores velocities with 8-bit direction angles, up to
  ~0.7 m/s off; in pure flight that alone made 0.38 m of the 0.5 s error, now 0.02 m), and
  `--trace_at=<t>` prints our car tick by tick through one window.
- **M10-4 jumps against TMNF** (owner: "Revisit jump physics whether it's the same as in TMNF"):
  measured, model unchanged. Flight is identical (0.01-0.02 m apart after 0.5 s in the air, gravity,
  drag and spin decay checked separately over every campaign ghost: `air_check.py`); take-offs agree;
  landings agree in the median with scatter both ways. The one visible difference: TMNF's car pops
  onto its rear wheels after a nose-down landing (12-20 deg nose-up for 0.3-0.5 s) and sometimes
  loses 4-15 km/h; ours lands flatter and keeps its speed. Contact-stiffness variants did not
  reproduce it (`docs/research/tmnf_physics.md` §3.7b, numbers there); the mechanism is in TMNF's
  wheel contact code, not read this session (reading the decompiled code was blocked by the
  session's safety check; asked the owner). Tools: `ghost_fit` groups landings/take-offs, counts
  wheelie time, `--trace_at` prints pitch and spin per tick.
- **M10-5 started: TMNF itself as the reference.** TMNF runs here under Wine (9.0, 32-bit prefix
  outside the repo, an offline local profile; its network shut off with `unshare -n`, so no
  account is created anywhere; shader quality PC2, Wine's own shader compiler can't build PC3's).
  Reference screenshots of its menus (globe, the left column of icon rows, green title bars, the
  campaign's grid of thumbnails), loading screen, opponent picker, race HUD, countdown and race
  menu, and video of its countdown, all local only.
- **In-race HUD as TMNF's** (`race/tm_race_hud.gd`): the clock in TMNF's seven-segment digits in a
  pill on the bottom edge (a blue tint growing toward the bottom; negative before the start, as
  TMNF's: -0:02.60), the speed with the distance driven ("125 m") in a darkening pill in the
  bottom-right corner, the map's name and author (and checkpoints / laps) in a grey pill hung from
  the top right; no medal list on screen; "Press Return to respawn / Press Delete to restart" when
  the car stands still. The pills' fills were measured against TMNF's frames (the speed's darkens
  every channel x0.76). The digits are our own drawing, `ui/tm_seg_text.gd` (pointed segment ends,
  a narrow 1, square dots, a drop shadow; letters fall back to the sans); pills by
  `ui/tm_pill.gdshader`. New fonts (SIL OFL): Cabin (a Gill-like humanist sans, TMNF's menus'
  feel) and DSEG7 Classic (`assets/fonts`, `TmUi.SANS`, `SANS_BOLD`, `DIGITS`).
- **TMNF's countdown** (measured from video of its restarts): the clock starts at -2.60 s (ours was
  1.5 s); the figures 3, 2, 1, Go! come every 0.75 s from -2.0 s, each shown 0.65 s, just above the
  middle, small (`TmRace.COUNTDOWN_MS`, `figure_at`; the beeps follow them). The figures redrawn
  upright in the sans with Go! pale inside a blue outline (`tools/texgen/ui.py`). `test_race` checks
  the schedule.
- **Race menu and finish card in TMNF's dialog style** (`ui/tm_race_menu.gd`, `ui/tm_ui.gd`): a dark
  glass panel (frosted only under the panel), a green title bar, white pill buttons with dark text
  (the focused one green-ringed), mixed-case labels as TMNF's ("Race menu", "Restart", "Resume",
  "Retry", "Replay", "Save replay", "Next track", "Quit"); the result card's time in the
  seven-segment digits; "Gold medal" / "New record" / "No medal". `race.tscn -- --pause` opens the
  race menu for screenshots. Tests follow the new labels (`test_menu`, `test_editor`, `test_replay`).
- **Menu assets drawn** for the coming menus: list icons (solo, online, profile, editors, quit,
  browse, back, replays, options, car) and a waving checkered flag per series
  (`tools/texgen/menu_icons.py` -> `assets/ui/icon_*.png`, `flag_*.png`), and the menu's globe:
  `tools/texgen/globe.py` draws the land map (Natural Earth 1:50m via world-atlas, public domain;
  cached outside the repo) into `assets/tex/globe_map_albedo.jpg`, `ui/tm_globe.gdshader` lights it
  as a slowly turning embossed sphere.
- **Menus as TMNF's** (`ui/tm_menu.gd`, compared side by side with TMNF running): black with our
  green globe turning behind (the profile keeps our car on the field); down the left a dark column
  with a grey header card (the page's title in bold italic, what to do, an icon: "Welcome! / Choose
  an activity", "Play Solo / Choose a difficulty", ...) and the page's entries as icon rows (white,
  green when focused, the current choice ringed green), Back or Quit at its foot; panels with green
  title bars beside it; a dark bar at the top right with your nickname, zone and the clock in the
  seven-segment digits (TMNF's bar has its volume and clock there). Main: Play Solo, Play Online,
  Editors, Profile, Options, Quit, your campaign's medals per series at the right (where TMNF lists
  your buddies). Solo is TMNF's campaign page: a row per series with its flag, the series' tracks
  as a 5 x 3 grid of cards (picture above, name below; the focused card all green with a play mark,
  your medal in its corner; a press races), the focused track's medal times and your best in the
  panel above; Replays, Browse (a track file), Back at the foot. Replays, Editors, Options, Profile
  and Online follow the same frame: lists as TMNF's light grey rows (the picked one white with a
  green bar), white pill buttons, mixed-case labels ("Watch", "Delete", "New Track", "Log in",
  "Clear all records"). The theme's buttons are TMNF's pills everywhere; the editor's block tiles
  and the cards share a square tile (`TmUi.glass("tm_tile")`). Tests follow the new pages and
  labels (`test_menu`, `test_editor`, `test_replay`). Next: pictures of our tracks on the cards
  (TMNF shows a shot of each track), the loading screen, the opponent dialog, the sounds.
- **TMNF's loading screen** (`ui/tm_loading.gd`): while a track loads (the menu's races and
  replays, the next track, a test drive from the editor), a keyboard with the race's keys lit
  orange (Esc, 1 2 3, Backspace and Delete, Enter, the arrows), blue arrows from white labels
  (MENU, CHANGE VIEW, RESTART, RESPAWN, DRIVE) and an orange progress bar, over a blurred picture of
  our car (`assets/ui/loading_bg.jpg`, rendered and blurred by `tools/icons/loading_bg.sh`). It
  goes once the new scene is in (at least 1.2 s), and the race holds its countdown until then
  (`TmLoading.covering()`). `--loading=hold` keeps it up for screenshots.
- **TMNF's three views** (`car/tm_camera.gd`, keys 1, 2, 3): the chase camera close behind (as
  before), one farther back and higher, and the driver's own from the cockpit; the choice is kept
  from race to race (`--cam_view=N` for screenshots). `test_race` checks the views, `test_menu` the
  loading screen's keys and cover.
- `tools/research/tmnf/sound_survey.py`: a sound's length, envelope, partials, pitch and octave
  bands, numbers only, to compare our cues with TMNF's (its sound files stay local).
- **Sounds as TMNF's** (`tools/sfxgen/cues.py`, numbers in `docs/research/m9_sound.md`): TMNF's
  cues measured (length, envelope, partials, octave bands; its files stay local) and ours
  synthesized to the same shapes, each cue's octave bands pulled onto TMNF's by a final EQ: the
  countdown's beep (a clean 756 Hz tone, 1.1 s, the same for 3, 2 and 1), the crowd roaring at Go!,
  the checkpoint's swoosh, the crowd cheering at the finish by medal as TMNF does (a big cheer with
  applause and whistles for gold and author, a smaller one for silver and bronze, none without a
  medal; TMNF's finish and record sounds are empty), a wall's crash (a broadband rattle instead of
  a metal clang), a new landing thump after jumps (`TmCarAudio._landing`, louder the harder it comes
  down), the menus' blip and tock (TMNF's Forever menus), the wind. Kenney's interface and impact
  sounds and the wind recording are gone (respawn stays); `test_sound` checks the landing.
- **TMNF's Select Opponent** (`ui/tm_race_menu.gd` `show_opponents`, `race/tm_medal_ghost.gd`): when
  one of our tracks is loaded from the menu, a dialog on black before the race, as TMNF's: Gold
  Medal, Silver Medal, Bronze Medal (each with its disc and time), Personal Best (when you have one)
  and None; the next medal to win is focused (bronze when you have none). TMNF races recorded medal
  ghosts; ours are our bot's run (TmBot driving the track once, unseen, about 25x faster than real
  time behind the loading screen; 0.8 s for A01) slowed to each medal's time: the same line,
  arriving on the medal's time. The run is kept per track for the session. A medal opponent stays
  when you set a record; Personal Best follows your record. `--opponent=ask` shows the dialog in
  screenshots, `--opponent=<kind>` picks one. `tests/test_opponent` (in the gate): the bot's run
  finishes near gold, a medal ghost arrives on its time along the same line, the dialog lists the
  medals and None and a pick sets the race's ghost.
- **Track pictures on the campaign cards**, as TMNF's (`tools/icons/thumbs.sh`): every campaign
  track built by `race/map_view.tscn` and shot from above and behind its start, cropped to the
  card's shape, 316 x 200 JPEG in `assets/ui/thumbs/<ID>.jpg` (1.2 MB for 65; imported lossy for a
  small web build, as is the loading screen's picture); a card without one keeps the map's outline.
  About 70 s a track under the software renderer: run the generator alone (two renderers at once
  ran this container out of memory). The race also waits for the loading screen's fade before its
  countdown (`TmLoading.covering()`). Not copied: TMNF's padlocks (its later tracks open as you
  finish earlier ones), which would change play; the owner's call.
- **The race menu lists Select Opponents**, as TMNF's does (for our tracks with medals, not online
  or in a test drive): it opens the dialog again, and a pick there starts the race over with the
  new opponent. Its list pills are slimmer with smaller text, as TMNF's. `test_opponent` checks it.
- **M10-6, TMNF's top bar** (owner: "yes build it, in races too"; `ui/tm_top_bar.gd`, drawn after
  TMNF's): at the top right, a sound volume wedge with its knob and a speaker (a press mutes), a
  music volume wedge and a note (a press turns the music off), display settings, the clock in the
  seven-segment digits and a window button (fullscreen / windowed). In the menus it stays up with
  your nickname and zone at its left and its display button opens the Options page; in races and
  replays it slides down when the mouse reaches the top edge, stays while the mouse is on it and
  goes 0.6 s after it leaves; there its display button opens a small panel (graphics quality,
  shadows, HD). New setting `sound_volume` (the master bus; Options has its slider too). Not
  copied: TMNF's 3D glasses button (no stereo mode). `--top_bar=show|display` for screenshots;
  `tests/test_top_bar` (in the gate).
- **The top bar spans the window's full width** (owner: "the bar should be as wide as the window
  screen"; TMNF's covers the right half): in races and replays it slides down across the whole top
  edge; in the menus it runs across the top and the left column starts under it. The bar is opaque
  (the race HUD's track name no longer shows through it).

<!-- (another session, in parallel on branch `claude/sleepy-albattani-o7ygr1`, commit 1e91708; brought in for v0.5) -->

## 2026-10-19 — Session 11: `WheelAbsorbContact` re-read; the "bottomed" flag is real

Owner approved reading TMNF's code to settle the wheelie-after-nose-down-landing question (the
screenshot's plan: confirm what the flag in `WheelAbsorbContact` represents, because if it were set
on every real contact the full impulse would land at the contact point and kick the nose up).

- Rebuilt the RE pipeline from scratch in a cloud container **without Ghidra or REA**: the official
  installer (SHA-256 `2f659138…6355`, the same build as session 9), `7z` + `innoextract`, then plain
  `objdump -b pei-i386` sliced by the addresses in `TmForever.map`. New `tools/research/tmnf/dis.py`
  (annotates call targets and float constants from the map) and `fnmap.py` (name → start/end/size).
  Both committed; README updated with this lighter path. Ghidra is only needed for pseudocode.
- **The hypothesis is wrong.** `WheelAbsorbContact` (0x7c11d0, 1600 bytes) sets the flag in exactly
  one place — `room <= penetration`, i.e. the spring could not swallow the whole penetration — and
  the full-impulse-at-the-contact-point branch is taken only when that flag is set or the normal
  approach is already non-negative. Written up as **§3.2a** of `docs/research/tmnf_physics.md`.
  `stadium/core/tm_body.gd::_collide` already matches it branch for branch, including both impulse
  application points (contact point when bottomed, wheel centre otherwise), the `|n_car.x| >= sin 45°`
  side test and the 0.8 keep factor. Also confirmed `0x184 == 0x18c == -0.8` and `0x178 == 0x17c ==
  -0.5`, so the surface-4 variants the code selects are identical and our single constants are right.
- The whole block is gated on `tuning[0x350] == 2`; re-decrypted the `20juin2006` tuning to confirm
  it is 2 (and `0x354 == 5` = force model 6), matching §5. The force model is `0x354`, not `0x350`.
- **Two real gaps found in `AddVehicleImpulse` (0x7be390)**, new **§3.2b** and three table rows:
  the angular `r x j` term is scaled by **0.55 [0x0ec]** before it is added, and `|w|` is then
  clamped to **100 rad/s [0x14c]** (never binds). Linear is `j / mass`, unscaled. Our
  `tm_body.gd::_apply_impulse` applies the full `r x j`, so **our contacts over-rotate by ~1.8x**
  relative to TMNF. Not the wheelie cause (it makes us rotate more, not less) but a genuine fidelity
  bug in the contact layer.
- **Next for the wheelie:** the contact layer is exonerated, so look at what feeds it — the spring
  force and its application point during the compression (§3.2), the ground/air gravity switch
  (3.0 ↔ 2.5 [0x160/0x164]) at the moment of touchdown, and the load-transfer torque
  [0x228–0x23c], which `tm_car_model.gd` does implement. Fixing the 0.55 first is worthwhile on its
  own and changes landing behaviour, so it should land before any wheelie tuning.

## 2026-10-19 — Session 13 continued: the contact spin fix (v0.5)
- **Every contact impulse now turns the car at 0.55 of r x j** and the spin is capped at 100 rad/s,
  as TMNF's `AddVehicleImpulse` [0x0ec, 0x14c] (found by the parallel session on
  `claude/sleepy-albattani-o7ygr1`, commit 1e91708, brought in; `core/tm_body.gd`, `TmTuning.
  IMPULSE_SPIN`, `MAX_SPIN`). Measured against TMNF's own runs on the six jumpiest tracks: landings
  end 0.26 m from TMNF's (was 0.34), speed error median 1.9 km/h (was 2.2, p90 15.7 from 17.7); the
  car now pivots onto its rear wheels after nose-down landings for 20.8 s over those windows (was
  10.5; TMNF 30.5). The rest unchanged (0.14 m overall). On flat ground ours lifts its nose a little
  more than before (19.1 s of the ground windows, was 14; TMNF 5.9): open. The body and model tests
  pass unchanged.
- Two checks followed it. The lab's quarter pipe (`tests/test_car_shapes`, our own shape, not a
  TMNF block): the car rides it but bounces along it more (4 wheels down 25-71% of the ride's
  second half over 9 entry angles and speeds, was 54-81%), so "on its wheels at the end" now means
  all four touch in the last second, not at the one tick 5 s in. And recording a run's inputs
  (`--record_inputs`) now keeps the steer at the script's resolution (TMInterface's 1/65536): the
  runs are chaotic enough that SF01's replay drifted off after 16 s from the 6-decimal rounding
  alone; replays are exact again.


## 2026-10-19 — Release `stadium-v0.5`: `stadium` + M10
- Owner: "take into account claude/sleepy-albattani-o7ygr1 (1e91708) (small physics bug fix) and
  merge into stadium to release v0.5". 1e91708's research (WheelAbsorbContact re-read, §3.2a/§3.2b,
  `dis.py`, `fnmap.py`) brought in alone (that branch forked from old `main`, so not merged
  whole); its find, the 0.55 contact spin, put in (above).
- `claude/tmnf-replica-graphics-nb1kcg` (M10: dark circuit screens, tyre marks, the surfaces and
  jumps against TMNF's runs, the contact spin, TMNF's HUD, dialogs, menus, loading screen, camera
  views, cues, Select Opponent with medal ghosts, track pictures, the top bar) merged into
  `stadium` (210d298: v0.4, the rotating adverts, the official server's address). Conflicts: the
  docs (both sides kept, `stadium`'s first) and `blocks/tm_surface.gdshader` (the ads' new
  uniforms and M9-2's `translucent`, both kept). One fix the merge needed: the grandstands' advert
  boards (M9-2, `fabric.gd` `_boards`) were plain quads, which the rotating ads show as unlit
  panels; they are `screen_rect`s now, so the ads run on them too.
- `stadium/PLAYING.txt` (the zips' how-to-play, the Release's notes): the opponent ghosts, the
  camera keys 1-3, the volumes and the top bar.

## 2026-10-19 — Session 13 continued (after v0.5): the circuit ledges' blue as narrow as TMNF's
- Owner (screenshot of A01 from the lane): "In tmnf the blue parts are not as wide". The ledge
  behind a circuit wall (top 8 m, the lane's level) was blue all over; on inner corners, GT curves
  and diagonals that is a wide wedge. Measured on TMNF's border blocks (local reference meshes,
  per material at 8 m): the blue border strip (StadiumRoadCircuitBorder) is always 4.91 m wide
  along the wall, radially on curves, and the rest is the lane's deck (StadiumPlatform).
  `blocks/shapes/circuit.gd`: the curves' and diagonals' ledges are split into that band
  (`BAND`, "circuit_floor") and the deck ("platform", asphalt as the circuit base; the grip and
  drive factors are the same as before). Our ledge tops now match TMNF's per shape to 0.5% (e.g.
  GTCurve 3 In 721.0 / 1982.9 m² against 721.0 / 1975.9; Corner In 226.4 / 224.9 against
  227.5 / 220.8); A01's inner corner checked side by side with TMNF's blocks in the same view.

## 2026-10-19 — Session 13 continued: no more black tyre smoke
- Owner: "When braking, i still see the black thingies near wheels". Reproduced in the test arena
  (hard braking from 160 km/h, chase camera): the newest puffs at each wheel still drew as dark,
  near-opaque blobs; the draw-order change of M10-2 had only hidden it in some frames. Their colour
  came from the particle's vertex colour (a StandardMaterial3D with `vertex_color_use_as_albedo`),
  which went wrong for fresh particles. Now the puffs have their own shader
  (`race/tm_tyre_smoke.gdshader`: the particle billboard, unshaded, the colour a per-wheel `tint`
  for the surface, the particle only fading it), so a puff can fade but never draw darker than its
  tint. With the puffs at their intended opacity the road smoke barely showed on the light decks,
  so it is whiter and denser (0.9 grey at 0.55, was 0.78 at 0.3); dust and grass bits unchanged.
- (same day) Owner: "But dont just fix A01 but all maps which have that problem". The fix is in the
  circuit border generator, so it holds on every map that has circuit borders: our 26 tracks with
  circuits (A01, A08, A13, A15, B01, B05, B10, B12, B15, C02, C04, C05, C06, C11, C13, C15, D02,
  D04, D05, D07, D08, D12, D13, D14, E03, E05: 238 inner corners, all raised), the editor's
  tracks and TMNF track files. Checked shape by shape against TMNF's own blocks (every Circuit
  border and slope shape, flat, sloped and turned): the ledge's blue strip and the deck agree
  within 1%; C11 rendered as well. Two differences remain, both where TMNF has blue and ours
  doesn't, and only in pieces our tracks don't use: borders standing on the ground (TMNF lays the
  blue strip on the ground along the wall's outside, 4.7 m; ours is grey there and has none at the
  outer corners) and the walls across a slope (Slope/Straight Top/Bottom: TMNF's ledge steps are
  blue, ours grey). Left for the owner to decide.
- (same day) Owner: "Yes, match in every way". `blocks/shapes/circuit.gd`, measured on TMNF's
  border blocks (the blue is its StadiumRoadCircuitBorder texture wherever it is used):
  - Borders standing on the ground now lay the blue strip on the terrain in front of the wall's
    foot, 0.465 to 5.155 m out from the face (`GROUND_STRIP`), on every shape: straights,
    corners and GT curves (radially; outer GT curves widen mid-curve by 0.46 / 0.33 / 0.10 m for
    2 / 3 / 4 cells, `GROUND_OUT_BULGE`), diagonals (along the cell edges), with TMNF's rubber pads
    where it crosses a cell corner (2-cell outer, 4-cell inner curves, `GROUND_PADS`). It lies
    1 cm above the grass (`GROUND_LIFT`: no flicker, and a wheel's ray finds the strip, not the
    grass). Straights had a grey strip there; the other shapes had none.
  - Slope starts on the ground: TMNF's black rubber strip in front of the wall for the first
    12 m; ours had the straight's strip laid across the piece instead (a bug).
  - The walls across a slope (Slope/Straight Top / Bottom): their step is the blue strip, not the
    wall's top-lip blue.
  - Every blue strip takes TMNF's surface for that material (9, rubber; the ledge was metal): the
    same grip and drive, and the chassis slides on it as on rubber, not metal.
  - Checked per shape against TMNF (blue on the ground and up on the walls, the deck, the pads):
    within 2.5% on every Circuit border and slope shape, exact on straights, corners and
    diagonals; TMNF's B08 (ground circuits) rendered side by side with TMNF's blocks.

## 2026-10-19 — M11-1: the block-by-block look check against TMNF
- Owner: "yes do the systematic check and fix everything". New research tool:
  `stadium/tests/block_dump.tscn` (every shape we build as triangles with material keys and each
  key's mean albedo) and `tools/research/tmnf/material_check.py` (TMNF's surfaces sampled every
  0.5 m with their texture colour, matched to ours; colour differences, missing and extra
  geometry per shape, by our material key, by TMNF material). First run over the 548 shapes we
  build: colour differs on 23% of TMNF's area, 18% missing; the list, weighted by our tracks'
  block counts, is `docs/research/m11_check.md`. Fixing it family by family (PLAN M11-2).
- (M11-2) **Platform walls and turbo pads as TMNF's.** Our own border atlas
  (`tools/texgen/borders.py`, `border_atlas`: TMNF's band layout and colours, our emblem) and
  turbo pad (`tools/texgen/turbo.py`, `turbo_pad`: dark ribbed panels on a seam grid, a big yellow
  arrow each half, red scrapes); UV-mapped as TMNF maps its own (`TmGeo.band_quad`,
  `TmGeo.remap_uv`). The platform border wall's top, foot and ends carry the orange band with its
  blue line outside (it was charcoal all over; 4082 walls on our tracks); turbo pads (road and
  platform) are TMNF's chevrons, 16 m a tile along the road, mirrored about the centre line (the
  platform plate split at x = 16 for it). Checked: platform wall 5% of its area off (the logos'
  edges), turbo pads mean dE 14-15, side by side with TMNF's blocks on A04. `block_dump` now reads
  UV-mapped textures at their UVs.
- (M11-2) **Circuit sides, undersides and slope bases as TMNF's.** Our own circuit side texture
  (`tools/texgen/circuit_side.py`, `circuit_side`: TMNF's row layout and colours measured from its
  StadiumCircuit texture: light rails top and bottom, an orange band under the top rail and one
  over the bottom rail, dark panels; the left quarter, the blocks' ends, a bolted plate with vented
  strips; drawn here) on every upright circuit face (plates, ramps, ledges' outer faces), UV-mapped
  as TMNF maps it: 16 m a tile along the face, mirrored every other tile (faces cut where it turns,
  `TmGeo.remap_uv_sides`), the 8 m height down from the piece's top (on slopes from the road's
  edge). The walls' end caps take its left quarter in TMNF's two charts, below and above the ledge
  (`TmGeo.cap_uv` / `cap_split`, `circuit.gd _cap_uv`; key `circuit_cap`). Underneath: TMNF's
  white fabric (`fabric_auvent`, surface 9 as TMNF's) under raised plates, ramps and the curves'
  ledges outside the blue strip; its dark stands' floor (`truss`) under the strip and the
  straights' ledges. **Slope bases** (Start, Straight, End) are TMNF's 8 m thick plate following
  the road with a round pillar under its middle (12 sides, r 1.64 m, chamfered foot, a 24-sided
  collar under the plate; collision as TMNF's), not a solid block down to the floor. Faces TMNF
  doesn't have are gone: plates' and ledges' bottoms on the ground (under the terrain; collision
  kept), the ledge's side against the wall's back in curves. Check over the 63 Circuit shapes:
  colour differs on 9.1% of TMNF's area (was 20.1%), missing 0.8% (2.8%), extra 3,332 m² (67,478);
  the sides' texture mean dE 12; side by side with TMNF's blocks on A01 (slopes, pillar) and
  alone (`tests/block_view.tscn`, new: one shape in the Day light, `--ref` for TMNF's look).
  `map_view --view=near:` takes a yaw and height.
- (M11-2) **Roads as TMNF's.** TMNF's curbs, road lip and keel plates are bands of the same
  border atlas we recreated (our `border_atlas`): every segment of the road's section now picks
  TMNF's band at TMNF's rows (measured from its UVs; `road.gd` HALF_* fifth column, carried by
  `TmGeo.sweep` as atlas rows): the curb's round top and the ground pieces' outer face the light
  panel, its flat top the dark ribs, its faces the black band with a white line, our emblem and a
  blue line at the foot, the road's lip blue, the ground shoulder the green band. The keel's
  underside is TMNF's light plates (our `road_under`, texgen/decks.py), the shoulder and its
  underside TMNF's two-panel grid (our `road_grid`, texgen/road.py), road pillars TMNF's light
  concrete, the curbs' ends and the junction deck's closed sides TMNF's dark border metal; noses
  have the grid on top. **Ground slopes** (Slope/Straight, Base, Base2, BiSlope, U bottom) keep the
  raised road's section as TMNF does (open underneath, its keel into the terrain at the low end)
  with TMNF's round pillar under the raised end (r 1.42 m, flared foot and head; collision too),
  not curb faces walled down to the grass. Road family check: colour differs 11.9% -> 10.5% of
  TMNF's area after the atlas step (was 23% overall in the first run), missing 11.2% -> 10.5%;
  side by side with TMNF's blocks (straights, curbs, undersides, ground slopes).
- (M11-3) **The inflatable decorations as TMNF's** (our tracks place 1,170 of them: palm trees,
  snow trees, cacti). Measured from TMNF's blocks with a new tool, `tools/research/tmnf/blob_slices.py`
  (a mesh cut into horizontal slices object by object: centres and radii), and its textures'
  colours sampled over the surfaces: each block is a group, as TMNF's, not one rough shape.
  Cacti: four (two kinds, each twice turned), ribbed trunks with rounded tops and two arms each
  (level, then up), a white label band at the foot (ours plain with an ink line), a grey base ring,
  red tie ropes. Snow trees: four, tiered lathes with eight branches per tier (staggered), snow on
  each tier's rim and the top cone (where TMNF's texture is light). Palms: two sand islands (TMNF's
  outline) with grey rims, two leaning palms on each (ringed trunks darker at the foot, a white
  label band, five drooping fronds each of TMNF's three kinds, a crown cap, four black tie ropes).
  One near-white vinyl texture tinted per part (`inflatable_skin`, texgen/stadium.py). Collision
  fidelity (top-down, 0.15 m): cactus 86.5 -> 94.6%, palm 66.1 -> 82.4%, snow tree 81.6 -> 84.7%;
  side by side with TMNF's blocks.
- (M11-2) **Platform decks' sides and underside as TMNF's** (our tracks' most used block,
  Platform/Road/BaseAir, 1,489 on our tracks): the rim is the border atlas' ribbed edge and black
  underside with the blue line (TMNF's rows), the flat underside and foot ledge TMNF's light plates,
  and under the body TMNF's dark tray (chamfered, to the level's floor) with two slanted truss
  columns on every closed side, as TMNF's (measured; collision too). The airship's envelope takes
  TMNF's beige (its texture's mean), not the fabric white. Side by side with TMNF's block.
- (M11-2) **Grandstands and camera booths in TMNF's colours.** TMNF's Fabric stands are not blue
  seats: their top is the grey concrete band of its stands texture (149, 148, 147), the
  quarter-pipe front its dark platform floor (43, 44, 43), the backs and ends its dark Stands2
  (keys `stands_top`, `stands_front`, `stands_dark`; the big stadium's seating rake keeps its
  seats). Camera lights: dark with grey tops and light undersides (TMNF's Stands2 / Stands / Auvent),
  dark ends; camera galleries: a dark foot, TMNF's band of windows 1.56-2.79 m above the wall's
  foot, the roof grey along its edge and dark beyond, the ground plinth light. Side by side with
  TMNF's blocks.
- (M11-2) **Dirt roads' outline and the sculptures' plinth as TMNF's.** The dirt follows the
  ground's shape as TMNF's meshes do: next to the survey's dirt cells, the terrain off the grass
  level (more than 5 cm) is dirt and on it grass, each triangle cut along that level
  (`dirt.gd _split_tri`), so the dirt base's ring mound and the berms have smooth edges instead of
  the survey's 2 m staircase. The sculptures' plinth pads are TMNF's light panel, not red rubber.
  `tests/block_view.tscn` lays its grass under a ground block's own terrain.
- (M11-2) **FreeWheeling pads in TMNF's layout.** TMNF's free-wheel road is red, not the turbo's
  orange: our own texture (`texgen/turbo.py freewheel_pad`) is red ribbed panels on the turbo's
  seam grid with two yellow chevrons per panel pointing at each other, as TMNF's (key `freewheel`,
  Road/Main/FreeWheeling/*). Side by side with TMNF's block.
- (M11-2) **Start / finish roads and the gate line as TMNF's.** TMNF paints no pads: its finish
  block's road is red the whole way (z 0-17), its start block's green from the nose up to the line,
  a start/finish line's (MultiLap) green 8 m either side of it, each with a chequered strip two
  squares wide along both edges (RoadRace's layout and colours, measured; our own texture,
  `texgen/gates.py race_road`, with our chevrons where TMNF has its mark). The line across the road
  at every gate is TMNF's: 0.36 m of the border atlas' blue band (`road.gd _gate_line`, the road
  top cut there: `TmGeo.split_mat`). Our 8 m pads with the word and the checkpoint's 1 m band
  (`TmGateDress`, textures pad_start / pad_finish / line_cp) are gone; the grass checkpoint has
  no line (TMNF's has none). Side by side with TMNF's blocks.
- (M11-2) **Pipe pillars and tubes in TMNF's materials** (Tube/V/Pillar*: our tracks' most used
  block, about 8,100 on our tracks): the pipes are TMNF's light StadiumPillar concrete (key `pillar`,
  as the road's pillars) instead of our shiny steel, the junction collars and the cap's lid its dark
  RoadDetails (`road_metal`), the ground foot and the cap's ring its border atlas band, once round
  (the blue line low down, the black band with the white line above; `tube.gd RING_ROWS`). The
  RoadPub pipes too. Side by side with TMNF's blocks.
- (M11-2) **Platform decks' underside as TMNF's, take two.** The chamfered tray read TMNF's
  bounding box, not its shape: TMNF hangs a flat dark plate at the body's floor (in to the lip's
  foot on closed sides, to the edge on open ones), a hub in the middle (a frustum to the level's
  ground) and beams 1 m deep on the column lines: from each column of a closed side in to the
  square the lines make, and along each side of that square whose block edge is open (measured
  on Base, Straight, Corner, Cross, Checkpoint; `platform.gd _underside`, `_beam`). Material check
  on Platform/Road/BaseAir: TMNF surface we lacked 766 -> 125 m2, colour differs 291 -> 232 m2.
- (M11-2) **Platform slopes as TMNF's underneath.** The rim takes the deck lip's atlas bands, the
  ledges TMNF's light plates, the panel between them its dark Stands2 (not our blue seats), and
  under it TMNF's frame (measured): a round post from the level's ground to the plate's middle, a
  cross of struts slanting down away from it to 7.86 m out, and from each strut's end a truss up
  to under the rim (`platform.gd _slope_frame`, `_strut`). Material check (2StraightAir, 92 uses):
  colour differs 1211 -> 197 m2, TMNF surface we lacked 406 -> 50 m2; the BiSlopes alike.
- (M11-2) **The platform turbo deck as TMNF's.** Ours was a plate over a fabric box; TMNF's thin
  turbo plate rides over an open engine room: the deck's floor (light, the border atlas' orange
  band round its edge) with the deck's underside and truss columns below it, the white fabric box
  in the middle and four jet turbines either side of it hung from two cross beams under the plate
  (measured: axes, intakes, the outline; a grey intake ring, a fan of four dark blades on a grey
  disc). The rim's bevel is TMNF's TURBO sign (our own texture: `texgen/turbo.py turbo_rim`, the
  word every 4 m), the plate's underside ring TMNF's light plates. Material check: TMNF surface we
  lacked 2820 -> 814 m2, colour differs 838 -> 664 m2.
- (M11-2) **Platform checkpoints' arch and ring as TMNF's.** Not white with blue edges: the outer and
  inner faces the border atlas' light panel, the rounded front and back faces the CHECKPOINT band
  (our gate_cp: TMNF's RaceSigns sign there), read along the arc from the front and the back
  (`platform.gd _ring_uv`); the legs under the lips dark truss; the billboard over the arch curved
  and falling with it as TMNF's (measured: its ends 2 m lower and 2.8 m nearer the front than its
  middle). Material check (Checkpoint/Air): colour differs 828 -> 657 m2.
- (M11-2) **The gates' word bands in TMNF's layout** (its RaceSigns, our own drawing and font):
  FINISH white on red between two white lines (was red on white), START green on white under one
  green line, CHECKPOINT blue on dark between two blue lines (`texgen/gates.py KINDS`: lines per
  kind); on the road gates' arch faces and curbs and the platform checkpoints' arch. Side by side
  with TMNF's blocks.
- (M11-2) **Platform decks' open ends and the ramp onto the road as TMNF's.** Where a deck
  continues (and nothing is built next to it) its body's end is TMNF's dark Stands2, not light
  metal; the road ramp off a platform (Platform/ToRoad/ToRoadMainAir) has the ground road's green
  shoulders (TMNF's), not the grid (`road.gd _green_shoulders`). Side by side with TMNF's block.
- (M11-2) **The glass booths (Control/RoadGlass) as TMNF's.** The plinth grey, the walkway and the
  wall under the windows white, a dark sill under TMNF's grey glass (`glass_booth`, not our smoked
  black), a room behind it (its back wall, ceiling and floor, measured), the roof grey along its
  edge and dark beyond; the ground plinths' rail an open railing's top bar (TMNF's railing is
  see-through), on the camera galleries too. Material check (BaseGround): colour differs 756 ->
  184 m2, TMNF surface we lacked 842 -> 396 m2.
- (M11-2) **The pub blocks (Control/RoadPub) as TMNF's.** A straight's screens are two 2:1 boards
  a side (12.2 m each, 0.76 m apart; ours one 26 m board), in a dark frame, under a dark portal at
  each end on the ground; the lone base is TMNF's dark kiosk with a board on each face (it had no
  screens); the plinth TMNF's (16 m wide, grey sides, a dark rubber top with a light strip down
  its middle, a railing's top bar along each edge), the base's running along z as TMNF's; the
  support block its dark Stands2 (`control.gd _pub`, `_pub_plinth`). Material check: TMNF
  surface we lacked 402 -> 218 m2 (straight), 1280 -> 411 m2 (base).
- (M11-2) **Camera lights as TMNF's, take two.** The block between the feet is dark on top and
  underneath (TMNF's Stands2; ours was grey and light: 1,024 m2 a block), the top bar's underside
  light on both sides with the lit strip on its outer bevel (ours had the strip on the left
  underside), and along each outer side TMNF's four floodlight bars at mid height (measured;
  `control.gd LIGHT_BARS`). Side by side with TMNF's block.
- (M11-2) **Sculptures as TMNF's.** Their concrete is TMNF's light grey panels (`sculpt`: our
  stadium concrete, 24 m a tile, (195, 196, 195) when flat; not our bluish tiles), the lofts shade
  smooth across a surface and sharp at its edges (`sculpt.gd SMOOTH_DEG`; they showed every
  facet), and the plinth's double curbs are TMNF's border atlas bands (rows measured), not white
  rubber. Side by side with TMNF's blocks.
- (M11-2) **The road turbo's gantry as TMNF's.** Its booster pods are TMNF's jet turbines now (a
  fan of four dark blades in the intake, the cowl light, the body dark; `TmGeo.fan`, shared with
  the platform turbo's), the walkway's side panels dark see-through (TMNF's railing; ours were
  light-blue glass), and the curbs' face carries TMNF's TURBO sign (our turbo_rim spread over the
  face's rows; `road.gd CURB_ROWS`). Side by side with TMNF's block.
- (M11-2) **Where a dirt road meets the road (Road/Dirt/RoadDirtToRoad), TMNF's curbs.** Ours was
  terrain only; TMNF runs the ground road's curbs along both sides, full up to 17 m, then a
  narrower, lower curb into the dirt's berm (measured; `dirt.gd _to_road_curbs`). Side by side
  with TMNF's block.
- (M11-2) **The dirt checkpoint's bumpers as TMNF's.** Its gate stands on two rounded dark rubber
  bumpers along the sides (the border atlas' black band with its blue line, a ribbed top;
  measured section, z 1.04..30.93; `dirt.gd _gate_bumpers`); ours floated over the berms. Side by
  side with TMNF's block.
- (M11-2) **Grandstand roofs' trusses white as TMNF's.** The lattice between the truss arches'
  chords is white (TMNF's StructureAlpha, its visible texels' mean 203), not dark; the raised
  stands' deck is light underneath (TMNF's Auvent). `material_check.py` now reads TMNF's alpha-cut
  textures (trusses, railings) as they show: the mean of their visible texels per region (it
  counted their transparent black ones too, reading them dark). Side by side with TMNF's block.
- (M11-2) **The airship in TMNF's livery layout, our own names.** Its envelope is UV-mapped now
  (u along it from the nose, v round it; `sculpt.gd _airship`, `_tube`'s uv_of) with our own
  texture (`texgen/stadium.py airship_skin`): white gores, a yellow nose cap and a yellow band
  along each upper flank, SPEEDFEST in black on each side with our emblem in red toward the nose
  (TMNF's has its maker's name there), lettered to read upright from outside on both sides; the
  tail fins red, the gondola white (it was all one beige). Side by side with TMNF's block.
- (M11-2) **Gate feet as TMNF's** (owner: "there is a simple block rectangle connecting the arch
  and the barriers. It looks stupid"). The box between each arch end and the curb is gone; each
  foot is TMNF's now (measured; `road.gd _gate_feet`): two dark clamps round the curb (their outer
  flange thicker, a strap over the curb's top), from each an eight-sided strut up to the arch's
  end, between them a dark see-through lattice with two light rigs aimed at the road. TMNF's
  checkpoints also have a clamp at z 5.8 with a brace up to the sign boards; with the boards
  (option B) they stay out. The dirt checkpoints' gates are TMNF's: the road gate (clamps and all)
  widened 4.5% (the high one narrowed to 0.891) and raised 1.07 m (5.78), 0.963 along z and moved
  0.12 m (`dirt.gd CHECKPOINTS`, `TmGeo.scale_move`), the clamps' straps down on the bumpers; ours
  had a lowered strut and no clamps.
- (M11-2) **Gate blocks' curb signs as TMNF's.** Every gate block (checkpoint, also its slope and
  tilt variants, start, finish, multilap, turbo) carries its sign on both faces of each curb, the
  word every 4 m on a panel with a joint between (TMNF's RaceSigns; ours had the word every 8 m,
  the inner face only, the outer showing our SPEEDFEST band); on the outer face it reads mirrored,
  as TMNF's does. The textures are UV-mapped as the border atlas now (`texgen/gates.py` curb_*,
  16 m a tile, rows spread over the face; `road.gd _entry`, `HALF_GROUND_GATE`). MultiLap says
  MULTILAP in yellow over a chequered strip as TMNF's (arch faces and curbs; it said FINISH; the
  crown screen still shows FINISH, where our lap races end). The dirt bumpers carry the sign the
  same way, the word every 5 m (`bumper_cp`). Side by side with TMNF's blocks: Checkpoint,
  Finish, Start, MultiLap, dirt checkpoint.
- (M11-2) **Review fixes for the gates** (a sequential read-only review of 867ec69, each finding
  checked by a second agent): the dirt gates' crown screen is resized with the gate
  (`TmGateDress.crown` `size`; it stood 0.1 m off the arch's faces, and on the high gate its ends
  above the narrowed arch); the lattice is one face (the translucent material shows both sides;
  two faces made it 92% opaque instead of 72%). The dirt gates' sizes re-measured on five points:
  1.042 wide, 1.075 m up.
- (M11-2) **The platform checkpoint as TMNF's.** TMNF's is the road's gate again, 8.9% wider and
  5.52 m up on the deck (measured: arch, clamps, struts, lattice, light rigs all fit), so ours is
  that now (`platform.gd _checkpoint_arch`; it was the ring's section revolved, light grey, no
  feet). Under the feet each side's edge is set back as TMNF's (`CP_NOTCH`, z 12..20: a dark
  strip along the top behind an orange band, a steeper bevel), elsewhere the rim's bevel carries
  the CHECKPOINT sign, mirrored as TMNF's reads from outside (`_checkpoint_deck`); the billboard
  and its struts stay. The turbo deck's TURBO rim reads mirrored as TMNF's too. Side by side with
  TMNF's blocks. Left: the high dirt checkpoint's side rails and posts (TMNF's; not on our tracks),
  the turbo deck's advert band under the rim, the platform billboard's struts as TMNF's lattice.
- (M11-2) **Grandstands' steel as TMNF's** (owner: "Yes", continue the check; the Fabric pieces
  were the biggest gap left on our tracks: 3,600-4,600 m2 of TMNF's surface missing per piece, 165-225
  uses). TMNF draws its steel as alpha cards; ours now has cut-out cards too
  (`TmMaterials.CUTOUT`: alpha-scissored, both sides, HD or not, both renderers) with our own
  drawings (`texgen/lattice.py`: a white X-braced panel, a dark railing, a dark truss girder, a
  dark grating). Measured from TMNF's blocks (`fabric.gd`): the raised straight's deck now stands
  on TMNF's open base (white tube columns, a beam along the block, a tube ring under the deck with
  posts, X-braced girder panels round the middle column and along the beam, two low catwalks,
  dark floodlight bars on girder frames) instead of a solid wall; both straights get the roof's
  spine (TMNF's V girder: X-braced panels from the light trusses' inner chords at z 12.5 / 19.5
  down to the main truss's), two catwalks under the shell, the floodlight bars at its top edge,
  the railings on the stands' or deck's top; the raised pillar is TMNF's (its wall's tower side
  the framed X panels, the steel tower of seven columns and four X-braced panels, 24 m) instead of
  a wall and a solid post. Missing surface on the four pieces 9,727 -> 4,874 m2 (the rest is
  lattice TMNF draws as flat cards where ours are thin tubes: per-part coverage 80-100%). Side by
  side with TMNF's blocks, Forward+ and Compatibility. Left: the corners' raised base (not on our
  tracks), the ground pillar's orange end strips.
- (M11-2) **Road-side booths as TMNF's** (`control.gd`; 814 and 1,116 uses on our tracks). The
  plinth's open railing under its top bar (TMNF's ControlAuventAlpha: a cut-out card, `_rails`),
  the glass booth's windows TMNF's modules (our drawing, `texgen/booth.py booth_window`: posts, a
  mullion, two transoms, a lit head, see-through panes, 2.2 m each, 36 round the booth; blended,
  `CUTOUT` booth_glass) and its room's wall facing them (`booth_wall`: concrete panels, a dark
  opening into the back rooms), the round booths 32-sided as TMNF's; the round camera booth built
  in arcs (`_camera_base`): TMNF's advert band under the windows either side of +-x (our adverts),
  the light gaps in the window band at +-z, no railing at the entrances. Lattice cards' metal
  lowered (they read light in the sun). Missing surface: camera booth 104 -> 1 m2, glass booth
  389 -> 280 m2. Side by side with TMNF's blocks. Left: the pub block's plinth (85 uses).
- (M11-2) **Platform truss columns and the turbo deck's advert band as TMNF's** (`platform.gd`).
  The truss columns under every closed deck edge are TMNF's dark open frames now (cut-out truss
  cards, TMNF's outline: 1.07 m deep at the foot on the beam's end, 0.55 m under the rim; ours
  were narrow solid boxes); the turbo deck has TMNF's advert band under its plate along each x
  side (our adverts; `TmGeo.screen_rect` takes a lower `min_h` for such bands). Side by side with
  TMNF's blocks.
- (M11-2) **The airship as TMNF's** (`sculpt.gd`, `texgen/stadium.py airship_skin`). Its lofts
  had lost the gondola (one tube left at its back) and the fins (2 m slivers); all built now from
  TMNF's measured outlines: the fins and rudders as slabs (TMNF's colours: top and sides red, the
  bottom fin white with yellow along its leading edge and foot), the gondola's hull lofted through
  14 stations with three windows between white pillars and the red stripe high along it, the dark
  frame up to the envelope, the engine pods (duct, hub, five-blade fan, stub wing), the keel
  girders fore and aft and the four mooring arms (dark cut-out truss cards) with their cables to
  the ground, the tail rounded by one more ring. The livery is laid out as TMNF's in world space
  (each texel placed on the envelope through its rings): the yellow band round it at y 29.6-44.2
  (so the nose and the tail are yellow, as TMNF's), white round the side fins' roots, four
  coloured lights fore and aft, our name and emblem projected flat on each side (reading upright
  from outside), the gores' seams by angle (they zig-zagged where the rings twist), smoother vinyl.
  Side by side with TMNF's block.
- (M11-2) **The pub base and the camera pub as TMNF's** (`control.gd`, `texgen/booth.py`; 48 and
  51 uses on our tracks). The pub base's kiosk is TMNF's: its boards flush in a dark border frame
  with a lip over the gap to the dark box set back 0.6 m behind them (ours stuck out of a solid
  box); the pub plinths get TMNF's cut-out railing under the top bar (round all four sides of the
  base's) and the light rim outside it. The camera pub was a grey rounded block; now TMNF's look
  in our drawing: its long sides a facade (`pub_facade`: light panels, a lamp strip on the rounded
  edge, six dark windows at each end; mapped by rows down the section, split above the windows so
  the air version's taller facade keeps them at TMNF's height), the roof light along its edges and
  dark between, the ends a dark curtain wall (`pub_end`), each side's board in a dark frame
  between two dark posts, an advert band under one end's windows (our adverts), the walkway's
  railing. Missing surface: pub base 409 -> 13 m2, camera pub 190 -> 10 m2. Side by side with
  TMNF's blocks, Forward+ and Compatibility. Left: the other pub forms' layout (TMNF's corner has
  a dark wall with a board and a logo panel on its outer sides; not on our tracks), the camera
  pub's small logo sign and the boards' brackets.
- (M11-2) **The camera lights' steel and spotlights, the platform columns' plates as TMNF's**
  (`control.gd`, `platform.gd`, `texgen/booth.py`, `texgen/lattice.py`). The camera light (87 uses)
  gets TMNF's steel as dark cut-out cards: a W-truss panel over each floodlight bar under a rail,
  two trusses holding them out under the top bar and one across each end, a grating along the
  foot with a railing and a lattice down to the foot; its lamps TMNF's round spotlights (our
  drawing, `spots_nose`: groups of four along the top bar's nose; `spots_bank`: six pairs on each
  bar's face), their lenses alone glowing (`TmMaterials.LENS_GLOW`) where the strips glowed
  white all over. Missing surface 1,304 -> 422 m2 (214 of it TMNF's additive glow cards, left
  out). The platform truss columns' outer and inner faces are TMNF's slotted plates
  (`lattice_plate`: a close grille between two long slots), the open frame only at their sides.
  Look check tool: `tests/block_dump.gd` read every cut-out material as white (it only looked at
  StandardMaterial3D; ours are ORMMaterial3D) and now takes their visible texels' mean; with it the
  76 shapes' colour differences are 10.5% of TMNF's area (13.5% before this round), missing 7.5%
  (11.8%). Side by side with TMNF's blocks, Forward+ and Compatibility. Left: the round base's
  railing ring and panels (not on our tracks).
- (M11-2) **The ground grandstands' orange strips and the pillar's back as TMNF's** (`fabric.gd`;
  FabricStraight1x1 332 uses, FabricPillarGround 390). The quarter-pipe fronts get TMNF's orange
  strips (0.4 m) at both ends and the straight's foot lip its orange top; the stands' ends are
  dark (TMNF's Stands2); the pillar's back is TMNF's: a white wall, its big screen smaller and set
  in a dark frame (ours filled the frame and stood out of the wall), its top edges and back foot
  grey. (TMNF's "floor" in front of these pieces is grass, our terrain's.) Side by side with
  TMNF's blocks.
- (M11-2) **The dirt roads' furniture as TMNF's** (`dirt.gd`, `tools/research/tmnf/dirt_furniture.py`,
  `blocks/data/dirt_furniture.json`, `texgen/stadium.py dirt_bumper`). TMNF's dirt pieces carry
  advert boards on props, low advert bands, kiosks on legs and inflatable logo bumpers with rubber
  ends along the road's edges; ours had none. The research tool measures their placements (board
  corners, bumper centre lines and sizes, the kiosks' leg rings: numbers only) for the 30 furnished
  pieces, and `dirt.gd` builds our own at them: our adverts on both faces of white-framed boards
  with props toward the piece's middle, kiosks with advert faces round a white box over a ring of
  white X-braced leg cards, bumpers as tubes in our logo vinyl (white, our name and emblem on
  both sides) with dark rubber parts (solid, rubber); boards too small for an advert white; what
  TMNF lets overhang the next block (the tilt clips') left out. On our tracks: the GT curves (24 uses; the
  checkpoints keep their gates' own bumpers). The terrain's dirt now follows the survey's cells smoothly
  where it lies level with the grass (they were drawn as grass there; the inner edges of TMNF's
  curves). Side by side with TMNF's pieces.
- (M11-2) **The loops' backs as TMNF's** (`road.gd`; Loop pieces 24 uses on our tracks). The loop's
  section was TMNF's shape already (measured) but its back was plain "structure"; now TMNF's
  materials (unwrapping TMNF's loop into its section frame: grates across the back, the dark spine
  down the middle, a dark rail under each edge) and TMNF's clamps every 22.5 degrees round it (a
  white tube either side of the spine with dark blocks at its ends and middle; `_obox`, an
  oriented box). The mirrored half of the loop's underside took its neighbour segment's material
  (harmless while all were one); fixed. Side by side with TMNF's block.
- (M11-8) **The grandstand roofs' glass band as TMNF's** (`env/tm_stadium_build.gd`,
  `texgen/stadium.py roof_glass`). Probing TMNF's surround (vertical rays through its roof,
  locally) shows its roof glass from ~20 m to ~110 m beyond the field's edge, top and underside,
  the white membrane only behind; ours was membrane all over. The visor and the band up to the
  main roof are now glass (our drawing: dark steel frames every 16 m, mullions every 4 m,
  grey-teal panes, partly see-through; `TmMaterials.CUTOUT` roof_glass, blended): from the field
  the roof's front reads as framed glass against the sky, from above the stands show through.
  The surround's other parts (outer roads, forecourts, parking) were done in session 12; M11-8 done.
- (M11-4) **The circuit base variants as TMNF's** (`circuit.gd`: `_base`, `_bump`, `_hole`, `_pillar`;
  editor pieces, none on our tracks). The bump, hole and pillar bases had no model (null). Built
  from measured numbers (TMNF's local visuals and collision): BumpUp, a 15.5 m round dome rising
  2 m (TMNF's profile, 64 sides, the dark floor) with an orange rubber rim and a blue line round it
  (BumpUp2: the same in the middle of a 1x2 plate); Hole, a 12 x 26 m rounded shaft through the
  plate (orange rim, a dark strip, the atlas' orange and blue band at the top of its walls, dark
  stands below, the dark strip round its opening underneath; on the ground the terrain's grass at
  its bottom, collision only); Pillar1/2/3/5/6/7, a dark rounded pad with the same rim and 1, 2, 3,
  5, 6 or 7 round pillars at TMNF's places: a 24-sided light concrete column with an orange rubber
  collar, a rounded black rubber cap (orange and blue edge), a dark lid with a ring of bolts round
  a boss and two of our advert bands facing either way along x. Rounded corners follow TMNF's
  (radius 1.81 m at the rim's outer edge, 0.8 m less per metre in). The border atlas' rows read as
  TMNF's v runs (up). The 20 shapes agree 100% with TMNF's collision (`test_block_fidelity`);
  colour differs on 4% (our adverts on the pillar bands, the parts hidden in the collar).
- (M11-2) **The glass booth's room as TMNF's** (`control.gd` GLASS_ROOM, GLASS_PARTITIONS,
  `_partitions`; `texgen/booth.py booth_wall`). The road-side glass pavilion is our tracks' most
  used control piece (814). Seen through its glass, ours showed the room's ceiling as a 1.2 m
  flat slab whose sunlit front read as a bright band, and a light concrete back wall; TMNF's
  ceiling is a thin plate rising from the back wall's top (6 m) to the glass's top (7.21 m), its
  back wall reads dark, and the ground pavilion's room is split by four light partitions (two
  across x, a V at each z end). Ours now: the sloping ceiling (GLASS_ROOM takes [y at x0, y at
  x1]), the partitions from TMNF's measured ends, the back wall redrawn dark (two openings into the
  gloom between light columns every 4 m: gallery rails, consoles, our blue cabinet). The colour
  check's missing area on the piece 280 -> 1 m2.
- (M11-2) **The booths' plinth rims, walkways and gallery ends as TMNF's** (`control.gd`,
  `TmMaterials` booth_rim). Sampling TMNF's colours inside its triangles (its vertices sit on
  texel edges): the ground booths' plinth rim is a bluish grey (138 144 150; ours was the grey
  concrete), the camera booth's walkway white like the glass booth's (ours grey), and a gallery's
  section ends dark where the piece stops (ours white; hidden against the next piece). Colour
  differs: camera booth 127 -> 73 m2, camera gallery straight 392 -> 64, glass straight 650 -> 320.
- (M11-2) **The grandstands' wave roofs' membrane as TMNF's** (`texgen/fabric.py fabric_roof`,
  `TmMaterials` fabric_roof, `fabric.gd` SHELL, SHELL_AIR, SHELL_IN_AIR). From outside, TMNF's roof
  reads as white panels pulled taut between clamped ribs (a band every two of its facets, 10.4 m,
  faint seams every 5.3 m along the block); ours read as plain grey concrete. A texture of our own
  in TMNF's layout (its tile 16 m along the block by 10.4 m round the roof): faint stitched seams,
  a bolted rib band across the tile's edges, the membrane between two ribs as a shallow pillow in
  the normal map, a satin sheen; the other fabric (skirts, the circuit wall's top) keeps its own.
- (M11-2) **Where a dirt road meets the road, as TMNF's** (`dirt.gd` TO_ROAD_*, `_sign`;
  `texgen/surfaces.py road_to_dirt`, `texgen/booth.py sign_arrow`; `dirt_furniture.py` signs). TMNF
  lays one image over the transition's asphalt: clean at the road's end, dirt carried on by tyres
  thickening toward the dirt in streaks; ours was clean asphalt. Our own image in that layout (u
  along the piece to the dirt, v from the centre line to the road's edge, mirrored). TMNF also
  stands LED signs on several dirt pieces (it runs arrow videos on them, an advert slot): a display
  on one face (back to back on the waves), a white housing 0.7 m deep, two legs; the research tool
  now records them with the way they face (13 pieces), and ours builds them: our amber LED chevrons
  pointing toward the piece's middle, the white housing, legs down to the terrain.
- (M11-2) **The dirt pieces' border tubes and bumpers' rubber ends** (`dirt.gd _bumper`,
  `dirt_furniture.py`). TMNF lines its dirt waves, diagonals, GT2 hill slopes and tilt-to-road
  corners with short tubes in the border atlas (orange, its blue line underneath; 5-7.5 m, 41 of
  them), and ends its logo bumpers with rubber segments under a second material name the tool
  didn't know (StadiumRaceSignsRubber, on 21 pieces). The tool now measures both (tubes only where
  the part is tube-shaped, 3-12 m long and 0.8-2 m thick; longer runs are curbs' faces), with the
  atlas rows a tube shows; ours builds the tubes in the border atlas round from underneath.
- (M11-2) **The ramp off a platform: the curb's outer underside orange** (`road.gd _entry`). On
  Platform/ToRoad/ToRoadMainAir (38 uses on our tracks) TMNF skins the curb's slanted outer
  underside with the border atlas' orange band and blue line (rows 300-367) where its air roads
  show the black band (ours had the black band there too). Side by side with TMNF's piece.
- (M11-2) **The turbo pads' grating and the road turbo's turbines as TMNF's** (`texgen/turbo.py
  turbo_pad`, `road.gd _turbo_sides`; Road/Main/Turbo 145 uses on our tracks each way). Up close
  TMNF's pad is a grating of dense round bars (~0.2 m apart, ~72 degrees to the road) with a flat
  plate strip at each panel's start, all slanting together, thin grey seams with bolts, the
  arrows painted over bars and plates; ours had sparse soft stripes and wide white seams. Redrawn
  so (our drawing, the layout TMNF's): from the car it reads as TMNF's zigzag of plates between
  the arrows. Its turbines' catwalks now have railings (our cut-out railing cards, solid to the
  car) where we had dark glass panels, and their fans nine dark blades over a dark inside (we had
  four light ones).
- (M11-2) **The sculptures' plinth pads and the snow trees' snow as TMNF's** (`TmMaterials`
  plinth_pad, `inflatable.gd` SNOW_TREE). The sculptures' corner pads are TMNF's white fabric
  (ours were mid grey; their curbs already wear TMNF's rows: the lighter look in its renders is
  its specular). Sampling TMNF's snow tree across its faces by height: the snow lies on each
  tier's slope above its green rim (the first tier's from 1.95 to 2.7 m), not on the rim as ours
  had it; moved there (four tiers, the top cone all snow as before).
- (M11-2) **The turbines' fans and exhaust caps as TMNF's** (`platform.gd _turbine`, `road.gd
  bolt_rings`). The platform turbo deck's turbines get the road turbo's nine dark blades over a
  dark inside, and both kinds of turbine TMNF's exhaust cap: a ring of eight bolts round a boss
  (light rims on the dark cap; we had a plain cap).
- (M11-2) **The road junctions' keel as TMNF's** (`road.gd _junction_keel`). Under a crossing or
  T in the air ours was a flat light plate; TMNF's is the straight road's whole keel section (the
  plates, the dark middle strip, the far plates rising again) revolved round each corner between
  two open arms, straight along a closed side: concentric plates and dark rings round the corners,
  a hollow-sided diamond in the middle (measured: TMNF's height there follows the section by the
  distance from the nearest corner). Built per quarter of the block (its nearest corner is its
  own), each ring clipped to the quarter, the step up to the shoulder, and a dark face where a
  straight quarter meets a revolved one. (The survey listed road blocks by their base form, so
  the junction forms our tracks use had not been in it.)
- (M11-2) **The platform plates' inner corners and undersides as TMNF's** (`platform.gd
  _deck_body`, `_underside`; the plates our tracks lay most: Cross 421, T 492, Corner 272 uses).
  TMNF's T, cross and corner plates are notched at every corner whose two sides both continue:
  the corner square under the deck is open and the plate's lip (rim bevel, underside, white skirt,
  foot) turns round it, so where a platform lane bends (about 300 such corners on our tracks) the
  skirt runs on round the inner corner; ours closed it with a dark wall. Now swept the same way
  (one point, the section's normal turning through the mitre), the bottom plate left open under
  the notch as TMNF's, and the slab's open sides, bottom plate and hub TMNF's dark truss panels
  (Stands2, our stands_dark) where ours were flat. Missing area: cross 191 -> 10 m2, T 96 -> 12,
  corner 56 -> 12; fidelity of the three 99.3-99.8% -> 100%. (Found with a census of the shapes
  our tracks build, weighted by their use: the survey's base forms had missed these.)
- (M11-2) **The platform checkpoint's floodlight banks as TMNF's** (`platform.gd CP_SPOTS`,
  `_checkpoint_spots`; `texgen/booth.py spots_grid`; Platform/Checkpoint 118 uses). TMNF's has
  nine banks a side we didn't build: two back to back on each truss column under the deck aimed
  out, two stacked by the gate's foot and three along the strut aimed at the road. Placed from
  the measurement (centre, facing, long axis), dark boxes with the lamps on one face: our own tile
  of two blocks of two by two round lamps, lit (LENS_GLOW). TMNF's glow cards in front of them
  (additive sprites) stay out: our lamps glow themselves, as on the camera lights.
- (M11-2) **The gate arches' word every 3.08 m as TMNF's** (`road.gd GATE_WORD`, `texgen/gates.py`;
  every road, platform and dirt gate). TMNF's arch faces carry START / CHECKPOINT / FINISH /
  MULTILAP every 3.08 m along the arch (its RaceSigns band, measured from the UVs; 3.34 m on the
  platform checkpoint's larger arch, which ours gets by its scale; the gate curbs every 4 m as
  ours already); ours had one word per 8 m, so a few big words where TMNF shows a row of small
  ones. The texture is now one word a tile, condensed as TMNF's lettering, the arch's length
  fitted to whole words; the ring checkpoint's band every 2.19 m as TMNF's. The crown screen
  stays (owner's option B).
- (M11-2) **The inflatable billboard walls as TMNF's** (`inflatable.gd _banner_wall`,
  `texgen/stadium.py inflatable_banner`; the walls our tracks put outside curves: CornerPillar 72,
  TShapedPillar 36 uses). TMNF's ground pillar pieces are a row of red cushions (four on the
  corner's arc, ours had five) rising from y 2 with a rounded belly, each with a white banner
  printed on it, over a low plinth and rubber strip, a white foot and a dark post at each seam;
  ours were thick red pillow walls from the ground with a white stripe. Now built so from the
  measurement (the belly's profile, the banner's height on the surface, the plinth, feet and
  posts), the banner our emblem and SPEEDFEST where TMNF prints its own logo, reading from the
  bulge side (toward the track; TMNF's logo reads mirrored from there), a plain red skin behind.
  Collision fidelity T 92.1 -> 94.8%, corner 94.2 -> 96.9%. (The stacked pieces above ground,
  not on our tracks, keep the plain cushion walls; the corner has four pillows as TMNF's.)
- (M11-2) **The camera pubs' ends and roof as TMNF's** (`control.gd` PUB tables, `PUB_END_STRIPS`,
  `texgen/booth.py pub_end`; Control/CameraPub 51 uses). TMNF lays its steel panel texture over
  each end, turned so it reads as dark bays between columns, braces above and below a slotted
  girder band, a white strip up each corner; ours were a curtain wall of light-framed panes. Now
  our own drawing of that layout (3 m bays, knee braces, an inverted V below the girder), mapped
  per block as TMNF's (a tile 12 m across from x 4, 6 m down from the roof), with the corner
  strips. The roof's edge strips are TMNF's grey concrete walkways (ours were white).
- (M11-2) **The road pubs' boards outward only, as TMNF's** (`control.gd _pub`, `TmGeo.screen_box`
  `out`). TMNF's road pub shows its adverts on the boards' outer faces; their inner faces (toward
  the support block and the pipe) are its dark steel panels. Ours showed an ad on both faces.
  `screen_box` takes the face to show the ad on (`out`), the other face back_mat.
- (M11-2) **The platform decks' lip in TMNF's atlas rows** (`platform.gd LIP`, `SLOPE_PLATE`,
  `LIP_ORANGE_ROWS`; every platform plate's and slope's closed side). Our lip's rows ran one
  segment behind TMNF's (measured on every platform piece: 161.5, 191.9, 217.4, 244.0, 277.6, 300.2
  down the rim), so its bevel showed the ribbed band where TMNF's shows the black band with its
  light line over the blue one. Now TMNF's rows; the ramp-up piece (ToRoadMainAir) takes TMNF's
  orange band on its bevel (rows 299.2 to 366.8), as TMNF's.
- (M11-2) **An atlas-row audit and the gate arches' surfaces as TMNF's** (`road.gd _gate_shell`,
  `GATE_TOP`, `GATE_UNDER`; `sculpt.gd A_CURB`; `platform.gd CP_NOTCH`; `road.gd _entry`). A scratch
  check (block_dump's per-triangle UVs against TMNF's at the same spot) compares the border-atlas
  row wherever both use the atlas, and lists what ours has where TMNF uses it. Found and fixed:
  the ramp off a platform had its orange rows upside down (TMNF's run 300 at the top to 367 at the
  bottom); the sculptures' plinth curbs' tops are the atlas' light panel (ours ribs); the platform
  checkpoint's notch bevel rows; and every gate arch (road, platform, dirt): TMNF lays the atlas
  across the arch's depth, its top dark with ribbed edges, its underside the light panel between
  ribbed edges, where ours was a flat dark shell with glowing strips in the gate's colour (an
  early addition, before the owner asked for TMNF's look; the gates are told apart by TMNF's word
  bands, and the crown screen stays: option B). Left: the loops' road_metal backs and a 12 m2
  strip (rare pieces), the circuit borders' rubber bands (flat keys where TMNF uses the atlas).
- (M11-2) **The circuit walls' bumpers in TMNF's atlas and outline** (`circuit.gd WALL`,
  `BUMPER_END_Y`; every circuit border, slope wall and curve, 1185 straights on our tracks). TMNF
  lays its border atlas on the wall's foot bumper (the black band over the blue line, rows 298 at
  the foot to 214 at the top) and on the ledge bumper behind (a light bevel, a ribbed flat top,
  the black band down its rounded nose to the blue line); ours were flat dark rubber keys on a
  coarser outline. Now TMNF's rows on both, the ledge bumper on TMNF's measured outline; the
  collision fidelity rose with it (diagonals 97.7 -> 100%, inner corners 98.1 -> 99.0%, curves +0.3-0.6).
- (M11-2) **The road keel's plates and the border atlas' rails as TMNF's** (`texgen/decks.py
  road_keel`, `road.gd HALF_AIR` and `_junction_keel`; `texgen/borders.py`). Under every elevated
  road TMNF's keel shows rows 0-288 of its details texture across each half: a dark bolted strip,
  three long light plates (16 m, joints only at the tile's ends), a dark bolted strip; ours was a
  staggered grey plate pattern. Our own drawing of that layout now, mapped by TMNF's rows (the
  junctions' revolved keel too). And the border atlas' rows 141-215, on curb sides, platform
  lips, the keel's middle strip, the arches and the circuit bumpers, were one uniform rib pattern
  where TMNF's has structure (measured row by row): a grey rail, a black line, a ribbed strip,
  light rails, a perforated grating, a wide rail, two bands of slotted teeth 16 px apart. Redrawn
  so (ours), and the panel band (the curbs' tops) gets TMNF's dark frame and its shading into
  the rail.
- (M11-2) **The decks' plate in 16 m tiles as TMNF's** (`texgen/decks.py platform_plate`,
  `TmMaterials` "platform"; every platform and circuit deck). TMNF tiles its deck plate every 16 m
  (UVs 0-2 over a block, a dark seam at the texture's edge), so each block shows a seam across its
  middle both ways; ours tiled 32 m (seams only at the block edges). The plate is redrawn as a
  16 m tile (the same scratches and smears per m2).
- (M11-2) **The circuit walls' back panel and ledge as TMNF's** (`circuit.gd WALL`, `LEDGE_SEAM`,
  `LEDGE_ROWS`; `texgen/decks.py circuit_ledge`). Above the back's dark screen TMNF stretches a
  slice of its steel texture into dark horizontal bands (ours an X truss): now the atlas' rails and
  grating there. The 8 m ledge behind straight walls maps the top half of TMNF's circuit-border
  texture across it (a dirty white line by the bumper, a bolted seam 1.87 m out, a darker strip at
  the edge, bolted joints every 16 m); ours was a plain blue plate. Our drawing of that layout,
  mapped by TMNF's rows (the curved walls' ledges keep the plain plate).

