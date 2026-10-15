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
- [ ] 3. **New car types** with clearly different handling (and looks): e.g. an AWD rally hatch that
      rules gravel/grass, a light high-grip kart-like car, a heavy torquey truck. **In progress on
      branch `wip/m6-cars`** (Kitsune R4, Pixie S, Goliath HD; written, untested; see HANDOFF)
- [ ] 4. **Better graphics**: CC0 HDRI skies (Poly Haven) and lighting/post polish on both renderers.
- [ ] 5. Export `server/public`, deploy on the Pi, verify in a browser.

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
