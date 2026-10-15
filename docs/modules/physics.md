# Module: physics (car physics, tuning, input, AutoDriver)

## Handoff (2026-10-15)

**State (branch `module/physics`, all pushed; `game/tests/physics/run_all.sh` → PHYSICS_ALL_OK):**
- Car: arcade raycast vehicle. Warp-tolerant suspension (droop-soft springs, anti-roll bars on
  average roll), roll damping relative to the road's twist, stick force on steep/inverted road,
  touchdown absorber, roof/side drag + self-righting, boost clamps (≤ 60 m/s², ≤ 4 s, fade
  360→420 km/h, 450 km/h hard cap).
- Wall rides: `test_wallride` (R 55/70/220, entry 142–215 km/h) has 0 air ticks for all cars.
- Jumps: 10–20° kickers at 150–230 km/h (≤ 4.5 s air) land upright with no bounce.
- AutoDriver: pure pursuit plus slip feed-forward; Stanley (road frame) in loops, ±40 m around wall
  rides and 45 m before jumps; banked-curve speed planning; full throttle 70 m before loops and jumps;
  never steers in the air; stuck → `reset_callable`; `reset()`/`reset_tracking()`.

**Envelope sent to tracks:** wall ride roll ≤ 85–90°, entry 140–215 km/h, full-roll radius
≥ 55 m, roll ramp ≥ 80–100 m (smoothstep, peak twist ≤ ~1.2°/m), horizontal curvature following
the roll (κ ≈ sin(roll)/R), linear tilt interpolation in TrackPath (the stock `_tilt_at`
smoothsteps per segment). Loops r ≥ 18 m up to ~270 km/h. Boost pads yellow 22/1.4 and red
34/2.2 are fine. Leave room after a red boost before a loop or wall ride.

**Open issues:**
1. Tracks part 2 (de1b225): the analog AutoDriver is 9/9 clean. Keyboard emulation is 4/9 clean.
   Failures: arena brute flips at the wall-ride entry (~264 km/h, full curvature at roll 0); jumps
   on arena (d≈899, 1348) and downtown (d≈1166); downtown boost before the loop (d≈678); coast
   d≈1088 and its loop (1156–1304). The main cause is the wall-ride geometry
   (`{"wallride", r 70, roll 75, ramp 62}` in all three defs), which is outside the envelope.
   Fixes requested from tracks.
2. Keyboard steering on walls above ~190 km/h is imprecise even inside the envelope (test_wallride
   `--keyboard`). A "cancel lateral gravity" assist was tried and reverted: it breaks banked balance.
3. TrackPath fixes (loop right-vector lock, linear tilt) live only in my test subclass
   `tests/physics/test_path.gd`.

**Next steps:** when tracks pushes new layouts, make a scratch worktree from origin/module/tracks,
merge module/physics, run `game/tests/physics/run_real_tracks.sh` (3 cars × 3 tracks, analog and
keyboard; it prints respawn locations with zone names), and report to tracks. If keyboard
respawns stay at wall rides that are inside the envelope, look at CarInput steering rates at
200+ km/h.

**Verify:** `tools/godot_import.sh && tools/check_scripts.sh` (SCRIPT_ERRORS=0),
`game/tests/physics/run_all.sh` (PHYSICS_ALL_OK), and with the real tracks merged,
`game/tests/physics/run_real_tracks.sh`.


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
- All scenario tests accept `--tune=min|max` (every slider at −1/+1) or `--<slider>=v`.
  `run_all.sh` also runs stunts/handling/circuit at both extremes, and test_straight confirms the
  estimator at the extremes (within 0.12 s and 1.5 km/h).
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

## Real tracks through race.tscn (module/physics with origin/module/tracks + race merged in)

`tools/run_scene.sh res://race/race.tscn --headless -- --frames=5400 --track=<id> --autodrive`
(kaze, default config): **arena 39.63 s** (second run 39.90 s), **downtown 60.30 s**,
**coast 53.95 s**. Every checkpoint in order, finish, no respawns. `AutoDriver.reset()` exists
(an alias of `reset_tracking()`) for race.gd between runs.

## Integrated check (scratch merge of all module branches, not pushed)

`race.tscn --track=arena --autodrive` with the real tracks, visuals, scenery, HUD and audio
renders correctly: the car sits on the road at the right height and the wheels line up. The visuals
module's `set_wheel_state` conventions match (steer = `rotation.y`, spin + = forward roll, offset + =
compressed). The race module has also verified its state machine and online rounds against this branch.
Per-tick cost of `Car._integrate_forces`: ~70 µs on desktop (AutoDriver ~80 µs when used).

## Known issues / notes

- Tuned against my own test geometry and verified on the tracks module's branch (see above).
  Re-run `test_real_tracks` after merging if track geometry changes.
- No physics interpolation: on > 60 Hz displays the car moves at the physics tick rate. See the
  integration requests.
- AutoDriver speed planning ignores banking beyond a small bonus. It is conservative
  (`grip_margin 0.72`); bots could go faster.
- Wheel `spin` for the visuals is integrated per physics tick (not interpolated).


## M3 rework support (Trackmania-style tracks)

Supported piece envelope (all 3 cars, 0 air ticks in tests). Sent to the tracks session:

| piece | limits |
|---|---|
| wall ride | roll ≤ 85–90°, entry 140–215 km/h (≈ 250 on the wall), full-roll radius ≥ 55 m, roll ramp ≥ 100 m smoothstep (peak twist ≤ ~1.2°/m), horizontal curvature κ(s) ≈ sin(roll(s))/R, linear tilt interpolation |
| loop | r ≥ 18 m up to ~270 km/h entry (r = 15 m up to ~200) |
| gap jump | kickers 10–20° at 150–230 km/h, up to 4.5 s of air / 25 m drops, land upright with no bounce even on flat ground |
| boost pads | `apply_boost` clamps accel ≤ 60 m/s², duration ≤ 4 s, pushes along the road plane, fades 360→420 km/h; hard cap 450 km/h (2.1 m/tick, below the 4 m gate depth; CCD for walls) |

Physics changes for it:
- **Warp-tolerant suspension**: on a twisting road the front and rear axles sit at different roll
  angles (twist × wheelbase). Springs are droop-soft (`DROOP_SOFT` = 0.45× rate while extending,
  same static height), and the anti-roll bars act on the average roll of both axles, so they resist
  body roll but not warp. Without this, diagonal wheels unloaded and the car got launched on
  wall-ride entries and exits.
- **Roll damping relative to the road's twist rate** (smoothed, `ROLL_DAMP`, `TWIST_SMOOTH`) plus a
  gentle `ROAD_ALIGN` torque, so the car follows wall-ride twists instead of resisting them.
- **apply_boost**: clamps and fade above. A stronger pad overrides a weaker one, and a weaker pad
  touched during a strong boost doesn't cut it short.
- **AutoDriver speed planning** uses the banked-curve limit
  v² = g/κ·(sinθ + μ cosθ)/(cosθ − μ sinθ), with world-horizontal curvature κ, bank θ toward the
  turn's center and μ including downforce. Steep wall-ride sections are unlimited (full throttle);
  low-roll entries get a sane speed. In `wallride` zones (±40 m) it steers with Stanley in the
  road frame.
- **Roof/side drag** (`ROOF_DRAG` 9 m/s²): a flipped car sliding on its frictionless body slows
  down, stops and self-rights. Before this it could slide off a deck at 100 km/h on its roof.

Real tracks, rework part 2 (tracks de1b225 + module/physics), `run_real_tracks.sh`:
analog AutoDriver 9/9 with 0 respawns (arena 32–37 s, downtown 25–27 s, coast 31–33 s).
Keyboard emulation 4/9 clean. The rest has 1–2 respawns, mostly at the wall rides, whose
geometry (62 m ramp, full horizontal curvature from roll 0) is outside the envelope; reported to
tracks.

Tests: `test_wallride.tscn` (`--car`, `--roll`, `--ramp`, `--tight_r`, `--fastcap`; four variants:
R 70 at 142 and 215 km/h entry, R 220 at 150, R 55 at 142), superboost and boost-into-wall cases
in `test_handling`, and jump variants `--jump_angle`, `--jump_nitro`, `--jump_zone` in `test_stunts`.

TrackPath notes for tracks (my tests override these in `test_path.gd`): lock the right vector
through steep sections (loop frame twist), and interpolate tilt linearly between control points.
The stock `_tilt_at` smoothsteps inside every segment, which makes dense tilt points a washboard.

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

## Handling feel pass (integrator, 2026-10-15, owner feedback)
Owner: *"the car handling is weird. Sometimes when i hit the barriers i flip out. i can't drift by
using back and left/right arrow at the same time. Jumping physics looks very fake"*
- **Barrier hits never flip the car.** While a side contact is active (+0.35 s), the velocity into
  the wall is removed (tiny bounce) and the roll/pitch rate is cut to 15% (`WALL_SPIN_KEEP`). The yaw
  rate is capped (`WALL_YAW_MAX`), and any upward "pop" from the hit is cancelled. Barrier collision tops
  now slope down toward the road (track_builder), so a car landing on one slides back onto the
  track instead of resting on an invisible ledge.
- **Brake drift:** brake + steer above ~50 km/h (keyboard: Down + Left/Right) breaks the rear loose
  (`BRAKE_DRIFT_REAR_GRIP`). The brakes keep only 30% of their force while sliding, and the slide
  carries on throttle via the drift assist. Bots (AutoDriver) switch it off with `brake_drift_enabled`;
  the keyboard-emulation test keeps it on (`emulate_player`).
- **Jumps:**
  - Air steering is a nudge (0.3 rad/s), not a spin.
  - +35% gravity while airborne (`AIR_GRAVITY_EXTRA`) makes arcs punchier and less floaty.
  - The nose partly follows the flight path, then lines up with the landing surface (downward probe),
    so landings are wheels-first.
  - Touchdown absorb is 0.45 (was 0.7), so the suspension visibly squashes.
- Test: `tests/physics/test_feel.tscn` covers 3 cars × wall hits at 150/250 km/h and 12/25/45°,
  with and without steering away, plus brake drift and air spin (84 checks). `tests/physics/jump_view.tscn`
  gives side-view frames and a per-frame trace of a real track jump (`--trace_from/--trace_to`).

## Session 4 fixes to the handling-feel pass
- Barrier anti-spin (`WALL_SPIN_KEEP`) is skipped while self-righting (`_righting > 0`), and a body
  contact whose normal is within ~45° of world-up never counts as a wall when fewer than 2 wheels touch.
- `AIR_GRAVITY_EXTRA` applies only when `speed > 15 m/s` and `_takeoff_up_y > 0.8` (the last ground
  normal's world-up component while ≥ 2 wheels touched): jumps get punchier arcs, wall-ride and loop
  lift-offs and spawn drops don't. Wall-ride exits above ~240 km/h remain marginal (chaotic in tests).

## Easy handling (session 4, owner: "Make handling easy, but different for different cars")
Baseline (`tests/physics/test_easy.tscn`, real key presses through CarInput): the brute snapped to
43 deg of slip on a 200 km/h flick (1.5 s to settle) and kaze slid 43 deg in a slalom, because on RWD
cars full throttle plus any slide over ~7 deg counted as drift intent and dropped rear grip. Keyboard
players are always at full throttle, so every small slide snapped.
- **Drift intent** now comes from the handbrake and brake-drift (the player asks), plus a mild per-car
  `power_oversteer` (kaze 0.4, brute 0.25, veloce 0) that only starts once a slide is well under way
  (`_drift > 0.35`).
- **Stability assist** (`STAB_YAW` × `params.yaw_damp`: kaze 1.0, brute 1.2, veloce 1.3; `yaw_damp`
  was unused before): when the body slip angle is beyond 2.5 deg and still growing, damp its growth.
  Scaled by `1 - _intent` (never fights a requested slide) and by "hands off" (`1 - 1.5·|steer|`: gone
  at 2/3 lock, so it never fights a driver or the AutoDriver steering). Off on steep road (loops,
  wall rides) and while the car rolls faster than ~0.3 rad/s with the road (wall-ride entries/exits).
  Earlier variants that damped all yaw (or measured against the per-wheel ground normal) made cars run
  wide at wall-ride exits and lose loops; the real-track matrix caught it.
- brute `rear_grip_bias` 0.97 → 1.0 (neutral).
- Result: flick slip 7–12 deg and settles in 0.2–0.4 s for all cars; slalom slip ≤ 13 deg; brake drift
  still slides 32–40 deg (test_feel).
- Track side (track_builder): deck rings inside loops are 1 m wherever the ring falls (`LOOP_RING`);
  a loop half-covered by a chunk used 1.5 m rings, and at 260+ km/h the body hit a deck fold edge.
