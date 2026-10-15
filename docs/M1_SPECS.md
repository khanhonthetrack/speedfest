# M1 module specs (relaunch, 2026-10-15)

Written by orchestrator #2 when it took over. Every module agent gets the **common rules** plus its
own section. The interface contracts in `docs/ARCHITECTURE.md` are the source of truth. These specs
add requirements and acceptance criteria on top of them.

Deadline: the owner plays online with 2–4 friends **tonight (2026-10-15, European evening)** in
desktop browsers with keyboards. Ship working, tested code first, then polish.

---

## Common rules (all modules)

### Setup in a fresh container
```bash
# Godot 4.7.2 (downloads.godotengine.org may be blocked; the GitHub mirror works)
mkdir -p /opt/godot && cd /opt/godot
curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
python3 -I -c "import zipfile;zipfile.ZipFile('godot.zip').extractall('.')"
chmod +x Godot_v4.7.2-stable_linux.x86_64 && ln -sf /opt/godot/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
apt-get update && apt-get install -y mesa-vulkan-drivers   # software Vulkan: Forward+ screenshots under Xvfb
cd <repo> && tools/godot_import.sh && tools/check_scripts.sh   # must print SCRIPT_ERRORS=0
```
Export templates are only needed for the web export (integrator).

### Working rules
- Read `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/DESIGN.md` first.
- **Only create or edit files your module owns** (see your section and the ownership table in
  `docs/PLAN.md`). Other modules are written **in parallel right now**. Their files are stubs
  that already have the final API. Code against the contract in ARCHITECTURE.md, never against
  stub internals (e.g. the stub Car is a sliding box and the stub Track is a flat plane).
- Need a change in a file you don't own (autoloads, `CarDefs`, `TrackDefs`, `project.godot`,
  `UITheme`, ARCHITECTURE.md)? Don't edit it. Write the exact change under **Integration requests**
  in your module doc. Work around it locally in the meantime.
- You may **add** public functions, signals and properties beyond the contract. Never remove
  or rename contracted ones. Document additions in your module doc.
- Don't edit `docs/PROGRESS.md`, `docs/PLAN.md` or `docs/ARCHITECTURE.md` (the integrator merges them).
  Write `docs/modules/<key>.md` instead: what you built, file map, how to test, API additions,
  tuning knobs, known issues, integration requests.
- GDScript with static typing, tabs. Geometry and materials are procedural (in code). No binary
  assets except generated audio (audio module).
- Must work on **Forward+** (desktop and console) and **Compatibility** (web, WebGL2). Branch on
  `Settings.is_compat()`, `Settings.quality`, `Settings.light_budget()`, `Settings.local_shadows()`.
  Compatibility has no SSR/SSAO/SDFGI/volumetric fog, GPUParticles are limited (prefer
  CPUParticles3D on compat), and each omni/spot light costs an extra pass per lit object.
- Web performance budget (whole race scene, compat, quality 1–2): about 60 fps on a mid laptop iGPU,
  under ~400 draw calls, under ~600k triangles visible, at most `Settings.light_budget()` dynamic
  lights. Use MultiMesh for repeated props. Merge static geometry by material.
- After adding a new `class_name`, run `tools/godot_import.sh` so the class gets registered.
- Tests go in `game/tests/<key>/` and print `TEST_OK`/`TEST_FAIL` through `TestHooks`, then call
  `TestHooks.finish()`. Run logic tests with `--headless`. For visual work, take screenshots with
  `tools/run_scene.sh ... -- --frames=N --shot=/abs/path.png` on **both** renderers (`--compat`).
  **Look at them with the Read tool** and iterate until they look good. Visual quality matters
  ("focus on beautiful graphics" — owner).
- Work on branch **`module/<key>`** (`git checkout -b module/<key>` before the first commit) and
  push only that branch (`git push -u origin module/<key>`). Never push to `main` or to the
  orchestrator's integration branch `ccr-49301774-b5a4ns`. Commit often (`<key>: <what>`). No PRs.
- Finish with a final push and a last message that summarizes: branch, what works, tests and
  their results, known issues, integration requests.

---

## physics — car physics (`key: physics`)

**Owns:** `game/cars/car.gd`, `game/cars/tuning.gd`, `game/cars/car_input.gd`,
`game/cars/auto_driver.gd`, `game/cars/physics/**`, `game/tests/physics/**`, `docs/modules/physics.md`.

Build an **arcade raycast vehicle** on `RigidBody3D` (Jolt, 60 Hz) that feels like Trackmania:
fast, grippy, stable, forgiving, fun to drift.
- 4 suspension raycasts (mask 1) at `CarDefs.wheel_positions()`. Spring and damper with bump stops,
  anti-roll. Ground is at `y = -wheel_radius` at rest (car origin = wheel-center height).
- Tire model: lateral grip from slip (with a curve that lets the rear break away under handbrake
  or with `balance` > 0), longitudinal drive and brake, rolling resistance. RWD for kaze/brute,
  AWD for veloce (`CarDefs.get_def(id).drive`).
- Engine: torque curve, 6 gears + reverse, automatic gearbox, rpm (0..1 ratio). Brake key reverses
  when nearly stopped.
- Speeds, stock: top speed about 250–320 km/h depending on car (veloce highest), 0–100 km/h in
  ~2.5–4 s (brute quickest off the line). Strong speed-dependent downforce and grip so 200+ km/h
  corners are drivable.
- **Nitro**: amount 0..1, drains while held and refills slowly while driving (or via
  `refill_nitro()`). Gives a strong forward push and raises the top speed. The `nitro` tuning slider
  trades a long, gentle boost for a short, strong one.
- **Loops**: a car entering a vertical loop (radius 15–25 m) at ≥ 140 km/h must go around without
  falling off. Use suspension that survives ~6–9 g plus extra "stick" downforce along the road
  normal while grounded at speed. Never fight gravity in the air.
- **Air**: on jumps, slight auto-levelling (pitch/roll damping toward upright) and light air steering
  so landings are clean. Landings must not bounce or flip the car.
- **Walls**: low-friction collision shape (box/capsule set) on layer 2, mask 1. Scraping a wall
  slides along it instead of stopping dead. Use continuous collision detection at high speed.
- Stability: anti-flip assist, and self-righting if the car rests upside down for > 1.5 s (gentle).
- `frozen_controls`: hold the car in place (countdown). `teleport()` fully resets dynamics
  (velocity, angular velocity, suspension state, wheel spin).
  `apply_boost(direction, accel, duration)` is used by boost pads.
- Drive the visual every frame: `visual.set_wheel_state(steer_rad, spin[4], susp_offsets[4])`,
  `set_lights(braking, reversing)`, `set_nitro(active)`.
- `get_flags()` and `get_net_state()` per ARCHITECTURE.md (drifting = drift_amount > 0.35).
- **Tuning** (`Tuning.physics_params`, `Tuning.stats`): deterministic mapping of the 7 sliders to
  physics params (DESIGN §3.1), with trade-offs and no strictly better settings. `stats()` values
  are normalized 0..1 across all cars and settings, and `top_speed_kmh`/`zero_to_100_s` are realistic
  estimates (ideally measured once per car offline and fitted, not guessed).
- **CarInput**: keyboard steering ramp that depends on speed (slower and smaller steering at high
  speed), self-centering, analog gamepad passthrough.
- **AutoDriver** (tests, bots, `--autodrive`): follows a `TrackPath` with speed-scaled look-ahead.
  Target speed comes from upcoming curvature. Full throttle in `loop` and `jump` zones. Optional nitro
  on straights. Recovers when stuck (reverse and re-align) and resets itself through a
  callable/signal after 5 s without progress (`signal stuck`). Must be good enough to finish real
  tracks.
- **Tests** (`game/tests/physics/`): build your own test ground with a small helper that turns a
  `TrackPath` into a road strip with trimesh collision (do NOT depend on the tracks module). It needs
  a long straight, a flat circle pad, a ramp jump, a vertical loop (r ≈ 18 m) and a wall. Check:
  0–100 km/h time and top speed per car are in range, braking 100→0 < 45 m, handbrake on the pad
  produces drift > 0.4 without spinning out forever, the AutoDriver completes the loop upright, the
  jump lands upright, the wall slide keeps > 50% speed at a 15° hit, teleport resets, and stats are
  monotonic per slider. Also take a Forward+ screenshot of a car mid-loop for sanity.

## visuals — car visuals (`key: visuals`)

**Owns:** `game/cars/visual/**`, `game/shaders/car_*.gdshader`, `game/tests/visual/**`, `docs/modules/visuals.md`.

Procedural, good-looking cars that read well at speed and up close in the garage.
- Three **distinct, original** bodies built from `CarDefs` geometry (length, width, height,
  wheelbase, track widths, wheel radius, ground clearance) following the origin convention:
  - `kaze`: JDM tuner coupe (wedge nose, pop-up-headlight era, notchback, boxy flares).
  - `brute`: American muscle (long hood, fastback roof, wide rear hips, big grille).
  - `veloce`: Euro mid-engine supercar (very low wedge, cab-forward, big side intakes, wide rear).
- Technique: loft cross-sections along the length with `SurfaceTool`/`ArrayMesh` (smooth normals,
  sharp creases where needed), separate surfaces for paint, glass (tint), trim/black plastic, lights
  (emissive), and chrome. Wheel arches cut or flared so the wheels sit correctly. Add a grille,
  mirrors and exhaust tips.
- **Parts** (`CarDefs.PART_COUNTS`): hood 4 (+ `hood_carbon`: carbon-weave material), front bumper 3,
  rear bumper 3, skirts 3, spoiler 5 (none, lip, ducktail, GT wing, high wing), rims 5 designs with
  `rim_color`, visible brake discs and calipers (`caliper`), tires with sidewall detail.
- **Paint** (`car_paint.gdshader`, both renderers): finishes gloss, metallic (flake), pearl (fresnel
  color shift), matte, chrome; **livery** with the `accent` color (racing_stripes, side_stripe,
  two_tone, fade, checker) in car-local coordinates; `tint` on the glass.
- **Lights**: emissive headlights (`headlight` color) and taillights (brighter when braking), reverse
  lights. Add real SpotLights for headlights only on request (`set_headlights_real(on)`, used for the
  local car) and only within the light budget.
- **Underglow**: color plus `underglow_mode` (off/static/pulse/strobe/rainbow), an emissive ground blob
  (additive quad/decal under the car) plus at most one OmniLight (skip the light on compat at low
  quality). `set_underglow_enabled(on)`.
- **Nitro**: exhaust flames and a blue plume. CPUParticles3D on compat, GPUParticles3D on Forward+.
- `set_ghost(alpha)`: whole car translucent (PB ghost, near-camera fade). Switch materials to alpha
  and keep it cheap.
- `ride_height` (−1 slammed .. +1 raised) moves the body relative to the wheels.
  `plate`: readable plate text (Label3D or a small SubViewport texture).
- Performance: ≤ ~25k triangles per car and ≤ ~12 draw calls (merge static parts per material),
  because up to 8 cars are on screen on web. `apply_style()` only rebuilds what changed (paint →
  material params only).
- **Tests/showcase**: `res://tests/visual/showcase.tscn` (args `--car=kaze|brute|veloce|all`,
  `--angle=front|rear|side|three_quarter`, `--style=default|alt|max`) on a reflective dark floor with
  nice lighting. Screenshot all cars, several angles, and part variants on both renderers. Critique
  your own screenshots honestly (proportions, wheel fit, silhouettes, materials) and iterate. Add a
  headless test that builds every part combination without errors and checks triangle counts.

## tracks — track builder and layouts (`key: tracks`)

**Owns:** `game/tracks/track.gd`, `game/tracks/track_builder.gd`, `game/tracks/defs/**`,
`game/tracks/track_path.gd` (refine, keep its tested API), `game/shaders/road*.gdshader`,
`game/shaders/track_*.gdshader`, `game/tests/tracks/**`, `docs/modules/tracks.md`.

- `Track.build(track_id)` loads the layout from `res://tracks/defs/<id>.gd` (control points with
  tilt/banking, width profile, zones, checkpoint distances, boost pads, supports) and builds:
  - the road mesh along `TrackPath` frames (asphalt + curbs + lane markings + edge lines in a road
    shader that works on both renderers; wet look for `downtown`), plus trimesh collision on layer 1;
  - walls and barriers with collision where the track can be left (neon-edged barriers in the arena,
    concrete and guardrails in the city and on the coast), open edges only where intended;
  - **checkpoint gates** (Area3D, layer 3, mask 2, spanning the full road width and ~6 m high) with
    neon arch visuals; a start/finish gate. Emit `checkpoint_reached(car, index)` and
    `finish_reached(car)` for any `Car` body. Race enforces the order;
  - **boost pads** (Area3D, calls `car.apply_boost(forward, accel, duration)`) with an animated chevron
    shader;
  - stunt pieces: vertical **loop** (radius ≥ 18 m, works with `TrackPath` tilt/frames), **jump** ramps
    with a gap (the landing must be reachable at expected speed: do the ballistic math), **banked**
    180°, **tunnel** (enclosed with lights), **bridge** and **elevated highway** with supports;
  - zones on `path.zones` ("loop", "jump", "tunnel", "bridge", "boost", "no_props") so scenery
    avoids them.
- Then add `SceneryKit.build_environment(theme)` and `SceneryKit.build_props(theme, path, seed)`
  (the scenery module implements those in parallel; the stubs are fine for now).
- `get_start_transform()`: on the centerline at the start line, origin **0.6 m above the road
  surface**, facing the direction of travel (−Z forward). `get_checkpoint_transform(i)` is the same at
  checkpoint `i` (−1 = start). `kill_y` sits well below the lowest road point.
  `get_minimap_points()` is the XZ centerline.
- **Layouts** (DESIGN §4), with wide roads (12–18 m), readable turns and no dead ends:
  - `downtown` "Neon Downtown": a ~2 km circuit through a city grid (smoothed 90° corners, a
    chicane), an elevated highway section with on/off ramps, and a tunnel. 4–6 checkpoints. ~60 s.
  - `arena` "Pulse Arena": a ~1.3–1.6 km stunt circuit with boost pads, a vertical loop, a gap jump,
    a banked 180° and a final jump over the start area. 4–5 checkpoints. ~45 s.
  - `coast` "Sunset Coast": a ~3 km point-to-point sprint with elevation, fast sweepers, a rock tunnel
    and a bridge over a bay. 5–6 checkpoints, finish gate at the end. ~60 s.
  Assume an average speed of ~150 km/h when sizing.
- Performance: chunk the road mesh (e.g. 100–200 m pieces) for frustum culling. Merge walls per
  chunk.
- **Tests** (`game/tests/tracks/`): headless build of each track. Check path length in range, circuit
  closure continuity, no unintended self-intersections (only at bridges), the start transform is
  0.6 m above the road (raycast), every gate spans the road, and a probe body moved along the path
  triggers all checkpoints in order and then the finish. Check loop radius and ramp/landing geometry.
  Screenshots: a high overview plus 3–4 driver-eye views per track on both renderers. Make them
  look great; iterate.

## scenery — environments and props (`key: scenery`)

**Owns:** `game/tracks/scenery/**`, `game/shaders/env_*.gdshader`, `game/tests/scenery/**`, `docs/modules/scenery.md`.

- `SceneryKit.build_environment(theme)` returns WorldEnvironment + key light + sky + fog, tuned with
  `Settings.tune_environment()` and `Settings.tune_sun()`:
  - `city`: rainy night. Dark blue-violet sky with a city glow on the horizon, wet look (high
    specular, SSR on Forward+), fog, bloom, and optionally rain particles around the camera
    (`build_rain()` helper for race to attach to the camera).
  - `arena`: night stadium. Purple/cyan haze, strong bloom, floodlight feel.
  - `coast`: dusk. Procedural sunset sky (sky shader: gradient, sun disk, clouds), warm low sun,
    a sea plane with an animated wave shader, distant islands/mountain silhouettes.
- `SceneryKit.build_props(theme, path, rng_seed)`, all placed relative to `path` with
  `path.edge_clearance(p) > 2` (except intentional overhead gantries and tunnel walls), skipping
  `no_props`/`tunnel`/`loop` zones as appropriate:
  - `city`: skyscrapers and blocks (MultiMesh boxes with a window shader of lit and unlit windows),
    original neon signs (made-up brands and "SPEEDFEST"), street lamps, billboards, overhead gantries,
    puddle decals.
  - `arena`: stands with a crowd shader, floodlight towers, giant screens, neon arches and pylons,
    sponsor banners (made-up names).
  - `coast`: procedural palms, rocks/cliffs, guardrail posts, a lighthouse, distant town lights, the sea.
- Lights: at most `Settings.light_budget()` dynamic lights in total. Fake most light with emissive
  materials and bloom. Shadows only when `Settings.local_shadows()`.
- Performance: MultiMeshInstance3D for repeats, visibility ranges (HLOD-like) for far props, few
  materials.
- **Tests**: `res://tests/scenery/scenery_demo.tscn --theme=city|arena|coast` builds a sample closed
  `TrackPath` (with a simple road strip of your own) plus environment and props, with cameras at
  driver height and overview. Screenshots on both renderers. Print draw calls and object counts
  (`Performance` monitors). Iterate until each theme looks beautiful and distinct.

## ui_menus — menus, garage, lobby (`key: ui_menus`)

**Owns:** `game/ui/main_menu.*`, `game/ui/garage.*`, `game/ui/track_select.*`,
`game/ui/online_lobby.*`, `game/ui/settings_menu.*`, `game/ui/menu/**`, `game/tests/ui_menus/**`,
`docs/modules/ui_menus.md`. Uses core `UITheme` (`game/ui/ui_theme.gd`, don't edit; request changes).

All screens are keyboard-, gamepad- and mouse-navigable (focus neighbours, `ui_accept`/`ui_cancel`
for back). They scale with the window (anchors/containers, 1280×720 to 2560×1440). Plays
`Audio.play_ui("hover"/"click"/"back"/"confirm")`. Scene paths come from `Game.SCENE_*`.
- **Main menu**: an animated NFSU2-flavoured backdrop (a slowly orbiting 3D `CarVisual` of the selected
  car on a neon turntable or a stylish shader backdrop), the SPEEDFEST logo, and buttons: Solo Time
  Attack → track select, Online → lobby, Garage, Settings, Quit (hidden on web). Ask for the player
  name on first run (`Profile.set_player_name`). Plays menu music (`Audio.play_music("menu")`).
- **Track select** (solo): 3 cards (name, theme, blurb, target time, your PB from
  `Profile.get_pb`), then start with `Game.start_solo(id)`.
- **Garage**: a 3D preview of the car (`CarVisual` with an orbit camera, mouse drag and auto-rotate,
  nice lighting) and car selection (3 cars with name, archetype, blurb). Tabs:
  - Performance: the 7 sliders (`CarDefs.TUNING_LABELS`, −1..1, step 0.1), live stat bars from
    `Tuning.stats()`, top speed (km/h or mph per `Settings.units_mph`) and 0–100 time, and "Reset".
  - Paint: paint color, finish, accent color, livery. Body: hood (+ carbon), front, rear, skirts,
    spoiler. Wheels: rims, rim color, caliper color. Lights: underglow color and mode, headlight
    color, window tint. Stance: ride height. Plate: text (`CarDefs.sanitize_plate`).
  - Colors use curated neon/street preset swatches plus a ColorPicker popup.
  - Every change updates the preview immediately (`CarVisual.apply_style`) and is stored with
    `Profile.set_tuning`/`set_style`/`set_selected_car`. Back → `Game.leave_garage()`.
- **Online lobby**: connect (server URL from `Settings.resolve_server_url()`, editable), player
  name, connection status and ping (`Net.ping_ms`). A room list with refresh, create room, and join
  by code. The room view shows players (name, car name, ready, best), host settings (track and round
  duration from `TrackDefs.DURATIONS_S`), ready toggle, Start (host only), chat, leave, and a Garage
  button (`Game.to_garage(Game.SCENE_LOBBY)`). Show `Net.net_error` messages. **On
  `Net.round_started(info)` call `Game.start_online_round(info)`** (AutoPilot relies on that). On entry,
  if already in a room (returning from a race or the garage), show the room view right away.
- **Settings menu**: quality, render scale, vsync, fullscreen (not web), show FPS, PB ghost, units,
  camera mode, master/music/sfx volume, server URL. Apply live (`Settings.apply()`), save on exit.
- **Tests**: a screenshot of every screen on both renderers. Headless logic tests: garage changes
  persist to `Profile`, and the lobby reacts to faked Net signals (emit them directly). Optional: a
  lobby smoke test against the real server (`server/`, `npm install && PORT=… node server.js`).

## ui_hud — HUD, pause, results (`key: ui_hud`)

**Owns:** `game/ui/hud.gd`, `game/ui/hud.tscn`, `game/ui/pause_menu.*`, `game/ui/results.*`,
`game/ui/hud/**`, `game/shaders/ui_*.gdshader`, `game/tests/ui_hud/**`, `docs/modules/ui_hud.md`.
Uses core `UITheme` (don't edit; request changes).

- **HUD** (`CanvasLayer`), the full contract API in ARCHITECTURE.md "HUD", styled per DESIGN §7:
  - bottom-right: tachometer arc (custom `_draw` or a shader) with a redline, digital speed,
    unit, gear (R/N/1–6), and a nitro bar that glows while active;
  - top-center: run time (Orbitron, tabular digits), checkpoint counter, split pop-ups (blue faster
    / red slower, +/− delta), round time left (online, turns amber or red in the last 30 s);
  - top-right: live leaderboard (rank, name, best, my row highlighted). Compact top 5; holding the
    `leaderboard` action expands it to everyone;
  - center: countdown 3-2-1-GO (big, animated), "CHECKPOINT", "FINISH", "NEW PB!" banners, and
    `show_message` toasts;
  - bottom-left: minimap (`set_minimap` points scaled to fit and oriented, local car and other cars
    as dots);
  - a speed-lines overlay (ui shader) above ~200 km/h, only when `Settings.quality >= 2`.
  - Optional FPS counter (`Settings.show_fps`).
  Animations use Tweens. Never allocate per frame in setters (they're called every frame).
- **Pause menu** (`CanvasLayer`, `process_mode = ALWAYS`): Resume, Restart run, Settings (volume
  sliders and camera mode inline), and Quit (to lobby when online, else to menu). Signals `resumed`,
  `restart_requested`, `quit_requested`; methods `open()`, `close()`. In online mode the game doesn't
  pause the tree (say so in a hint).
- **Results** (`CanvasLayer`): `show_results(results, my_id)` shows a ranked table (medal colors for
  the top 3, DNF last, my row highlighted, best time, runs, car name) and a "back to lobby" hint or
  countdown. Animated entrance.
- **Tests**: `res://tests/ui_hud/hud_demo.tscn` feeds fake data (speed sweep, splits, countdown,
  leaderboard with 6 players, minimap of a sample oval). Screenshots at several moments on both
  renderers, at 1280×720 and 1920×1080. Also screenshot pause and results.

## audio — sound and music (`key: audio`)

**Owns:** `game/audio/**`, `game/autoload/audio_manager.gd`, `tools/audio/**`, `game/tests/audio/**`,
`docs/modules/audio.md`.

- All sounds are **synthesized by our own scripts**: Python with numpy (available) in
  `tools/audio/`, written as Ogg Vorbis (ffmpeg is available) to `game/audio/generated/`. Commit
  the generator scripts, the `.ogg` files and their `.import` files. Total size ≤ ~4 MB (the web
  download). Loops must be seamless (set loop points in the import or use AudioStreamOggVorbis.loop).
- **Engine** per car, 2–4 loopable layers (e.g. low, mid and high rpm, on/off throttle) crossfaded
  and pitch-shifted by rpm: kaze is a high rotary buzz, brute a lumpy V8 rumble, veloce a flat-plane
  V12 scream. Plus a turbo whistle and blow-off (on throttle lift at high rpm), a nitro whoosh, tire
  squeal (by drift amount), wind (by speed), and a landing thud (on a grounded transition).
- `EngineAudio` (Node3D): for the local car, non-positional players with full layers; for remote
  cars, AudioStreamPlayer3D with fewer layers and distance attenuation. `set_params()` smooths its
  inputs. Cheap enough for 8 cars.
- `Audio` autoload: `play_ui` (click, hover, back, confirm, error), `play_sfx` (checkpoint,
  finish, pb, countdown, go, respawn, plus boost, wall_hit), `play_music("menu"|"race")` with a
  crossfade, and `stop_music()`. Use the buses `Settings.BUS_MUSIC`/`Settings.BUS_SFX`. Small player
  pools, no allocation spam.
- **Music**: two original synthwave loops (menu ~60–90 s, race ~60–90 s, punchier): drums, bass,
  pads, arpeggio, side-chain feel. Tasteful, not harsh.
- Web: Godot starts audio after the first user gesture. Make sure nothing breaks before that.
- **Tests**: a headless test that loads every stream, checks loop flags and lengths, and exercises
  `EngineAudio` through an rpm sweep and every `Audio` call. Also render the engine and music
  samples to PNG spectrograms or waveforms (optional) to sanity-check them visually.

## race — race scene and Time Attack logic (`key: race`)

**Owns:** `game/race/**` (race.gd/tscn, chase camera, remote cars, ghosts, run state machine),
`game/tests/race/**`, `docs/modules/race.md`.

Implement ARCHITECTURE.md "Race" fully:
- `race.gd`: build the Track (`Track.build(Game.track_id)`), the local Car (`Car.create(Profile.get_config())`)
  with a `CarInput` child (or an `AutoDriver` child when launched with `--autodrive`; then it also
  auto-restarts after a finish), `ChaseCamera`, HUD (`res://ui/hud.tscn`), pause menu
  (`res://ui/pause_menu.tscn`), results (`res://ui/results.tscn`), and an `EngineAudio` per car
  (`Audio.play_music("race")`).
- **State machine**: COUNTDOWN (car frozen, 3-2-1-GO with `Audio.play_sfx("countdown"/"go")`) →
  RUNNING → FINISHED (show the time for 2.5 s) → COUNTDOWN (a 1.5 s restart hold) …
  Run time = physics ticks × 1000/60 ms. Checkpoints must be passed **in order**: ignore wrong or
  duplicate gates, and only accept the finish after all checkpoints. On a checkpoint, record the
  split, compare it with the PB splits (stored alongside the ghost), call `hud.show_split`, store a
  respawn snapshot (transform + velocity) and call `Net.send_checkpoint`. On finish, call
  `Profile.submit_time` and `Net.send_finish`, and save the ghost and splits on a PB. Respawn
  (`respawn` action, or automatically below `track.kill_y` or upside down and stuck) teleports to the
  last checkpoint with its velocity, keeping the clock running. Restart (`restart` action) starts a
  new run.
- **Online**: the first countdown syncs to `Game.round_info.start_at_local_ms` (late joiners start
  their first run right away). Call `Net.send_state(car.get_net_state() + {"t": run_ms})` every
  physics tick. HUD round time left comes from `round_info.end_at_local_ms`. When the round ends
  (`Net.round_ended`), stop the run, show the results overlay, and return to the lobby when
  `Net.room_changed` reports phase "lobby" (`Game.to_lobby()`). Live leaderboard from
  `Net.leaderboard_changed`. Remote cars come from `Net.player_state`/`player_left`.
  Pause doesn't stop the tree online.
- **ChaseCamera** (`chase_camera.gd`): modes chase-near, chase-far, bumper and hood
  (`camera_cycle`, saved to `Settings.camera_mode`), `look_back`. Spring lag, FOV widening with
  speed plus a nitro kick, subtle shake at very high speed and on landings, and an up vector that
  follows the car smoothly so **loops look right**. A camera collision raycast keeps it from
  clipping into walls.
- **RemoteCar** (`remote_car.gd`): interpolates snapshots ~100 ms in the past (use the `rx_ms` that
  Net adds, or the snapshot `t`), drives a `CarVisual` (config from `Net.get_player(id).car`, run
  through `CarDefs.sanitize_config`), wheel steer and spin from the snapshot, lights and nitro from
  the flags. It shows a name tag (`Label3D`, billboard, fixed size), fades near the camera
  (`set_ghost`), extrapolates briefly on packet loss, and hides after 3 s of silence.
- **Ghosts**: `GhostRecorder` and `GhostPlayer` with 20 Hz samples `{t, p, q, st, fl}`.
  Save with `Profile.save_ghost` on a PB and play the PB ghost translucent (`Settings.show_pb_ghost`).
- Minimap: `hud.set_minimap(track.get_minimap_points())` and `set_minimap_cars` every frame.
- Pause: the `pause` action opens the pause menu (solo pauses the tree). Restart and quit go
  through the signals.
- **Tests** (`game/tests/race/`): the real Car, Track and HUD are stubs while you work. Write a tiny
  **test track** of your own (a `Track` subclass or a duck-typed node with the same API: a short
  straight `TrackPath`, Area3D gates and signals) and drive the state machine by teleporting the car
  through the gates. Check countdown → running, CP order enforcement, splits, finish, the PB saved,
  respawn and restart. Test the remote-car interpolation with synthetic snapshots. Run one online
  round end to end headless: the server from `server/` plus two clients using
  `--auto_online=host|guest --autodrive` (see `game/autoload/auto_pilot.gd` and
  `tools/net_smoke_test.sh`). Take a screenshot of the race scene on both renderers.
