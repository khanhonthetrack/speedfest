# M7 physics: why it has "no feel", the Trackmania target, and the rewrite plan

Owner (session 7): "The physics is horrible. There is no feel ... learn or copy from Trackmania how
the car behaves", "The barriers are super annoying", "The wall rides are terrible. It slows you
down, pulls you down. These cars don't have any grip?", "Rails should not be magnetic".

## 1. Diagnosis of the current model (game/cars/car.gd, 1008 lines, before M7)

The car is a sim-style raycast vehicle with a slip-angle tire model, then a stack of assists
that try to make it drivable:

| Mechanism | Where | Effect on feel |
|---|---|---|
| Slip-angle lateral tire curve + breakaway (`slip_peak`, `front_slide`/`rear_slide`) and a friction circle | `_integrate_forces`, tire loop (~l.640-760) | The car only turns by sliding: 13-19 deg body slip in an ordinary full-lock turn (baseline below). Grip feels vague, the car "floats" |
| Stability assist (`STAB_YAW`, yaw damping on slip growth, only "hands off") | ~l.800 | Fights the player when they straighten; adds lag |
| Drift stabilizer (`DRIFT_MAX_DEG`, `DRIFT_STAB`) | ~l.780 | Second controller on top of the tires |
| Drift speed keeping (`DRIFT_SPEED_KEEP`), power oversteer, brake-drift blend, handbrake blend, drift assist | ~l.590-770 | Five overlapping drift systems; behaviour depends on hidden state |
| "Stick" force on steep road only (`STICK_ACCEL` 13 m/s^2, ramps in 12-27 m/s) | aero block | Wall rides/loops depend on a special case; the tire model still has to fight gravity sideways through slip, so the car slides down the wall (8 m in the lab) and scrubs speed |
| Keyboard steering smoothed twice: CarInput ramps 5.5/s -> 2.4/s and caps lock at 72% at speed, then the car rate-limits again (`5 * steer_speed` rad/s) | car_input.gd, car.gd steering | ~0.4 s to full lock at speed; 0.55 s to settle on release |
| Air: nose follows the flight path (`AIR_PITCH_FOLLOW`), auto-level, extra gravity only for some take-offs | air block | Mostly fine; the extra gravity is conditional |
| Barriers: velocity into the wall removed x1.05, yaw capped, roll/pitch killed | barrier block | Doesn't flip, but the car doesn't turn along the wall: after a 15 deg graze it bounces off at 6-7 m/s with the nose still 19-20 deg off the wall, so it hits the other side or bounces back in |
| Engine | Tuning.drive_force | 0-100 km/h 3.1 s, 0-200 km/h 8.9 s (kaze): sluggish next to TM |

## 2. Trackmania behaviour we target

Public, numeric data on TM physics is scarce (no official docs, community wikis blocked from here),
so the spec below is the well-known qualitative behaviour of the TM Stadium car turned into numbers
that we choose and measure. Values marked (ours) are design choices, not measured TM values.

- **Steering is direct**: the car yaws the moment you steer and stops yawing the moment you let go.
  No understeer at full lock: the maximum steer angle shrinks with speed so full lock sits just
  inside the grip limit. No spins on tarmac without a deliberate drift.
- **Grip, not slide**: on road the car goes where it points; the rear doesn't step out on its own.
- **Speed retention**: cornering on grip costs very little speed; drifting (brake tap + steer) turns
  tighter and costs some speed.
- **Walls and loops hold through speed, not magnets**: adhesion = road-normal gravity + cornering
  (centripetal) load + downforce (grows with v^2). A fast car stays on a curved wall with full grip;
  a slow one falls off. Nothing pulls a car onto a surface it isn't on.
- **Jumps are snappy**: effective gravity in the air ~1.3-1.5 g (ours: 1.35 g, as before), flat
  landings keep the speed.
- **Barriers are forgiving**: a glancing hit glances off along the wall and keeps most of the speed,
  the nose turns along the wall; a head-on hit stops you; nothing flips or pops up.
- **Deterministic and assist-free**: the same inputs give the same run; no hidden helpers fighting
  the player.

## 3. Target spec and the lab (game/tests/physics/test_tm.gd)

| Behaviour | Target (ours) | Test id |
|---|---|---|
| 0-100 km/h, flat, full throttle | <= 2.4 s | tm_accel_100 |
| 0-200 km/h | <= 7.5 s | tm_accel_200 |
| Turn-in at 150 km/h: time to 90% of steady yaw rate | <= 0.2 s | tm_response_turn_in |
| Release: yaw rate below 10% | <= 0.25 s | tm_response_release |
| Full lock 2 s at 120/200/280 km/h: speed kept | >= 93% | tm_turn_keep |
| ... body slip | <= 8 deg | tm_turn_no_slide |
| ... lateral acceleration | >= 1.0 g | tm_turn_grip |
| Full-lock slalom from 250 km/h, 4 s | slip <= 15 deg | tm_no_spin |
| Brake tap + full steer at 200 km/h, 1.5 s | slip >= 12 deg, turns >= 1.15x the grip turn, keeps >= 80% | tm_drift_* |
| ... 1 s after centring | slip <= 6 deg | tm_drift_recovers |
| Barrier 15/30 deg at 250 km/h | keeps >= 85/70%, nose <= 10 deg off the wall after 0.5 s, tilt <= 12/15 deg, pop <= 0.4 m | tm_wall_* |
| Barrier 45 deg at 200, 90 deg at 150 km/h | keeps >= 50%; head-on bounce <= 3 m/s; no flip | tm_wall_* |
| Curved 80 deg wall ride, r 70 m, 150/200 km/h | lateral drift <= 2 m, speed kept >= 95%, grounded | tm_wallride_* |
| Loop r 18 m at 140 km/h | completes, grounded | tm_loop_* |
| 12 deg kicker at 200 km/h onto flat | lands on wheels, keeps >= 95% | tm_landing_* |
| Free fall | 12-18 m/s^2 | tm_air_gravity |

## 4. Baseline (before the rewrite, kaze)

```
TM accel kaze t100=3.07s t200=8.85s v@10s=212 v@30s=280 km/h
TM response kaze steady_yaw=0.27 rad/s t90=0.083s release=0.550s
TM turn kaze 120 km/h keep=116.9% max_slip=12.9 deg lat=1.50 g
TM turn kaze 200 km/h keep=98.2% max_slip=14.9 deg lat=2.04 g
TM turn kaze 280 km/h keep=89.8% max_slip=18.6 deg lat=2.97 g
TM spin kaze slalom max_slip=40.8 deg
TM drift kaze max_slip=19.0 deg turn 33 vs grip 29 deg keep=92.1% slip_after=0.8
TM wall kaze 15 deg 250 km/h keep=97% heading_off_wall=19 deg bounce=6.2 m/s tilt=1 pop=0.00
TM wall kaze 30 deg 250 km/h keep=87% heading_off_wall=8 deg bounce=1.5 m/s tilt=1 pop=0.00
TM wall kaze 45 deg 200 km/h keep=72% heading_off_wall=2 deg bounce=0.2 m/s tilt=1 pop=0.01
TM wallride kaze 150 km/h entry=150 min=150 keep=100% max_lat=8.07 m air=38/290
TM wallride kaze 200 km/h entry=201 min=201 keep=100% max_lat=6.49 m air=28/260
TM loop kaze done=true air=0/188 top=141 km/h
TM landing kaze airborne=true keep=95.0% tilt_after=5
TM air kaze effective_gravity=13.1 m/s^2 (1.33 g)
```
17 of 52 checks fail (wall ride, grip turn slide, slalom spin, release lag, acceleration, wall align).

## 5. Rewrite plan (car.gd keeps its public API, signals and the grind hook)

1. **Ground handling = a yaw-rate controller + lateral velocity cancellation** (the standard arcade
   approach behind TM-like handling): the steering sets a desired yaw rate v*tan(delta)/L, a torque
   drives the body's yaw rate to it within ~0.05 s, and a lateral force at the centre of mass
   cancels sideways velocity in the road plane, capped by mu * (total suspension load). Lateral
   forces stay perpendicular to the heading, so grip turns don't bleed speed. Max steer angle
   follows the grip limit (unchanged `max_steer_at`, used by the AutoDriver). Removes: slip-curve
   tires, friction circle, stability assist, drift stabilizer, drift speed keeping, power
   oversteer, the steep-road stick force.
2. **Drift mode**: brake tap + steer above ~60 km/h (or handbrake) lowers the lateral cap and lets
   the yaw controller target a slip angle (bounded ~35 deg), so the car turns tighter; centring the
   wheel ends it and grip ramps back in ~0.3 s.
3. **Adhesion everywhere**: the same lateral cap works on banks, walls and loops because the load
   comes from the springs (gravity normal component + centripetal + downforce): no special case.
4. **Engine**: stronger low/mid acceleration (targets above); top speeds unchanged so the tracks
   still fit.
5. **Keyboard steering**: one fast ramp (~0.08-0.12 s to full), no lock cap; the car limits the
   angle by grip.
6. **Barriers**: remove the speed into the wall with a small bounce, keep the speed along it minus a
   little friction, and yaw the nose toward the wall tangent over ~0.2 s; still no roll/pitch/pop.
7. **Air**: keep 1.35 g in the air for every jump, keep the light auto-level; landings keep speed.
8. **Rails**: capture only when the car actually comes down onto the rail (no 1.8 m pull).
9. Then retune the AutoDriver and re-run the physics, track and real-track suites.
