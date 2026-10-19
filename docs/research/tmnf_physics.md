# TrackMania Nations Forever: how the Stadium car really works (reverse engineered)

Session 9, 2026-10-15. Owner request (TRANSCRIPT session 9): look at ModTMNF and REA, then reverse
engineer TrackMania Nations Forever. Goal for SpeedFest: replace the guessed "Trackmania feel" targets
(docs/research/m7_physics.md) with the real model and numbers.

**What this page is:** our own description of the behaviour we found in TmForever 2.11.26 (the free
TMNF client, official installer from Ubisoft's CDN) and in the car's data files, plus the numbers. No
game code, binaries or assets are in the repo. Tools: `tools/research/tmnf/` (README there).
`tools/research/tmnf/tmnf_model.py` is our runnable reconstruction of the flat-ground model; the
derived numbers in §6 come from it.

## 1. How we got it

1. **Symbols.** TMNF ships `TmForever.map` (MSVC linker map), so all 63,139 functions keep their
   names (ModTMNF's main point). We fed them to Ghidra 12.1.4 as analysis seeds through **REA**
   (morluto/rea) and drove REA over MCP from a small bridge (one Ghidra analysis, many queries).
2. **The car code.** `CSceneVehicleCar::ComputeForces` picks a force model by a tuning enum; the
   Stadium car uses **model 6** (`ComputeForcesModel6`). Helpers read: `ApplyFrictionForces`,
   `GetSlopeAdherence`, `ComputeAirControl`, `IntegrateVehicle`, `WheelIntegrate`,
   `WheelAddForceToVehicle`, `WheelAbsorbContact`, `AbsorbContact`, `EngineIntegrate`,
   `EnableTurbo`/`UpdateTurbo`, `UpdateParamsFromTuning`, plus the rigid-body layer
   (`CHmsDyna::IntegrateStep`, `CHmsZoneDynamic::ComputeCorpusForces`/`PhysicsStep2`).
3. **The numbers.** The tuning lives in `Stadium.pak` →
   `Vehicles\VehicleTunings\StadiumCar.VehicleTunings.Gbx`. Packs are Blowfish-encrypted with an
   IV that the reader re-keys on every node read (with the node's parent class id), after every
   tuning name and after every `CPlugSurfaceGeom` box. We re-implemented GBX.NET's pack format,
   worked out TmForever's reader buffering (256-byte zlib input blocks into a 1024-byte output
   buffer; large reads bypass it, handled by a backtracking search) and checked every file against
   zlib's Adler-32. Parsed with the chunk layout from `CSceneVehicleCarTuning::Chunk`.
4. **The file holds 30 tunings**: Nadeo's development history of the Stadium car, named by date from
   `26Nov2002` to `20juin2006`. The game uses the last one (`selected = 29`, **`20juin2006`**).
   Nadeo stripped the tuning parameter names from the release build (other classes keep theirs), so
   every meaning below comes from how the code uses each field (offset in brackets).
5. Also decrypted: `StadiumCar.Solid.Gbx` (geometry: wheel and body collision shapes),
   `StadiumCar.VehicleStruct.Gbx` and `StadiumVehicleMaterials.RefBuffer.Gbx` (surfaces).

## 2. The simulation frame

- **100 Hz** fixed ticks (TMNF's known rate). Collision is sub-stepped so the car moves at most
  ~0.3 m per sub-step [0x168] (anti-tunnelling), up to 1000 sub-steps.
- **Mass 1** [0x130]. Every tuning force is an **acceleration** (m/s²); nothing is scaled by mass.
- **Inertia** from a box: "inertia mass" 5 [0x134], size 1 × 1 × 2 m [0x138..0x140]
  → pitch/yaw ≈ 2.08, roll ≈ 0.83. Linear and angular damping 0 (overriding the solid's 0.1/0.3).
- **Geometry** (StadiumCar physics shapes): wheels at x ±0.863 (front) / ±0.885 (rear), z +1.782
  (front) / −1.2055 (rear), y 0.3525; wheel shape radius **0.364 m**, half-width 0.182 m.
  **Wheelbase 2.988 m.** Centre of mass at mid-wheelbase, 0.45 m [0x148] above the wheel contact
  level. Chassis collision: four boxes (`BodySurf`…`BodySurf04`).
- Semi-implicit Euler: v += F·dt, then x += v·dt; angular speed clamped.

## 3. Forces, in tick order

### 3.1 Gravity (the big one)
The race scene's gravity field is **(0, −10, 0)**. The car multiplies it by a coefficient it rewrites
every tick: **3.0 while any wheel touches** [0x160], **2.5 in the air** [0x164]. Effective gravity is
**30 m/s² on the ground, 25 m/s² (2.55 g) in the air**. In the air only, linear damping 0.03 [0x154].
This is why TM jumps are short and snappy and the car feels glued to the road.

### 3.2 Suspension (per wheel)
Spring along the car's up axis: F = 40·(0.2 − length) − 1.0·d(length)/dt [0x114, 0x124, 0x118],
applied at the wheel. The length relaxes back to 0.2 at 5/s [0x194] and is pushed in by contact
penetration. Four springs at full compression give 32 m/s² against 30 m/s² of ground gravity: the car
sits deep in a stiff, short suspension. Wheel contact impulses remove 20% of the approach speed per
tick (factor 0.8 [0x184/0x18c]).

### 3.2a Wheel ground contact: what `WheelAbsorbContact` actually does
*(Session 11, re-read from the disassembly at 0x7c11d0 to settle whether the "bottomed" flag means
what §3.2 assumes. It does.)*

The whole suspension/impulse half of the function is behind `tuning[0x350] == 2` ("suspension model
2"; the Stadium car's value, §5). A contact whose normal is more than 45° off the car's up axis is a
**side** contact (`|n_car.x| >= sin 45°`): it only sets the wall flag and the lateral slow-down
vector, and takes an impulse keeping 0.5 [0x178/0x17c] at the contact point. A ground contact
accumulates the normal, the contact count and the surface, and then:

```
if pen_car.y > 0:                        # penetration pushing up into the car
    room     = wheel.susp_len - 0x11c    # 0x11c < -1e-5 disables this: take = pen_car.y
    take     = min(pen_car.y, room)
    bottomed = (room <= pen_car.y)       # <- the flag, set ONLY here
    wheel.absorb = max(wheel.absorb, take)
    pen_car.y   -= take
else:
    bottomed = true                      # nothing for the spring to take

vn = dot(n, v_rel)
if vn < 0:
    vn_up = (n * vn)_car.y
    if bottomed or vn_up >= 0:
        impulse(keep 0.8, v_rel, n)  at the CONTACT POINT       # full kick, with torque
    else:
        v2 = v_rel - up * vn_up                                 # spring takes the vertical part
        if dot(n, v2) < 0:
            impulse(keep 0.8, v2, n) at the WHEEL CENTRE        # remainder only
```

So the flag is genuinely "the spring could not swallow the whole penetration", it is **not** set for
every real contact, and TMNF does **not** apply the full contact impulse on every ground touch. The
two application points (contact point when bottomed, wheel centre otherwise) are real and are what
decides how much pitch a landing produces. `stadium/core/tm_body.gd::_collide` already implements
exactly this, branch for branch.

### 3.2b The angular scale and clamp in `AddVehicleImpulse` (0x7be390)
Both contact branches above hand their impulse to `CSceneVehicleCar::AddVehicleImpulse(j, at)`, which
is **not** a plain rigid-body impulse:

- linear: `v += j / mass` — unscaled;
- angular: the `r x j` term is scaled by **0.55 [0x0ec]** before it is added (one axis is scaled
  again by [0x0e8], which the tuning chunks never write, so it keeps its constructor default);
- then `|w|` is clamped to **100 rad/s [0x14c]** (so high it effectively never binds).

The 0.55 is the part that matters: **every contact in TMNF produces only 55% of the rotation a
textbook impulse would give.** Our port applies the full `r x j`, so our contacts over-rotate.

**Implemented (v0.5):** `TmBody._apply_impulse` turns the car by `IMPULSE_SPIN` (0.55) of `r x j` and
caps the spin at `MAX_SPIN` (100 rad/s); the impulse is still sized with the full inertia, as
`ComputeImpulse`. Against TMNF's own runs (the six jumpiest tracks, `race/ghost_fit.tscn`): landings
0.34 -> 0.26 m apart (median), speed error 2.2 -> 1.9 km/h (p90 17.7 -> 15.7); time on the rear
wheels after nose-down landings 10.5 -> 20.8 s (TMNF 30.5): the softer spin of the rear contact
lets the car pivot up as TMNF's does. Overall (3844 windows) 0.15 -> 0.14 m.

### 3.3 Slope adherence: the wall/loop rule
Before the tyre forces, the game measures how much of the current force on the car (gravity) lies
along the car's up axis: r = |F_up| / |F|, i.e. |cos(tilt)| relative to gravity.
- **Side grip** factor: 0 below r = 0.3, smooth ramp (1 − cos) to 1 at r = 0.7 [0xd4, 0xd8].
- **Drive/brake** factor: 0 below r = 0.4, ramp to 1 at 0.7 [0xdc, 0xe0].

So grip fades between ~46° and ~73° of tilt and is **zero on a wall steeper than ~73°**, but full
again upside-down (|cos| = 1, e.g. the top of a loop). There is no stick force: on a wall the
springs (pressed by speed and curvature) hold the car while gravity drags it down. A fast car crosses
a curved wall before it slides off; a slow one falls.

Loops (remake, session 12): the Stadium loop is a helix on a cylinder (radius 42.66 m to the road,
64 m sideways per half turn from the first frame on, measured), so its road turns ~25.5° off the
straight leading in. Nothing in the model pushes the car sideways (gravity has no component along
the cylinder's axis), so the car must be steered into the drift on the loop's floor, while it still
grips; a wheel on the curb is a side contact and brings the wall slow-down (§3.9). On the 30 m/s²
ground gravity the car needs ≥ 129 km/h at the top (g·R) and so about 280 km/h in.

### 3.4 Steering
- Input slews to the target at **20/s** [0x94] (full lock in 0.05 s, keyboard or pad alike).
- Steer angle **δ = steer · asin(1 / (2 + 0.85·|v|))** [0x6c, 0x70], v in m/s: 30° at rest, 2.2° at
  100 km/h, 1.2° at 200, 0.6° at 400. The **front wheels' lateral axes are rotated by δ**, so they
  push the car sideways directly (§3.5).
- **Yaw torque** on the front axle: steer · SteerDriveTorque(km/h) [0xa0] · ramp(v), ramp =
  sin(π/2 · v/30) below 30 m/s [0x74] (0 below 0.7 m/s), 1 above. SteerDriveTorque (linear):
  16 @ 0, 10.4 @ 50, 8.5 @ 100, 6.8 @ 150, 5.5 @ 200, 4.25 @ 300, 4.0 @ 400, 3.75 @ 500+.
- **Yaw damping** from every axle: 0.08 [0x98] × (−20 × axle side speed) × lever (±wheelbase/2),
  never capped by grip. Result: steady yaw rate ω = steer·K(v)·ramp(v) / (3.2·wheelbase/2), reached
  with a time constant of ~0.15 s (yaw inertia 2.08). The yaw rate depends on speed only, not on grip.
- Visual front-wheel angle: 30° at 0 km/h → 10° at 100 km/h+ (curve [0x378]); cosmetic.

### 3.5 Side grip (per wheel)
- Side force F = −20 × (car velocity · wheel lateral axis) [0xa4 × 0.5], applied **at the centre of
  mass** (no torque).
- Cap = surface grip × slope side factor × MaxSideFriction(km/h) [0xac] × slide factors ×
  damper factor. The damper factor (`M6GetModulationFromDamperAbsorbVal`) is curve [0x224] at
  r = (len − 0.7) / (0 − 0.7) [0x120, 0x11c], len = the wheel's suspension length: 1.0 at the
  static length (0.0125 m) and below ~0.0175 m, 0.91 at 0.05 m, 0.51 with the suspension fully
  extended (0.2 m). A wheel that barely touches grips about half as much.
  MaxSideFriction: 80 up to 100 km/h, 75 @ 200, 67 @ 300, 60 @ 400, 55 @ 500. With 20 per m/s, a
  wheel needs ~4 m/s of side speed to reach it: **on asphalt the car essentially never slides by
  cornering alone**; side slip stays under ~1°.
- Over the cap the wheel is flagged **sliding**: F = 0.982·cap + 0.018·F [0xb4]. A sliding wheel's
  cap is ×0.35 [0xb0], and ×0.2 more while braking [0x244]. The flag clears as soon as the demand
  fits under the (reduced) cap.

### 3.6 Engine, brake, drag
- **Acceleration is a step function of speed** [0x34]: **16 m/s² from 0 to 101 km/h, 11 to
  201, 7 to 401, 5.5 to 801, 1 above** (reverse side: 12/6/2/1). Times surface accel factor.
- **No aerodynamic drag under throttle.** Only above 1000 km/h [0x2c] does a flat 10 m/s² [0x60]
  push back (the famous speed cap); reverse caps at 499 km/h [0x30].
- **Speedslide**: when wheels exceed their cap, acceleration blends toward a "slipping" value of
  **10 m/s²** [0x1e0 × 0x1e4] by how far over the cap they are. Above 201 km/h that is *more* than
  normal (7, then 5.5): a slight slide accelerates harder. This is TMNF's known speedslide trick, and
  seeing it fall out of the code is a good sign that the reading is right.
- Gear changes cut drive for ~25 ms (engine RPM model, otherwise only sound/visuals).
- **Coasting** (no throttle): −1.0 − 0.3·v [0x58, 0x5c].
- **Brake**: (1 + 1.75·v) × input [0x40, 0x44], halved per sliding wheel [0x240], capped at 30
  [0x4c] (60 [0x48] if a wheel already slides), × surface brake factor. Above ~60 km/h the cap is
  hit, which **flags all four wheels sliding**: front grip collapses while braking and steering.
  That is TM's brake-drift. In this model the slide is a grip state (front wheels skate, speed
  bleeds), not a big slide angle; the yaw rate is still the steering's.
- Throttle + brake at low speed: burnout (< 3 m/s), donut (< 75 km/h with steer); cosmetic-ish
  state machine with rollover torques. Reverse: brake below ~0 speed drives backwards [0x230].

### 3.7 Air
**No air steering.** In the air the only torque is angular drag 0.4·|ω| + 0.2·|ω|² against the spin
[0x158, 0x15c]: the car keeps the rotation it took off with, slowly damped. Gravity 25 m/s².

### 3.7b Jumps against TMNF's own runs (M10-4, session 13)
Measured with `stadium/race/ghost_fit.tscn` (our car started from a campaign ghost's state, driven
0.5 s with the run's own inputs; start velocity from the neighbouring positions, since a ghost
packs velocities with 8-bit angles) on the six jumpiest campaign tracks (A06, B12, C11, D05, D08,
E04) and with `tools/research/tmnf/air_check.py` over every campaign ghost:
- **Flight is identical**: TMNF's heights give −24.4 to −24.9 m/s² (gravity 25 plus the 0.03·v
  drag), horizontal drag 0.03·v at every speed (−2.7 m/s² at 300-350 km/h, −5.2 at 600-650), spin
  decay = (0.4|ω| + 0.2|ω|²)/inertia (0.19 vs our 0.20 rad/s² at 0.75 rad/s). Ours ends 0.01-0.02 m
  from TMNF after 0.5 s in the air (median, 738 windows).
- **Take-offs agree** (0.11-0.45 m, speed within 0.1-0.7 km/h median).
- **Landings agree in the median** (309 windows: 0.31 m, speed +0.3 km/h) but scatter: a tenth of
  them end 4 km/h slower and a tenth 11-15 km/h faster than TMNF. The visible difference: after a
  nose-down landing (pitch −11 to −26°) TMNF's car kicks up to −4 to −6.5 rad/s nose-up, rides on its
  rear wheels 12-20° nose-up for 0.3-0.5 s (nose coming down at a steady ~9.3 rad/s², a rigid car
  pivoting on its rear contact) and sometimes loses 4-15 km/h; ours stops that rotation when the
  rear wheels touch (peak +3.5° on E04 at 98 s) and keeps its speed. Over those windows TMNF spends
  ~29 s on its rear wheels alone, ours ~10 s.
- Tried and rejected (all measured on the same windows): the ground contact's keep factor once per
  tick instead of per substep (wheelies 10 -> 16.6 s, speeds worse), a harder contact (keep 0.2:
  wheelies 4 s), softer ones (0.9/0.95 per tick: ~18 s, speeds worse, mean error 7.4-8.8 km/h).
  The mechanism is in TMNF's contact code (`CSceneVehicleCar::WheelAbsorbContact`, `AbsorbContact`,
  `AfterContacts`), which this pass did not read: open.
- **M10-4b (owner: "do it", then "nevermind")**: TMNF's contact code read locally (decompiled, never
  in the repo). Our port matches it where it reads clearly: the suspension (spring 40, damper 1,
  rest 0.2, relax 5/s, absorbing a wheel's penetration along the car's up axis up to its length),
  the ground contact keep 0.8 and chassis keep 0.5 (`ComputeImpulse`: j = (keep - 1) v.n / k), the
  side and chassis friction. Unresolved: in `WheelAbsorbContact` a ground contact takes the full
  impulse at the contact point under a flag the decompiler lost (else only the approach left after
  the spring's vertical share, at the wheel centre); ours takes it when the suspension bottoms.
  `AddVehicleImpulse` scales an impulse's spin by 0.55 [0xec] and caps it at 100 rad/s [0x14c]
  (§3.2b: the disassembly, read by a parallel session, scales every axis; the decompiled view had
  suggested two). TMNF's landings (A06 10.8 s, E04 97.9 s, D08 13.7 s): within
  0.1 s of a nose-down touch the fall is mostly gone and the car spins nose-up at 3-4 rad/s on
  bottomed rear springs; the rear then slows the spin only ~25 rad/s² (springs and gravity), while
  ours stops it at once (a near-inelastic rear contact). Measured on the six tracks' landings
  (TMNF 30.5 s on the rear wheels; ours as ported 10.5 s, speed error median 2.2 km/h): full impulse
  always 7.8 s; never when bottomed 19.9 s but the fall is never stopped (speed error 7.9 km/h);
  spin scaled in the car frame 9.6 s; unlimited suspension absorption: chassis drags, -30 km/h;
  suspension once per tick 11.2 s; impulses from the centre of mass's velocity 13.8 s (wheelies on
  flat ground 26 s vs TMNF's 6). Kept as ported. The disassembly (to name the flag) was not read:
  the session's safety check stopped it. Next step if resumed: the spin scaling in the world frame.

### 3.8 Turbo pads
Turbo **multiplies the acceleration curve**: drive += accel(speed) × strength, even without throttle.
Yellow pad (surface 7): strength **5** [0xf0], **250 ms** [0xf8]; red pad (surface 26): strength
**20** [0xf4], **100 ms** [0xfc]. Strength is scaled by how well the car points along the pad, and the
timer re-arms every tick while on the pad (so the boost lasts contact time + duration). At 200 km/h a
yellow pad adds 35 m/s² (7 × 5).

### 3.9 Walls and barriers
- **Chassis contact**: only while moving into the surface. Tangential speed is clipped to a friction
  cone μ = 0.3 [0x170] (0.2 on metal [0x174]), then an impulse removes half of the remaining
  approach (factor 0.5 [0x17c]). A glancing hit keeps most of the speed and nothing pops the car.
- **Wheel side contact** (contact normal more than 45° off the car's up axis): flags a wall hit and,
  for **500 ms** after the last one [0x1e8], applies a slow-down along the velocity of
  LateralContactSlowDown(km/h) [0x68]: **12 @ 50, 24 @ 100, 48 @ 200, 70 @ 400 m/s²**. Brushing a
  wall with the wheels at 200 km/h costs ~80 km/h. This is the "wall kills your run" feel.

### 3.10 Surfaces (StadiumVehicleMaterials)
Four factors per surface, averaged over the wheels on the ground. The file stores them in the
column order below; which force each scales was **measured from TMNF's own runs** (M10-3, session
13; until then the columns were read as top speed, accel, brake, grip, which made grass and dirt
wrong): on grass TMNF accelerates at exactly 0.4x asphalt's curve at every step (6.33 / 4.36 /
2.83 m/s^2 against 16 / 11 / 7) and brakes at 30 x 0.05 (20.7 m/s^2 at 200-240 km/h = 1.5 + the
coasting drag), on dirt 0.9x and 0.4x (`tools/research/tmnf/accel_curve.py`, `--brake`); and our
car started from a ghost's state and driven 0.5 s with the run's own inputs
(`stadium/race/ghost_fit.tscn`) follows TMNF best with column 1 as the side grip:

| reading (columns as top, accel, brake, grip) | grass B12 | grass D05 | dirt D15 | dirt E03 |
|---|---|---|---|---|
| 0,1,2,3 (the old one) | 1.08 m, 3.4 km/h | 0.96 m, 5.0 | 1.47 m, 12.7 | 0.93 m, 10.0 |
| **0,2,3,1 (measured)** | **0.24 m, 0.7** | **0.25 m, 1.7** | **0.44 m, 1.9** | **0.29 m, 1.7** |
| 0,2,3,0 | 2.74 m, 2.2 | 1.11 m, 8.0 | 3.10 m, 3.5 | 0.69 m, 2.7 |
| 0,2,3,3 | 1.00 m, 1.4 | 0.92 m, 2.4 | 1.17 m, 2.5 | 0.62 m, 1.6 |
| 1,2,3,1 | 1.76 m, 24.5 | 0.25 m, 1.7 | | |

(median distance apart and |speed difference| after 0.5 s, all four wheels on that surface;
asphalt for comparison: 0.16 m, 0.2 km/h.)

| Surface | col 0: top speed | col 1: grip | col 2: accel | col 3: brake |
|---|---|---|---|---|
| Asphalt, Concrete, Metal, Wood | 1.0 | 1.0 | 1.0 | 1.0 |
| Dirt | 0.9 | 0.25 | 0.9 | 0.4 |
| DirtRoad | 0.7 | 0.5 | 1.0 | 1.0 |
| Grass | 0.5 | 0.15 | 0.4 | 0.05 |
| Sand | 0.2 | 0.5 | 0.4 | 1.0 |
| WetPavement | 1.0 | 0.85 | 1.0 | 0.85 |
| WetGrass | 0.1 | 0.5 | 0.5 | 1.0 |
| WetDirtRoad | 0.9 | 1.0 | 1.0 | 1.0 |
| Snow | 0.2 | 0.1 | 0.6 | 0.1 |
| Ice | 1.0 | 0 | 0.1 | 0 |

So on grass the car keeps 40% of its drive and 15% of its grip but its brakes barely work; dirt
drives almost like asphalt with a quarter of the grip and 40% of the brakes. Column 0 only caps
the top speed (500 km/h on grass, above any grass run in the campaign replays: up to ~260 km/h). In the code: `TmTuning.SURFACES` (the
file's order) and `S_TOP`, `S_GRIP`, `S_ACCEL`, `S_BRAKE`.

## 4. Behaviour numbers (from `tmnf_model.py`, flat asphalt)

| | TMNF Stadium car |
|---|---|
| 0-100 / 200 / 300 / 400 km/h | 1.74 / 4.26 / 8.2 / 12.2 s |
| 0-500 / 800 km/h | 17.2 / 32.4 s (no drag: it keeps accelerating) |
| Full-lock radius @ 50 / 100 / 150 / 200 km/h | 9.6 / 15.8 / 29 / 48 m |
| Full-lock radius @ 300 / 400 / 500 km/h | 94 / 133 / 177 m |
| Full-lock lateral acceleration @ 100 / 200 / 400 km/h | 5.0 / 6.5 / 9.5 g (grip never runs out) |
| Side slip in a grip turn | < 1° |
| Steering: full lock reached | 0.05 s; yaw time constant ~0.15 s |
| Brake 100→0 / 200→0 | 1.7 s, 13 m / 2.3 s, 39 m (3 g plateau above 60 km/h) |
| Brake tap + full lock @ 200 km/h | front wheels slide, slip angle stays < 2°, speed bleeds |
| Gravity on ground / in air | 30 / 25 m/s²; an 8 m drop takes 0.8 s |
| Wall brush with the wheels @ 200 km/h | ~−80 km/h over 0.5 s |
| Grip on a wall | 0 beyond ~73° of tilt; full upside down |

Limits of the planar model: no suspension/pitch/roll, no slopes, all wheels on one surface.

## 5. Full tuning table (20juin2006)

Meaning given where the code makes it clear; the rest are fields model 6 does not read or that drive
sound, visuals or the other force models (3, 4, 5). Curves: (km/h or input → value); "step" =
interpolation 1.

| Offset | Value | Meaning |
|---|---|---|
| 0x028 | 50 | (base class) |
| 0x02c | 277.78 | max forward speed, m/s (1000 km/h) × surface top-speed factor |
| 0x030 | 138.61 | max reverse speed, m/s (499 km/h) |
| 0x034 | step (−1000,1)(−102,2)(−80,6)(−35,12)(0,16)(101,11)(201,7)(401,5.5)(801,1) | acceleration vs km/h |
| 0x040, 0x044 | 1, 1.75 | brake = (0x40 + 0x44·v) × input |
| 0x048, 0x04c | 60, 30 | brake cap: wheels sliding / not |
| 0x058, 0x05c | 1, 0.3 | coasting drag: constant + linear |
| 0x060 | 10 | over-max-speed push-back |
| 0x068 | (0,0)(50,12)(100,24)(200,48)(400,70) | wall-contact slow-down vs km/h |
| 0x06c, 0x070 | 2, 0.85 | steer angle = asin(1/(0x6c + 0x70·v)) |
| 0x074 | 30 | steer torque ramp speed, m/s |
| 0x078 | (−50,1)(0,0)… | steer slow-down vs km/h (0 going forward) |
| 0x07c | 0.5 | steer slow-down scale |
| 0x094 | 20 | steering input slew, 1/s |
| 0x098 | 0.08 | yaw damping from axle side forces |
| 0x09c | 1 | steer torque factor while sliding |
| 0x0a0 | (−100,7)(0,16)(50,10.4)(100,8.5)(150,6.8)(200,5.5)(300,4.25)(400,4)(500,3.75) | steering yaw torque vs km/h |
| 0x0a4 | 40 | side stiffness (×0.5 per wheel) |
| 0x0ac | (0,80)(100,80)(200,75)(300,67)(400,60)(500,55) | max side force per wheel vs km/h |
| 0x0b0 | 0.35 | grip while sliding |
| 0x0b4 | 0.018 | blend over the cap |
| 0x0d4–0x0e0 | 0.3, 0.7, 0.4, 0.7 | slope adherence thresholds (side, drive) |
| 0x0f0, 0x0f8 | 5, 250 | yellow turbo strength, ms |
| 0x0f4, 0x0fc | 20, 100 | red turbo strength, ms |
| 0x114, 0x118, 0x124 | 40, 1, 0.2 | spring, damper, rest length |
| 0x11c, 0x120 | 0, 0.7 | suspension lengths mapped to damper ratio 1 and 0 (grip factor) |
| 0x130 | 1 | mass |
| 0x134, 0x138–0x140 | 5; 0.5, 0.5, 1.0 | inertia box: mass, half-size |
| 0x0e8, 0x0ec | (not written), 0.55 | angular scale on every contact impulse (AddVehicleImpulse) |
| 0x148 | 0.45 | centre of mass height above wheel contact |
| 0x14c | 100 | max angular speed, rad/s (clamped in AddVehicleImpulse) |
| 0x154 | 0.03 | linear damping in the air |
| 0x158, 0x15c | 0.4, 0.2 | air angular drag: linear, quadratic |
| 0x160, 0x164 | 3, 2.5 | gravity factor: ground, air |
| 0x170, 0x174 | 0.3, 0.2 | chassis contact friction (default, metal) |
| 0x178–0x18c | −0.5 / −0.8 | contact impulse factors (side, ground) |
| 0x194 | 5 | suspension relax rate |
| 0x1e0, 0x1e4 | (0,10), 1 | slipping acceleration (speedslide) |
| 0x1e8 | 500 | wall-contact slow-down duration, ms |
| 0x200 | 1 | slip blend scale |
| 0x224 | (0,0.1)(0.6,0.3)(0.975,1)(1,1) | side grip factor vs damper ratio (see §3.5) |
| 0x228–0x23c | 5, 200, …, 0.05, 0.05 | load transfer: per wheel on the ground, 0.05 × (contact point × last tick's total force), pitch and roll (the force is stored ÷ 0x228 and read back × −0x228) |
| 0x230 | (−150,0.1)(−100,1.5)(−50,8)(0,30) | reverse acceleration vs km/h |
| 0x240, 0x244 | 0.5, 0.2 | brake halving per sliding wheel; grip while sliding + braking |
| 0x248, 0x24c | 100, 50 | reverse-brake caps |
| 0x250–0x2bc | … | burnout/donut state machine (rollover torques, radii, timings) |
| 0x2c4–0x2f4, buffers | 6 gears: speeds 400/370/220/160/110/85… | engine RPM/gear model (sound, 25 ms shift cut) |
| 0x350 | 2 | suspension model 2 |
| 0x354 | 5 | force model 6 (Steer06) |
| 0x378 | (0,30)(100,10) | visual front wheel angle, degrees |

## 6. What this means for SpeedFest (M7 handling)

Session 10 merged a handling rewrite built on guessed targets (yaw-rate steering, lateral grip
cancellation, a 12-28° drift mode, glancing barriers, a ground stick). Much of its design agrees with
TMNF; these points don't:

1. **Gravity**: TMNF uses 3 g on the ground and 2.5 g in the air (we use ~1.35 g in the air).
   Our jump and loop geometry is tuned for low gravity, so changing it means re-checking every map.
2. **Acceleration**: TMNF is a staircase with no drag under throttle: 16/11/7/5.5 m/s². 0-100 in
   1.74 s, 0-200 in 4.3 s, and it keeps accelerating. Ours has drag-limited top speeds per car.
3. **Turning**: yaw rate is set by speed alone (torque curve vs damping) and grip almost never runs
   out on asphalt: radius 16 m @ 100 km/h, 48 m @ 200, 133 m @ 400 (5-9 g). The visual steer angle
   is decorative; the physical angle is asin(1/(2+0.85v)).
4. **Drift**: in TMNF the brake drift is a grip state (front wheels skate, braking softens), with
   small slide angles, not a target slide angle.
5. **Walls**: a soft chassis impulse (μ 0.3, half the approach speed), plus a hard **500 ms
   slow-down when wheels touch a wall** (24 m/s² at 100 km/h). TMNF punishes wheel-to-wall contact
   much more than chassis grazes. The owner found our barriers "annoying"; TMNF's are annoying by
   design but predictable.
6. **Wall rides and loops**: no stick force; side grip fades with tilt (0 beyond ~73°, full upside
   down) and the springs plus speed carry the car. This matches the owner's complaint in reverse:
   TMNF cars do slide down flat walls, only curved, fast wall sections work.
7. **Air**: no air steering at all (we have some), angular drag 0.4|ω| + 0.2|ω|².
8. **Turbo**: multiplies the accel curve (×5 yellow for 250 ms, ×20 red for 100 ms, while on the pad
   plus that long).
9. **Surfaces**: grass ×0.4 accel / ×0.15 grip / ×0.05 brakes, dirt ×0.9 / ×0.25 / ×0.4 (§3.10,
   measured in M10-3; this list first read them as grass ×0.15 accel / ×0.05 grip).

Suggested next step: a `TM_FAITHFUL` handling mode in `car.gd` that follows §3 (mass-1 accelerations,
the curves above, 100 Hz), with `tests/physics/test_tm` targets regenerated from `tmnf_model.py`; then
re-tune maps for 25-30 m/s² gravity. This is a design decision for the owner, because it changes how
every existing map plays.
