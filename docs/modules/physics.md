# Module: physics (car physics, tuning, input, AutoDriver)

Branch: `module/physics`. Owner files only (see the file map). All tests are headless and pass on
all three cars (`game/tests/physics/run_all.sh` prints `PHYSICS_ALL_OK`).

## What it is

An arcade raycast vehicle on `RigidBody3D` (Jolt, 60 Hz), tuned to feel like Trackmania: fast,
grippy, forgiving, with RWD power oversteer and handbrake drifts that you can hold and that settle
by themselves.

| | kaze | brute | veloce |
|---|---|---|---|
| drive | RWD | RWD | AWD |
| mass | 1180 kg | 1480 kg | 1340 kg |
| 0-100 km/h (measured) | 3.08 s | **2.58 s** | 2.87 s |
| top speed (measured) | 282 km/h | 273 km/h | **308 km/h** |
| top speed with nitro | 337 | 347 | 354 |
| braking 100→0 | 28 m | 29 m | 26 m |
| skidpad r=70 (AutoDriver) | 1.26 g | 1.26 g | 1.45 g |
| drift character | easiest | loose, heavy | least drifty |

`Tuning.stats()` estimates match these measurements within ~1.5 km/h and ~0.1 s.

## File map

| file | what |
|---|---|
| `game/cars/car.gd` | `Car` (RigidBody3D): suspension, tires, engine/gearbox, aero, nitro/boost, air control, stability helpers, visual driving |
| `game/cars/physics/car_physics_defs.gd` | `CarPhysicsDefs`: stock params per car, torque-curve shape |
| `game/cars/tuning.gd` | `Tuning`: sliders → params, the shared engine model, the 1D estimator, stats |
| `game/cars/car_input.gd` | `CarInput`: keyboard steering ramp, analog passthrough |
| `game/cars/auto_driver.gd` | `AutoDriver`: path-following bot |
| `game/tests/physics/test_ground.gd` | `PhysicsTestGround`: road strip from a `TrackPath` (trimesh, layer 1), pads, walls, ramps, sample paths (loop, circuit) |
| `game/tests/physics/test_path.gd` | `PhysicsTestPath`: test-only `TrackPath` with fixed loop frames (see integration requests) |
| `game/tests/physics/test_*.gd/.tscn` | tests (below) |
| `game/tests/physics/run_all.sh` | runs everything for every car |

## Model (car.gd)

- **Suspension**: 4 rays (mask 1, back faces too, areas ignored) from 0.30 m above each wheel center
  along −car-up, length 0.30 + 0.20 droop + radius. Spring with preload (static corner weight),
  so the car rests exactly at origin = wheel-center height (ground at `y = -wheel_radius`). Damper
  from velocity along the suspension axis. Progressive bump stop from 8.5 cm (13× rate) with extra
  compression damping. Anti-roll per axle. Each wheel force is capped at 28 corner weights.
  The bump stop stays moderate (6× rate) for explicit-integration stability. Beyond it the body
  bottoms out (see body collision). Supported envelope: loops with r ≥ 18 m at any entry speed up
  to ~270 km/h (≈ 33 g), r = 15 m up to ~200 km/h.
- **Tires**: slip angle `atan2(v_lat, max(|v_long|, 2.5))`, linear to the peak (7–8°), then falls
  to a slide ratio (front 0.86–0.90, rear 0.66–0.80). The lateral force is capped so it never
  overshoots the lateral velocity in one step (no low-speed jitter). Friction circle: drive or brake
  force reduces lateral capacity (`FRICTION_CIRCLE = 0.5`), which gives RWD power oversteer. Drive
  is limited by `traction` × load (wheelspin shows in `get_wheelspin()` and wheel spin visuals).
- **Drift**: the handbrake drops rear grip to 42% (ramp 0.08 s, recovery 0.45 s) and locks the rear.
  *Drift intent* (handbrake, or heavy throttle on RWD while already sliding) keeps the rear loose.
  Without intent, the rear's sliding grip rises above the front's, so slides straighten out by
  themselves. A drift stabilizer bounds the body slip angle around 38° (`DRIFT_MAX_DEG`) and damps
  yaw beyond it, so no endless spins. While drifting with throttle, part of the scrub comes back as
  forward push (`DRIFT_SPEED_KEEP`), so drifts don't kill speed.
- **Engine**: constant-power model with a torque-curve shape (`Tuning.drive_force`): in gear g,
  `F = power / gear_top[g] × shape(u) / norm`. 6 gears, force-optimal automatic shifting with a
  90 ms 35% torque cut and a 0.35 s hold. Rev limiter. Reverse: hold brake when (nearly) stopped,
  up to 47 km/h. Engine braking/coast drag when off throttle.
- **Aero**: drag `c·v²` (calibrated so peak power balances drag at the car's `v_top`), rolling
  resistance, downforce `downforce·v²` while grounded (more load means more grip at speed).
- **Loops / walls**: while ≥ 2 wheels touch road that is steep or inverted, a *stick* force of up to
  13 m/s² pulls along −road-normal (scaled in from 12 m/s). Never applied in the air.
- **Air**: pitch/roll rate damping, auto-levelling after 0.2 s of air (roll → upright, pitch →
  flight direction clamped to −30…+25°), light air steering: steering sets a target yaw rate of
  at most 1 rad/s, which also damps yaw spins in the air. **Touchdown absorber**: on
  landing after > 0.2 s of air, 70% of the impact speed into the ground is removed and pitch/roll
  rates are cut, and for 0.35 s the rebound speed is capped at 0.6 m/s. No bounces, no flips.
- **Body collision**: a floor box over the wheelbase (0.2 m above the ground at rest), raised
  nose/tail boxes (so overhangs don't scrape in tight loops or on ramps) and a cabin box.
  Friction 0, bounce 0, layer 2 / mask 1, CCD on. At extreme loads (> ~20 g) the floor box
  bottoms out on the road and Jolt's contact solver carries the load stably. A 15° wall hit at
  150 km/h keeps ~186 km/h one second later (with throttle).
- **Stability**: roll-rate damping and a righting torque when rolled > 25° relative to the ground.
  Self-righting when resting on the roof or side (< 3 m/s, < 2 wheels) for 1.5 s: a gentle lift and
  rotate.
- **Nitro**: 0..1 tank, drains over `nitro_time`, pushes `nitro_accel` along the ground-projected
  forward axis, refills at 1/28 per second while driving > 8 m/s on ≥ 2 wheels. Nitro also beats the
  rev limiter (raises the top speed by ~50–75 km/h).
- **frozen_controls**: suspension still settles; planar velocity and yaw are zeroed each tick; the
  engine revs freely with throttle; no nitro.
- **teleport()**: sets the transform/velocity immediately and again in the next `_integrate_forces`,
  resets suspension, wheel spin, steering, drift, boost, air/landing timers, gear (best gear for the
  given velocity) and rpm. Works before the car is in the tree.

## Public API (contract) and additions

Contract API as in ARCHITECTURE.md. Notes:
- `controls` keys may be missing; missing keys read as 0/false.
- `get_gear()` returns 0 (N) when stopped without throttle or while frozen, −1 when reversing.
- `visual.set_wheel_state(steer, spin, susp)`: **`steer` is the front wheels' yaw as a
  `rotation.y` value (positive = turning left)**, matching the CarVisual stub. `spin` is the wheel
  rotation angle in radians around the axle (positive = rolling forward). `susp` is the wheel's
  vertical offset from rest in car space (+ = compressed up, droop ≥ −0.2).

Additions (all on `Car`):
```gdscript
signal landed(impact_speed: float)      # touchdown after > 0.25 s air; speed into the ground (m/s). Camera shake / thud
signal wall_hit(strength: float)        # body contact with a wall while grounded; speed lost (m/s). Sparks / sound
var params: Dictionary                  # resolved Tuning.physics_params (read-only use)
var car_id: String
func get_steer_angle() -> float          # applied wheel angle (rad, + = right)
func get_air_time() -> float
func get_wheel_contact(i: int) -> bool
func get_wheelspin() -> float            # 0..1 tire slip intensity: smoke, squeal
func get_slip_angle() -> float           # body slip angle (rad)
func is_boosting() -> bool
func max_steer_at(v: float) -> float     # speed-dependent steering limit (rad)
func get_wheelbase() -> float
func drive_awd_flag() -> bool
```
`Tuning`: `drive_force(p, gear, v)`, `rpm_ratio(p, gear, v)`, `best_gear(p, v, current)`,
`estimate(p)`. `Tuning.stats()` extra keys: `zero_to_200_s`, `nitro_duration_s`,
`nitro_duration` (0..1, long = 1), `accel_raw`, `handling_raw`, `drift_raw`.
**Garage hint:** the `nitro` bar is boost *strength*. Show `nitro_duration_s` next to it, because
the trade-off of the nitro slider is strength vs duration.

`CarInput`: `var enabled`, `var steer_value`.

`AutoDriver`:
```gdscript
signal stuck                          # after stuck_timeout (5 s) without progress
var path: TrackPath
var target_speed_kmh := 0.0           # optional speed cap (<= 0: none)
var enabled := true
var use_nitro := true
var lateral_offset := 0.0             # racing-line offset (bots can vary it)
var grip_margin := 0.72               # fraction of grip it plans corners with
var brake_accel := 9.0
var stuck_timeout := 5.0
var reset_callable: Callable          # called on stuck; if unset it resets itself onto the path (before a loop/jump zone it backs up 60 m)
func get_progress() -> float          # total meters driven along the path (laps accumulate)
func get_distance() -> float          # current distance along the path
func reset_tracking() -> void         # call after teleporting the car (respawn); also auto-detected on > 15 m jumps
```
Race usage: `var ai := AutoDriver.new(); ai.path = track.path; ai.reset_callable = respawn_func; car.add_child(ai)`.
The AutoDriver tracks its position with a local search around the last distance, so it doesn't
jump across loops or bridges. Steering is pure pursuit (speed-scaled look-ahead 8–38 m) with a
tire-slip feed-forward. Inside loops and for 45 m before and through jumps it switches to a
Stanley controller measured in the road frame (heading + lateral error), which works upside down
and gives clean takeoffs. It never steers in the air. It plans speed from horizontal curvature
only (vertical loop curvature is ignored), goes full throttle from 70 m before `loop`/`jump` zones
until their end, uses nitro on straights, has traction control, and reverses out when it's
blocked.

**Real tracks** (tested against `origin/module/tracks` f517266 in a scratch worktree with
`test_real_tracks.tscn`): all 3 cars finish all 3 tracks with 0 respawns. Arena 38–40 s,
downtown 58–60 s, coast 51–56 s. Runs are deterministic (identical times run after run).

## Tuning sliders → params (Tuning.physics_params)

| slider | −1 | +1 |
|---|---|---|
| gearing | limiter −11%, +6% wheel power (0-200 quicker, top −17 km/h) | limiter +11%, −2.5% power (top +9…11 km/h, 0-200 slower) |
| turbo | torque below u=0.86 up (mid-range) | torque above u=0.86 up (top end) |
| downforce | downforce ×0.5, drag −8.5% (top +8) | ×1.5, drag +8.5% (more grip at speed) |
| suspension | spring −22%, damping −0.07, ARB −45%, grip/traction +2.5/5% (accel, drift) | stiffer, more responsive (handling) |
| balance | rear slide +0.10, rear grip +7%, less drift assist (planted) | looser rear (drift) |
| steering | lock −10%, rate −35%, more yaw damping | lock +10%, rate +35% (handling) |
| nitro | accel −35%, duration +45% (more total boost) | accel +35%, duration −45% |

Stats are normalized with fixed ranges (`Tuning.*_RANGE`), fitted over every car with every slider
at −1…+1. `test_tuning` checks 0..1, monotonicity per slider, that every slider is a trade-off, and
that the ranges still fit (it prints the observed ranges for re-fitting).

## Tuning knobs (constants in car.gd)

`SUSP_UP`, `SUSP_DROOP`, `BUMP_START`, `BUMP_MULT`, `BUMP_DAMP`, `MAX_WHEEL_G`, `STICK_ACCEL`,
`AIR_LEVEL`, `AIR_DAMP`, `AIR_STEER`, `LAND_ABSORB`, `LAND_REBOUND_*`, `NITRO_REFILL`,
`DRIFT_MAX_DEG`, `DRIFT_STAB`, `DRIFT_SPEED_KEEP`, `FRICTION_CIRCLE`, `BODY_FRICTION`,
`SHIFT_TIME/CUT/HOLD`. Per-car feel lives in `CarPhysicsDefs.BASE`.

## Tests

```bash
game/tests/physics/run_all.sh        # everything, all cars (~25 s) -> PHYSICS_ALL_OK
tools/run_scene.sh res://tests/physics/test_straight.tscn --headless -- --frames=6000 [--car=id] [--gearing=1 ...]
tools/run_scene.sh res://tests/physics/test_tuning.tscn   --headless -- --frames=10
tools/run_scene.sh res://tests/physics/test_stunts.tscn   --headless -- --car=kaze
tools/run_scene.sh res://tests/physics/test_handling.tscn --headless -- --car=kaze
tools/run_scene.sh res://tests/physics/test_circuit.tscn  --headless -- --car=kaze
# mid-loop screenshot (Forward+; add --compat for the web renderer):
tools/run_scene.sh res://tests/physics/test_stunts.tscn --timeout 900 -- --car=veloce --shotdir=/abs/dir
```
- **test_straight**: rest height = wheel radius, 0-100 in 2.2–4.2 s, top speed 245–330 km/h,
  estimate vs measured (±12 km/h, ±0.45 s), nitro raises top speed, brute quickest launch, veloce
  fastest, braking 100→0 < 45 m. Accepts tuning args to check estimates at extreme settings.
- **test_tuning**: stats in 0..1, monotonic, trade-offs, ranges, determinism, bad input.
- **test_stunts**: AutoDriver through a vertical loop (r = 18 m, 14 m lateral shift) at ~182 km/h,
  at a capped 143 km/h entry and at ~250–270 km/h with nitro: < 10% air ticks (measured 0), upright
  exit, no reset. Kicker jump (10°, ~155 km/h, 8 m peak, 2.2 s air) onto flat ground: lands upright,
  no bounce, keeps speed.
- **test_handling**: handbrake drift at 90 km/h → drift 1.0, held drift with countersteer and
  throttle, recovers to 0 with no input, < 0.9 turns of total yaw. 15° wall hit at 150 km/h keeps
  > 50% speed, upright, no tunnelling. Teleport resets immediately and on the next tick, keeps a
  given velocity. Self-righting from the roof. Frozen hold (< 5 cm drift, engine revs, no nitro).
  Boost pad. Nitro drain/refill/refill_nitro. Skidpad > 1 g.
- **test_real_tracks** (integration, needs the tracks module): AutoDriver full run(s) on
  `--track=arena|downtown|coast`, CPs in order, finish, respawns at the last CP when stuck or below
  `kill_y` (like race). Not in `run_all.sh` because the stub Track is a flat plane.
- **test_input**: CarInput keyboard ramp, self-centering, counter-steer, smaller/slower steering at speed.
- **test_circuit**: AutoDriver, 2 laps on a 1.56 km circuit without walls (hairpin, sweepers,
  banked turn, elevation): never leaves the road, never gets stuck. Laps ~40 s (≈140 km/h average).

## Known issues / notes

- Tuned against my own test geometry and verified on the tracks module's branch (see above).
  Re-run `test_real_tracks` after merging if track geometry changes.
- No physics interpolation: on > 60 Hz displays the car moves at the physics tick rate. See the
  integration requests.
- AutoDriver speed planning ignores banking beyond a small bonus. It is conservative
  (`grip_margin 0.72`); bots could go faster.
- Wheel `spin` for the visuals is integrated per physics tick (not interpolated).

## Integration requests

1. **TrackPath loop frames (tracks / core, `track_path.gd`)**: on a loop with a lateral shift,
   `_bake_frames` snaps the parallel-transported up back to world-up in one 0.5 m step on the
   descending side. Measured on r=18 m with a 14 m shift: a 48.7° twist at y ≈ 5 m, so the road is
   banked 45° and then flat, and a car at 180 km/h gets launched off the crease. Fix
   (`game/tests/physics/test_path.gd` implements and tests it): in steep/inverted sections, lock
   the **right** vector (`right = normalize(R0 - t*(t·R0))`, with `R0` = right when the steep
   section began, `up = right.cross(t)`) instead of transporting up. Already sent to the
   orchestrator.
2. **Physics interpolation (core, `project.godot`)**: consider
   `physics/common/physics_interpolation=true` for smooth motion on 120/144 Hz monitors. The race
   camera would then need to follow the interpolated transform (`get_global_transform_interpolated()`).
   Optional, not needed for tonight.
3. **Race (race module)**: after `car.teleport()` on respawn/restart, call
   `ai.reset_tracking()` when an AutoDriver is attached (it also auto-detects jumps > 15 m).
   Set `ai.reset_callable` to the race's respawn function so a stuck bot respawns at its last
   checkpoint instead of the built-in path reset. Call `car.refill_nitro()` on restart if each run
   should start with a full tank (teleport doesn't refill).
4. **Visuals**: `set_wheel_state` steer convention: `rotation.y` of the front wheels (+ = left).
   Signals `landed`/`wall_hit` and `get_wheelspin()` can drive sparks, smoke and the camera shake.
5. **Audio**: `EngineAudio.set_params(car.get_rpm_ratio(), car.controls.throttle, abs(speed),
   car.get_drift_amount(), car.is_nitro_active(), car.is_grounded())`. `landed` gives the thud
   strength. `get_wheelspin()` is a good extra squeal input.
