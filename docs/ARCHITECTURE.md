# ARCHITECTURE — the contracts between SpeedFest's modules

The game is the former `stadium/` branch grown into a full title: TMNF's car physics underneath, a
procedural night city on top. This document is the source of truth for the interfaces; if you
change one, change it here in the same commit and note it in `docs/PROGRESS.md`.

```
game/
  autoload/   TestHooks, Settings, Garage, Game          (always loaded, in that order)
  core/       TmTuning, TmCarModel, TmBody, MeshKit      (physics + geometry, no scene code)
  cars/       CarDefs, Tuning, TmCar, TmCarInput, TmCamera, CarRig, visual/
  city/       CityKit, CityEnv, Scenery* helpers         (the night city)
  track/      TrackPath, TrackDefs, TrackBuilder         (the circuits)
  race/       Race, main.gd                              (the session and the screen flow)
  ui/         UiTheme, MainMenu, GarageScreen, Hud, PauseOverlay
  gbx/        the .Challenge.Gbx reader (TMNF maps, read at runtime, never committed)
  tests/      headless labs and look-dev scenes
```

## Coordinate conventions
There are two frames, and every bug in this codebase that looked like "the car drives backwards"
came from mixing them up.

| frame | forward | left | origin | used by |
|---|---|---|---|---|
| **car frame** (TMNF) | `+Z` | `+X` | centre of mass | `core/`, `cars/tm_car.gd`, physics |
| **model space** (Godot) | `-Z` | `-X` | wheel-centre height, ground at `y = -radius` | `cars/visual/`, `CarVisual` |

`CarRig` bridges them: it parents the `CarVisual` under a node rotated by `PI` around Y and lifts it
by `wheel_radius - body.rest_height()`.

The **track frame** from `TrackPath.sample_transform(d)` is a third one: `basis.x` = right,
`basis.y` = road normal, `-basis.z` = direction of travel. To put a car on the road at distance `d`:

```gdscript
var t := path.sample_transform(d)
car.place(Transform3D(Basis(-t.basis.x, t.basis.y, -t.basis.z), t.origin))
```

## Autoloads

### `Settings`
Owns the renderer. Forward+ only; `quality` 0..3 (Low, Medium, High, Ultra) scales everything.
- `night_environment() -> Environment` — the house night look, authored at Ultra.
- `tune_environment(env, path_trace := true)` — strips what the current quality cannot afford.
  Call it after you finish configuring an Environment, every time.
- `tune_sun(light)`, `tune_point_light(light, shadows := false)` — shadow and fade settings.
- `light_budget() -> int` — how many real omni/spot lights a scene may light up (24 … 240).
- `local_shadows() -> bool`, `quality_name()`, `render_status() -> String`.
- RTX (NVIDIA's fork only, docs in `old/docs/RTX.md`): `is_rtx_fork()`, `can_path_trace()`,
  `dlss_available()`, `dlss_rr_available()`, `path_tracing_active()`. `tune_environment` turns the
  path tracer on and the screen-space approximations off when it is active.
- Persisted in `user://settings.cfg`; `apply_and_save()` emits `changed`.

### `Garage`
The player's cars. `setups[car_id]` is the Dictionary described in `cars/tuning.gd`;
`owned[car_id][slot]` is the highest level paid for.
- `setup_of(id) -> Dictionary`, `current_setup()`, `specs_of(id)`, `select(id)`.
- `set_level(car_id, slot, level) -> bool` — buys the levels in between; false if too expensive.
- `set_value(car_id, key, value)` — colours and the plate.
- `price_to(car_id, slot, level)`, `owned_level(car_id, slot)`, `can_afford(...)`, `add_credits(n)`.
- `reset_car(id)`, `reset_all()`. Signals: `changed(car_id)`, `credits_changed(credits)`.
- Persisted in `user://garage.json`; **never written while `TestHooks.is_testing()`**.

### `Game`
Session state: `track`, `laps`, `records`, `last_result`.
- `select_track(id)`, `best_lap(track_id, car_id := "")`, `submit_lap(track_id, car_id, ms) -> bool`
  (true on a personal best), `format_time(ms)`, `format_delta(ms)`.
- Persisted in `user://records.json`, under the same test guard.

### `TestHooks`
Command-line hooks: `--shot=`, `--frames=`, `--shots=a.png@60,...`, any `--key=value` through
`TestHooks.arg(key, default)`. Tests call `ok/fail/check/finish`.

## `core/` — physics (do not edit for looks)
`TmTuning` (constants and curves of TMNF's force model 6, tuning `20juin2006`), `TmCarModel` (one
10 ms tick of handling, engine independent), `TmBody` (the integrator, sub-steps, ellipsoid contacts
and impulses). `docs/research/tmnf_physics.md` is the reference; the model lab test guards it.

Per-car scaling lives on `TmCarModel`: `accel_mul`, `launch_mul`, `steer_mul`, `grip_mul`,
`brake_mul`, `slide_grip`, `max_speed`, `surface_override`.

`MeshKit` is the procedural geometry accumulator: `tri/quad/flat_quad/box/prism/cylinder/revolve_x/
grid`, one surface per material key, `commit(materials) -> ArrayMesh`. `mirror_x` builds half a car
and gets the other half free; `color` is the per-vertex tag the car and scenery shaders read.

## `cars/`

### `CarDefs`
`IDS` = `["f4", "kaze", "vector", "polonez", "ridge"]`. Per car: `name`, `archetype`, `blurb`,
`drive`, `body` (`formula` / `coupe` / `gt` / `classic` / `offroad`), `price`, `geometry`, `specs`,
`surface_bonus`, `style`.
- `geometry(id)`, `specs(id)`, `default_style(id)`, `name_of(id)`, `has(id)`.
- `wheel_positions(id, ride_drop)` — car frame, for `TmBody.setup()`.
- `visual_wheel_positions(id)` — model space, for `CarVisual`.
- `body_ellipsoids(id)` — the four chassis ellipsoids, scaled from the car's own box.
- `style_from_setup(id, setup)` / `sanitize_style(id, style)` — the bridge to the model builder.

### `Tuning`
16 slots: `PERF_SLOTS` (engine, turbo, nitrous, tyres, brakes, suspension, gearbox, weight) and
`LOOK_SLOTS` (bodykit, spoiler, rims, paint, vinyl, neon, headlights, tint). `CATALOGUE[slot]` has
`label`, `kind`, `hint`, optional `choice`/`colour`, and `levels` (`name`, `price`, `mul`, `add`).
- `default_setup(id)`, `resolve(id, setup) -> Dictionary` (the numbers the game runs on),
  `ratings(id, setup)` (0..1 per `SPEC_BARS`), `total_price(setup)`,
  `surface_overrides(id, setup)`, `is_choice(slot)`, `level_name/level_price/level_count`.
- Vinyl indices are fixed by `shaders/car_paint.gdshader`'s `livery_mask()`; neon modes by
  `shaders/car_glow.gdshader`. Do not reorder them.

### `TmCar`
The car in the scene (`Node3D`, car frame, 100 Hz through `TmBody`).
- `configure(car_id, setup)` — collision geometry, model multipliers, nitrous.
- `place(xf)`, `speed_kmh()`, `local_velocity()`, `top_speed_kmh()`, `step_tick()`.
- Inputs: `gas`, `brake`, `steer`, `boost_input`, `controls_enabled`.
- Nitrous: `boost_meter` (0..1), `boost_power`, `boost_tank`, `boost_gain`, `boost_kmh`,
  `boosting`; signals `boost_started`, `boost_ended`, `wheel_hit_wall`.

### `AutoDriver`
A path-following driver for a `TmCar` (tests, demos, `--autodrive=1` in the race). Set `car` and
`path`, call `reset_to(d)`, and it fills the controls every physics tick: pure-pursuit steering
toward a look-ahead point, a speed profile baked from the path's curvature (`grip_margin` of the
car's cornering force) and run backwards so it brakes in time, nitrous on the straights. Emits
`stuck` when it stops making progress so the caller can respawn it. `distance` and `laps` track the
lap; `speed_limit_at(d)` exposes the profile.


### `CarRig`
Parents a `CarVisual` to a `TmCar` and syncs it each frame (steering, spin, suspension, brake and
reverse lamps, ground contact, nitrous flames). `rebuild()` after a tuning change.

### `cars/visual/`
`CarShape` (per-car profiles) → `CarBody` (shell + greenhouse) + `CarParts` (lights, grilles, kits,
spoilers, interior) → `CarVisual` (materials, wheels, underglow, plate, flames, headlight spots).
The single-seater skips `CarBody`/`CarParts` and uses `FormulaBody` instead. Material keys:
`paint`, `glass`, `glass_front`, `trim`, `chrome`, `lights`.

## `city/`
`CityKit.new().build(field, seed) -> Node3D` fills everything around a circuit: towers (MultiMesh +
`shaders/env_building.gdshader`), neon signs and vertical boards, billboards
(`shaders/env_screen.gdshader`), street lamps with light pools and cones, overhead gantries,
puddles, a distant skyline, and the real lights inside `Settings.light_budget()`.
`SceneryField.new(path, step)` is the spatial index it (and the race logic) queries:
`query(p, radius) -> clearance`, then `q_index`, `q_dist`, `q_clear`, `q_lat`, `q_y`, `q_d`.
`CityEnv.create()` is the sky, the moon and the fog.

## `track/`
- `TrackPath` — the centreline: `sample_transform(d)`, `sample_position(d)`, `width_at(d)`,
  `closest_distance(p)`, `lateral_offset(p)`, `edge_clearance(p)`, `in_zone(d, kind)`,
  `point_offset(i)`, `length`, `zones`.
- `TrackDefs` — `IDS`, `DEFS` (waypoints, widths, zones, pads, arches, checkpoints, laps),
  `build_path(id) -> TrackPath`, `feature_distance(path, entry)`.
- `TrackBuilder.new().build(id, seed) -> Node3D` with `info`: `path`, `checkpoints` (distances, the
  finish line last), `start` (Transform3D), `length`, `laps`, `name`. It builds the road and its
  collision, curvature-driven curbs, LED barriers, tunnels, light gantries, turbo pads (surface
  `TmTuning.Surface.TURBO2` + `pad_dir` meta) and the start gantry.

## `race/`
`Race` owns a session: it builds the track, the city, the car, the camera and the timing.
Progress is **geometric**: the car's position is projected onto the path through `SceneryField`,
which gives the distance along the lap; checkpoints fire when that distance passes them in order
and a lap when the car wraps the line. Signals: `checkpoint_passed(index, ms)`,
`lap_done(lap, ms, best)`, `race_done(total_ms)`. `respawn()`, `restart()`, `progress_ratio()`.
`race/main.gd` is the entry point: menu → garage → race, one screen at a time.

## `ui/`
`UiTheme` (palette, fonts, panels, buttons, bars, backdrop), `MainMenu`, `GarageScreen` (the car on
a `SubViewport` turntable), `Hud` (speed, nitrous, splits, lap map), `PauseOverlay`.
A `Control` screen whose parent is a plain `Node` sizes itself to the viewport (`_fill_viewport`).

## Tests
`tools/test_all.sh` runs every `game/tests/test_*.tscn`:
| test | what it guards |
|---|---|
| `test_model_lab` | the TMNF force model against the reference numbers |
| `test_car_body`, `test_car_shapes` | the body integrator and the per-car shapes |
| `test_gbx` | the `.Challenge.Gbx` reader |
| `test_settings` | the night look, the quality gates, the light budget, the RTX path staying off |
| `test_tuning` | the catalogue, prices, credits, surfaces and styles |
| `test_race` | circuit shape, the grid slot, checkpoint order, laps, nitrous, respawn, a real drive |
| `test_autodrive` | every circuit is lapped by the bot with three different cars |
| `test_flow` | menu -> garage -> race wiring, installing parts, pausing, restarting |

Look-dev scenes (`showroom`, `track_tour`) are not tests and are skipped by the runner.
