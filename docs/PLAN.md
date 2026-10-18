# SpeedFest — Plan & Status

Goal: a Trackmania-like racer with an NFSU2 vibe, eventually on Nintendo Switch / Switch 2.
**First milestone: a web build that the owner and 2–4 friends can play online "tomorrow"
(2026-10-15).**

## Milestones

### M0 — Bootstrap ✅
- [x] Environment: Godot 4.7.2 + export templates, software Vulkan/GL for headless screenshots
- [x] Design questions answered (see TRANSCRIPT)
- [x] Docs: DESIGN, ARCHITECTURE (interfaces), PLAN, PROGRESS, SWITCH, CLAUDE.md
- [x] Godot skeleton: project.godot, autoloads (Settings, Profile, Game, TestHooks implemented;
      Net, Audio stubs), CarDefs, TrackDefs, TrackPath (+ test), stubs for Car/CarVisual/Tuning/Track/Race
- [x] Tooling: import, compile-check, run/screenshot, web export scripts

### M1 — Modules in parallel (each on its own branch, merged into main)
| # | Module | Owns (files/dirs) | Status |
|---|---|---|---|
| 1 | **networking** | `server/**`, `game/autoload/net.gd`, `game/tests/net/**`, `docs/HOSTING.md` | ✅ merged (server tests 10/10, 3-client smoke PASS) |
| 2 | **car physics** | `game/cars/car.gd`, `game/cars/tuning.gd`, `game/cars/car_input.gd`, `game/cars/auto_driver.gd`, `game/cars/physics/**`, `game/tests/physics/**` | ✅ merged |
| 3 | **car visuals** | `game/cars/visual/**`, `game/shaders/car_*.gdshader`, `game/tests/visual/**` | ✅ merged 00:55 (see docs/modules/visuals.md) |
| 4 | **track builder** | `game/tracks/track.gd`, `game/tracks/track_builder.gd`, `game/tracks/defs/**`, `game/tracks/track_path.gd` (refine), `game/shaders/road*.gdshader`, `game/shaders/track_*.gdshader`, `game/tests/tracks/**` | ✅ merged (incl. Trackmania rework) |
| 5 | **scenery & environment** | `game/tracks/scenery/**`, `game/shaders/env_*.gdshader`, `game/tests/scenery/**` | ✅ merged |
| 6a | **ui_menus** | `game/ui/main_menu.*`, `garage.*`, `track_select.*`, `online_lobby.*`, `settings_menu.*`, `game/ui/menu/**`, `game/tests/ui_menus/**` | ✅ merged 00:55 (see docs/modules/ui_menus.md) |
| 6b | **ui_hud** | `game/ui/hud.*`, `pause_menu.*`, `results.*`, `game/ui/hud/**`, `game/shaders/ui_*.gdshader`, `game/tests/ui_hud/**` | ✅ merged 00:55 (see docs/modules/ui_hud.md) |
| 7 | **audio** | `game/audio/**`, `game/autoload/audio_manager.gd`, `tools/audio/**`, `game/tests/audio/**` | ✅ merged 00:55 (see docs/modules/audio.md) |
| 8 | **race** | `game/race/**` (race.gd/tscn, chase camera, remote cars, ghosts, run state machine), `game/tests/race/**` | ✅ merged |
| 9 | **weather** (session 3) | `game/weather/**`, `game/shaders/track_puddle.gdshader`, `game/tests/weather/**`, `tools/audio/gen_weather.py`, `docs/modules/weather.md` | ✅ (DESIGN §4.1) |

Shared/core files (`project.godot`, `autoload/settings.gd`, `profile.gd`, `game.gd`, `test_hooks.gd`,
`cars/car_defs.gd`, `tracks/track_defs.gd`, `ui/ui_theme.gd`, `docs/ARCHITECTURE.md`, `docs/PLAN.md`, `docs/PROGRESS.md`)
are changed only by the integrator. Module agents document themselves in `docs/modules/<key>.md`.

### M2 — Integration ☐
- [x] Merge all module branches. Fix compile errors and API mismatches. (01:00 UTC; modules keep polishing, re-merged as they push)
- [ ] Full flow works: menu → garage → solo race on all 3 tracks → finish → PB.
- [x] Online flow: 3 headless/browser clients join a room, race, and see each other. Results appear.
- [ ] Web export runs in Chromium (Playwright) under the Compatibility renderer at a playable frame rate.
- [x] AutoDriver can finish every track (all checkpoints, loop, jumps). arena 39.6 s, downtown 60.3 s, coast 54.0 s.

### M3 — Review & polish (in progress; see docs/HANDOFF.md)
- [x] **Trackmania-style rework of all 3 tracks** (owner decision 2026-10-15): merged in session 3. Analog bot 9/9 clean; keyboard emulation 13/18 (open: high-speed wall-ride exits / jumps)
- [x] **Weather** (owner request 2026-10-15): dry/rain/storm rounds, stage-designed puddles that cut grip (DESIGN §4.1)
- [ ] Adversarial bug review (networking edge cases, race logic, physics exploits)
- [ ] Visual critique from screenshots of each track and car (Forward+ and Compatibility)
- [ ] Performance pass for web (draw calls, lights, physics)
- [ ] Game-feel tuning (speeds, drift, nitro, camera)

### M4 — Game night release v0.1 ☐
- [ ] `server/public` web build committed
- [ ] `docs/HOSTING.md`: run locally + Cloudflare quick tunnel, or deploy to Render
- [ ] README quick start for friends

### M4.5 — Owner feedback, session 4 (2026-10-15 ~09:20 UTC; do these first, one at a time)
Owner's words in TRANSCRIPT (session 4). Work sequentially, push after each item.
- [x] 1. "On the road it feels bumpy, is it a bug?" **Yes, a bug**: twisting full-width deck quads folded into a
      ±12 cm washboard on bank ramps. Deck now 8 cells across with finer rings where it twists (`test_road_smooth`)
- [x] 2. "Remove a map, no one cares." Removed the HUD minimap (read as the minimap, not a track)
- [x] 3. Checkpoints: much smaller "CHECKPOINT" text (done: only the compact split pop-up now); checkpoints must not look see-through (you
      "fly past it like a ghost"); a better, solid gate design. **Done:** solid light pillars on
      concrete footings with collision, a crossbar with a backlit "CHECKPOINT n/N" sign (crossbar
      collision except near jumps/loops), light strips, and a road light on Forward+ q≥2
- [x] 4. Smaller speedometer/NOS panel (70%). **NOS is a fixed tank per run, not recharged** (strategy):
      kaze 5.5 s, brute 6.5 s, veloce 5.0 s of nitro per run; respawn keeps the tank, restart refills
- [x] 5. No neon futuristic grids: the stadium gets grass (or similar) instead of the neon grid; the
      menu background is static; the online lobby shows every player's car as soon as they join and
      updates live when they change car or style (like Rocket League's lobby). **Done:** mown stadium
      lawn + neutral night-stadium light; static graphite menu backdrop, no auto-spinning car, no neon
      rings; `LobbyLineup` (3D car lineup in the room view, live updates, arrival animation)
- [ ] 6. Remove performance tuning (too complicated). Easy handling that still differs per car.
      **Tuning removed** (garage TUNE tab gone; `Profile.get_config()` always stock). Handling: in progress

### M4.6 — Owner requests, session 4 (~10:25 UTC; sequential, push after each step)
- [ ] Verify the easy-handling + end-stop state, export a safe web build for tonight
- [x] 3. Music: menu = dark trap (Future / Southside / 808 Mafia type beat), one beat per map in the same
      style. Generated by our own scripts (original, royalty-free, listed in ASSETS.md). Done:
      `tools/audio/gen_trap.py`, 5 loops (menu, arena, downtown, coast, generic race), ~2.8 MB
- [x] 2. Two or three short (~10 s) maps on the stadium or coast that use grass, gravel or sand, with
      surface physics (grip, drag, spray) and clever choices (shortcut vs. grip). Done: Infield Rush
      and Dune Dash (~12 s), TrackSurface ground patches, DirtSpray, track select fits 5 cards
      (SPRINT tag), lobby chips use short names
- [x] 1. Neon Downtown rework that uses the buildings: a checkpoint inside a building, wall rides on
      facades, jumping and bouncing off buildings, rooftops
- [x] 4. Export the web build (server/public) and verify it in a browser (session 5; also a static copy on the `web-build` branch)

### M7 — "Unplayable" pass: PC, feel, maps (owner, session 7, 2026-10-15 ~21:10 UTC) ☐
Owner's words in TRANSCRIPT (session 7, last entry). Priority order:
- [ ] 1. **PC first**: native desktop build (Windows + Linux) on Forward+ with real Godot graphics
      (GI, reflections, AO, volumetrics, TAA/upscaling, better materials and lighting). It should
      not look like 2005, and it must run smoothly (frame pacing / physics interpolation, perf
      budget). **Optional RTX**: a path-traced mode when the game runs on NVIDIA's RTX Godot fork,
      plus whatever mainline offers for RTX cards.
- [x] 2. **Handling with Trackmania feel**: research how TM cars behave (grip, steering,
      acceleration, drift, slopes, air, landing, walls) and rebuild the car model to match, with
      measurable targets and tests. Done (sessions 8 + 10, merged into `main`): TM lab 336/336,
      AutoDriver 60/60 analog + 60/60 keyboard. Session 9 reverse engineered TMNF's real model
      (docs/research/tmnf_physics.md, tools/research/tmnf/tmnf_model.py). Open (owner decision):
      port it as a `TM_FAITHFUL` mode with test_tm targets regenerated from the reference model.
- [x] 3. **Barriers**: hits should not ruin a run (glance off and keep going, no snagging, no
      flips). Done (session 8): glancing hits keep the speed and the nose turns along the wall.
- [x] 4. **Wall rides and loops**: full grip on walls and loops, no speed loss or pulling down at
      sensible speeds. Done (session 8; session 10 added a suspension hard stop for fast loops).
- [x] 5. **Rails not magnetic**: the car must not be pulled onto a rail; landing on it is the
      player's job. Done (session 10).
- [ ] 6. **30+ high-quality, distinct maps** in original designs that borrow from the most-played
      TM map styles (TMX). This needs new track pieces and mechanics so maps don't repeat.
Process: research workflow → plan → implement in sequence (physics → barriers/walls/rails → PC
graphics/perf → track pieces → maps in parallel batches) → verify (tests, AutoDriver, screenshots).

### M8 — TMNF: real handling in SpeedFest + the Stadium remake (owner, session 9, 2026-10-16) ☐
Owner's words in TRANSCRIPT (session 9). Answers: assets recreated only (no Nadeo files), tracks =
official campaign + any .Challenge.Gbx read at runtime from the player's own files + our own maps,
SpeedFest gets TMNF handling as the default and its maps are retuned, Godot 4.7 Forward+.
Remake folder: `stadium/` (own Godot project, see stadium/README.md). Work sequentially.
- [x] 1. TMNF car model as engine-independent code: `stadium/core/tm_tuning.gd`,
      `tm_car_model.gd`; lab `stadium/tests/test_model_lab` 44/44 vs `tmnf_model.py`
- [x] 2. Remake: custom 100 Hz car body (sub-steps <= 0.3 m, ellipsoid wheels/chassis, TMNF contact
      impulses, suspension) + a flat test arena, ramps, walls, loop. Done: `car/tm_car.gd` (lab
      `test_car_body` 22/22), drivable `race/drive_test.tscn`, shapes lab 11/11 (kicker, loop, pipe)
- [ ] 3. SpeedFest: TMNF handling as the default on branch `tmnf-physics` (merge after `m7-maps`),
      test_tm targets from the reference model, retune every map, AutoDriver on all tracks, web export.
      **PAUSED: owner approval needed before it goes into SpeedFest** (remake first). State: AutoDriver
      34/34 (1 respawn), suites pass except per-car test_tm items (branch HANDOFF)
- [x] 4. Remake: `.Challenge.Gbx` reader (header + medals, LZO1X body, blocks chunk): `stadium/gbx/`,
      65/65 official campaign tracks read from a TMNF install at runtime (242 block types)
- [x] 5. Remake: recreated Stadium block library (32 x 8 x 32 grid, TMNF-compatible shapes).
      Done: catalogue + placement, map builder/view, Circuit, Tube, Platform (decks, walls incl. GT
      curve walls, loops, slopes, ToRoad, checkpoints incl. ring, sloped and banked), Road/Main
      complete (roads, GT curves at TMNF's segment counts, junctions, gates, slope transitions, tilt,
      GT diagonals from TMNF's frames, holes and pillars, Y junctions), terrain zones + ground,
      Control, Inflatable, Road/Dirt + DirtHigh; every campaign checkpoint built; session 12: circuit
      slope turns, Stretch, turbo gates and variants, ramps, zone clips, loops, diagonal/curved tilt
      transitions: every drivable campaign shape built; Fabric grandstands; every Sculpt piece as
      lofts; the last decorations: **100% of campaign blocks built** (session 12). Polish left:
      inflatable castles, camera light base, bump (see stadium/CLAUDE.md)
- [ ] 6. Remake: stadium environment, our own car model, race flow (countdown, checkpoints, medals,
      ghosts), TMNF-like menus, sounds, HD Forward+ graphics, our own maps.
      Done: race flow (`TmRace`, measured triggers `TmTriggers`, `race/race.tscn` with HUD; all 65
      campaign tracks pass `tests/test_race`); ghosts and best times (`TmGhost`, `TmRecords`, HUD
      record and split differences; session 12); stadium environment (Day sky and sun from the
      mood's numbers, the Stadium around the map from our own measurements; session 12); our own
      car model; menus (main, campaign, options, pause, finish); sounds (synthesized); HD materials (procedural
      surface shaders) (session 12); the owner's list (polish, online with the official server, RTX,
      music, recorded sounds, exports; session 12).
- [x] 7. Remake: **standalone** (owner, 2026-10-17: "I want this to be a standalone game", and
      TMNF's .gbx tracks still loadable): our own tracks `stadium/tracks/*.json` (SF01..SF10) laid
      out by `race/tm_track_builder.gd` from the recreated blocks, `race/tm_tracks.gd`, the driving
      bot `race/tm_bot.gd` that finishes each track and sets its medals (`tests/test_tracks`); menu,
      race and the online server use them by default; TMNF's campaign and .Challenge.Gbx files stay
      as extras. Loops fixed (the bot's eased line and loop steering, a seam contact fix; SF11 Full
      Circle has two). Open: the bot's high-speed weaving (re-medal after), more tracks, a track
      editor
- [x] 9. Quality pass (owner + independent review, session 12): gates, driver, blur, decoration,
      adverts, light, AA, finish run-off and camera, respawn speed, records by layout; then the
      review's rest: tracks across the field (climb/dive, crests), Fabric stands at the start and
      finish, inflatable billboard walls, camera booths, seats in the stands, a result panel
- [x] 8. Release `stadium-v0.1` (2026-10-17): https://github.com/khanhonthetrack/speedfest/releases/tag/stadium-v0.1 (Windows 53 MB and Linux
      44 MB zips, built by CI from the tag)

### M9 — "A 1:1 TMNF replica" (owner, session 13, 2026-10-17) ☐
Owner's words and answers in TRANSCRIPT (session 13). Branch `claude/tmnf-replica-graphics-nb1kcg`
(started from `stadium`; only `stadium/`, `docs/`, `tools/research/`). Rule unchanged: TMNF is
measured locally, our own assets are built to match it, no Nadeo file is committed or shipped.
Work sequentially, push after every step. Research notes go to `docs/research/m9_*.md`.
- [ ] 0. Research (numbers and descriptions only): TMNF's look (materials, gates, adverts, stadium,
      light), menus (screens, flow, layout), online (accounts, ladder, server modes, browser, votes,
      chat), sound (engine layers, gears, cues), campaign style (A-E statistics: lengths, times,
      checkpoints, block families per series)
- [x] 1. Car model: wheels that hold together (tyre, rim seated in the bead, hub, brake), TMNF's
      body from the measured visual mesh proportions, the driver, PBR paint/carbon/rubber
- [ ] 2. Graphics: road/platform/dirt/grass surfaces, start/checkpoint/finish gates, billboards and
      adverts (our own brand art), the stadium (stands with crowd, roof, floodlights), light (TMNF's
      day mood with modern GI/SSR/AO), RTX/Ultra preset; side-by-side checks against local
      reference renders. First pass done (road, gates, adverts, fabric, stadium); open: platform,
      dirt, circuit, tube, control and airship families, light and atmosphere, RTX preset
- [x] 3. Engine and sounds: TMNF's engine behaviour (rpm, gears, layers), skid, turbo, impacts, cues
- [x] 4. Menus: TMNF's structure and flow (Solo / Online / Editors / Profile / Options / Quit,
      campaign A-E tabs with medals), in-race menus. Done (PROGRESS 18 Oct); the EDITORS entry
      lands with steps 5-6, the ladder and rankings in Profile/Online with step 7
- [ ] 5. Replays: save, browse and watch replays (with free and chase cameras)
- [ ] 6. Track Editor: place the recreated blocks on the 32 x 8 x 32 grid, validate by driving
      (author time), save/load/share
- [ ] 7. Online: master server (accounts with password and zone, $-code nicknames, ladder points,
      world/zone rankings, records, server list), dedicated servers (Time Attack, Rounds, Team,
      Laps), server browser, chat, votes, spectators; docker + named Cloudflare tunnel for the Pi
- [ ] 8. Campaign: 65 original tracks A01-E05 (White, Green, Blue, Red, Black) in TMNF's structure,
      difficulty curve and block style; the TMNF-install campaign tabs removed (single
      `.Challenge.Gbx` files still open)

### M6 — Owner requests, session 6 (2026-10-15 ~14:10 UTC; sequential, push after each step)
Owner's words in TRANSCRIPT (session 6): "better graphics, server which rotates maps all the time
instead of having a lobby and waiting for players, more maps (10–30 s), different types of cars.
Keep it fun, and clever." Worked on the Pi (it can push and reach CC0 asset sites).
- [x] 1. **LIVE rotation**: an always-on public room that cycles maps (and weather) round after round.
      Joining drops you straight into the current round; results → next map automatically; no host,
      no ready-up. Private rooms stay as an option. Done: `server/lib/rotation.js`, LIVE room in
      `lobby.js`, `Net.join_live()`, menu "ONLINE · LIVE" + "PRIVATE ROOM", lobby JUMP IN, results
      "NEXT UP"; server 16/16, live_smoke_test 2 clients PASS, net_smoke PASS
- [x] 2. **New maps (10–30 s)**, each built around one clever idea, AutoDriver-finishable, in the
      rotation and the track select. Done: Rooftop Rush, Cliff Hanger, Twister, Pipe Dream (14–20 s);
      side boost pads (`"x"`, `"pw"`); track select is a carousel; LIVE playlist has all 10 tracks
- [x] 3. **New car types** with clearly different handling (and looks): Kitsune R4 (AWD rally
      hatch, rally tires on grass/gravel/sand), Pixie S (kei roadster: most grip, sharpest turn-in),
      Goliath HD (pickup: 2.25 t, biggest nitro). Merged in session 7: engine sounds, stat ranges,
      flat pickup bed, `test_loose`, PHYSICS_ALL_OK with all 6 cars, AutoDriver 30/30 clean
      (3 new cars × 10 tracks)
- [ ] 4. **Better graphics**: CC0 HDRI skies (Poly Haven) and lighting/post polish on both renderers.
      Step 1 done (session 7): photographed skies for all three themes, blended over the procedural
      sky (ASSETS "Sky panoramas"). Open: rain/storm skies, lighting/post polish.
- [ ] 5. Export `server/public`, deploy on the Pi, verify in a browser. Export and browser check
      done (session 7); the Pi deploy (`git pull && docker restart speedfest` on the Pi) is pending.

### M5 — Visual upgrade, beyond web (in progress, owner request 2026-10-15)
Owner: "graphics ... kinda trivial and menu looks very mobiley and boring", so focus on real art
and lighting on mainline Godot plus an NFSU2-style 3D front end (docs/RENDERING.md §3 items 1 and 5).
Path tracing is parked until the owner is at their RTX PC. Three parallel tracks, each on its own branch
(specs: **docs/M5_SPECS.md**). **Paused until M4.5 is done.** The owner said not to run parallel sessions
(work is lost when the usage limit hits), so one agent does these tracks one after another on `main`:
| track | branch | scope |
|---|---|---|
| cars | `visual/cars` | Blender-scripted hero car models (glTF, all customization slots, LODs) behind the unchanged CarVisual API; better paint, glass, chrome, tire and light materials |
| world | `visual/world` | reflection probes + SSR (wet roads), CC0 PBR textures (asphalt, concrete, rock), building facades with depth, HDRI skies, SDFGI/volumetric fog on Ultra, color grade + post FX, quality presets (desktop High/Ultra) |
| frontend | `visual/frontend` | 3D tuner-garage front end: camera stations (main, dyno, paint booth, lift, wheels, neon, online board), NFSU2-style lists and carousels instead of chip grids |
Tools: Blender 5.2 as a Python module (`/opt/bpyenv/bin/python`), CC0 sources ambientCG and Poly Haven
(every asset listed in docs/ASSETS.md). `server/public` (tonight's web build) is not re-exported until
the upgrade is verified on both renderers.

### Later
- **Beyond-web graphics and front end:** see docs/RENDERING.md (path tracing investigation, real
  art assets, Forward+ features, optional RTX mode via the NVIDIA fork, NFSU2-style 3D garage menus)
- Desktop builds with full Forward+ quality
- Track editor, replays and ghost sharing, medals, more cars and tracks
- Switch / Switch 2 port (see `docs/SWITCH.md`)
