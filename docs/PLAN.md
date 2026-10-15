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
| 2 | **car physics** | `game/cars/car.gd`, `game/cars/tuning.gd`, `game/cars/car_input.gd`, `game/cars/auto_driver.gd`, `game/cars/physics/**`, `game/tests/physics/**` | ☐ |
| 3 | **car visuals** | `game/cars/visual/**`, `game/shaders/car_*.gdshader`, `game/tests/visual/**` | ☐ |
| 4 | **track builder** | `game/tracks/track.gd`, `game/tracks/track_builder.gd`, `game/tracks/defs/**`, `game/tracks/track_path.gd` (refine), `game/shaders/road*.gdshader`, `game/shaders/track_*.gdshader`, `game/tests/tracks/**` | ☐ |
| 5 | **scenery & environment** | `game/tracks/scenery/**`, `game/shaders/env_*.gdshader`, `game/tests/scenery/**` | ☐ |
| 6a | **ui_menus** | `game/ui/main_menu.*`, `garage.*`, `track_select.*`, `online_lobby.*`, `settings_menu.*`, `game/ui/menu/**`, `game/tests/ui_menus/**` | ☐ |
| 6b | **ui_hud** | `game/ui/hud.*`, `pause_menu.*`, `results.*`, `game/ui/hud/**`, `game/shaders/ui_*.gdshader`, `game/tests/ui_hud/**` | ☐ |
| 7 | **audio** | `game/audio/**`, `game/autoload/audio_manager.gd`, `tools/audio/**`, `game/tests/audio/**` | ☐ |
| 8 | **race** | `game/race/**` (race.gd/tscn, chase camera, remote cars, ghosts, run state machine), `game/tests/race/**` | ☐ |

Shared/core files (`project.godot`, `autoload/settings.gd`, `profile.gd`, `game.gd`, `test_hooks.gd`,
`cars/car_defs.gd`, `tracks/track_defs.gd`, `ui/ui_theme.gd`, `docs/ARCHITECTURE.md`, `docs/PLAN.md`, `docs/PROGRESS.md`)
are changed only by the integrator. Module agents document themselves in `docs/modules/<key>.md`.

### M2 — Integration ☐
- [ ] Merge all module branches. Fix compile errors and API mismatches.
- [ ] Full flow works: menu → garage → solo race on all 3 tracks → finish → PB.
- [ ] Online flow: 3 headless/browser clients join a room, race, and see each other. Results appear.
- [ ] Web export runs in Chromium (Playwright) under the Compatibility renderer at a playable frame rate.
- [ ] AutoDriver can finish every track (all checkpoints, loop, jumps).

### M3 — Review & polish ☐
- [ ] Adversarial bug review (networking edge cases, race logic, physics exploits)
- [ ] Visual critique from screenshots of each track and car (Forward+ and Compatibility)
- [ ] Performance pass for web (draw calls, lights, physics)
- [ ] Game-feel tuning (speeds, drift, nitro, camera)

### M4 — Game night release v0.1 ☐
- [ ] `server/public` web build committed
- [ ] `docs/HOSTING.md`: run locally + Cloudflare quick tunnel, or deploy to Render
- [ ] README quick start for friends

### Later
- Desktop builds with full Forward+ quality
- Track editor, replays and ghost sharing, medals, more cars and tracks
- Switch / Switch 2 port (see `docs/SWITCH.md`)
