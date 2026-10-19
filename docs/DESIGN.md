# DESIGN — SpeedFest

A time-attack racer that drives like TrackMania Nations and looks like Need for Speed Underground 2.
One city, at night, in the rain's aftermath: wet asphalt, neon on every facade, and five cars you
rebuild in a garage until the lap time falls.

## The pitch
- **Drive** — TMNF's force model 6 with the `20juin2006` tuning, reverse engineered and
  reimplemented (`docs/research/tmnf_physics.md`). Grip that lets go cleanly, a brake that drifts,
  no gears to think about, a respawn that costs you a second and nothing else.
- **Build** — a garage of five cars with sixteen slots each. Eight change how the car drives,
  eight change how it looks, and the look ones that add downforce or lighter wheels change both.
- **Place** — a neon city built in code: towers with lit windows, signs, billboards, gantries,
  tunnels and a flyover. No photographs, no bought models; every mesh in the game is generated.

## The cars
| id | name | type | character | top | mass |
|---|---|---|---|---|---|
| `f4` | Vireo F4 | FIA F4 single-seater | the fastest thing through a corner; tiny nitrous tank | 302 | 570 kg |
| `kaze` | Kaze RS | JDM sport coupe | the baseline: balanced, happy to drift, refills boost fast | 291 | 1290 kg |
| `vector` | Vector GT8 | grand tourer V8 | the highest top speed, heavy, lazy turn-in | 334 | 1620 kg |
| `polonez` | Lodowiec 1600 | Eastern Bloc classic | soft, loose, the biggest boost gain, modest top speed | 248 | 1180 kg |
| `ridge` | Ridge RX | offroad pre-runner | keeps its grip on dirt and kerbs, torque off the line | 236 | 2050 kg |

Each is built from its real dimensions (the Lodowiec is a 4.27 m car on a 2.51 m wheelbase, like
the Polonez it is drawn from; the Vireo is a 4.42 m F4 car on 2.47 m). The single-seater has its own
builder: raised nose, two-element wings, sidepods, airbox, halo, pushrod suspension and a driver.

### What a car is made of
`specs` are expressed in the terms of the force model: `top_kmh` (the speed cap), `accel` and
`launch` (the engine staircase and its first step), `grip` (the side-friction cap), `brake`,
`steer`, `slide_grip` (how loose it is once a wheel lets go), `mass_kg` (display + the weight
maths), and the nitrous four: `boost_power` (m/s² while held), `boost_tank` (seconds),
`boost_gain` (tank per second of driving) and `boost_kmh` (how much the cap lifts).

The owner asked for cars that differ in "top speed, boost gain etc." — those two numbers alone
separate the lineup by 100 km/h and by a factor of two on refill rate.

## Tuning (Underground rules)
Performance: **engine**, **turbo**, **nitrous**, **tyres**, **brakes**, **suspension**,
**gearbox**, **weight**.
Look: **body kit**, **spoiler**, **rims**, **paint** (+ finish: gloss, metallic, pearl, matte,
chrome), **vinyl** (16 designs), **neon** underglow (colour + off/static/pulse/strobe/rainbow/full
kit), **headlights** (bulb colour and reach), **window tint**.

Rules that make the choices interesting rather than a ladder:
- The **gearbox** is a trade, not an upgrade: close and drag ratios cost top speed, the highway set
  buys it back and dulls the launch.
- **Slicks** are the fastest tyre on tarmac and the worst everywhere else — they rewrite the car's
  surface table, so grass and dirt punish them.
- A **wide body kit** and a **big wing** add grip and take top speed away.
- **Weight** reduction improves acceleration, grip and braking at once, which is why it is the
  dearest ladder in the shop.
- Paint, vinyl and neon cost credits but change nothing mechanical; they are the reason to come
  back. The top neon level ("full kit") is the only one that adds visible tubes under the sills
  and bumpers as well as the pool on the road.
- **Headlights** are not just a colour: projector lenses throw a narrow 62 m beam, the LED bar a
  wide 75 m one, angel eyes ring every lamp. On a night circuit that is a handling aid.

Parts are bought once per car and then free to swap: `Garage.owned[car][slot]` is the highest level
paid for. Everyone starts with 150 000 credits.

## The city
One district, generated around whatever circuit is loaded:
- **Towers** — podium, setback tower and crown, with procedural window grids (punched, curtain wall
  or ribbon), rooftop plant, antennas and blinking aviation lights above 70 m.
- **Neon** — horizontal signs and vertical kanji-style boards on the facades facing the road, roof
  edge strips, animated billboards on poles and on the gantries; a slice of them get real lights so
  the colour lands on the road and the walls.
- **Street** — lamps with visible cones in the fog, overhead gantries, puddles, wet asphalt
  everywhere between the buildings.
- **Sky** — sodium light pollution on the horizon, stars overhead, cloud lit from below, one cold
  moon. The only directional light in the scene is that moon: everything else is the city's own.

## The circuits
- **Neon Downtown** — 1912 m. The main straight past the arcades, a flyover over the plaza, a
  tunnel under the Kaiju building, a chicane and a hairpin behind the shops. Three laps.
- **Harbour Lights** — a shorter dock loop: one long straight, a banked sweeper and a stop-start
  section between the warehouses. Four laps.

Both are closed loops of waypoints; the builder adds curbs where the curvature asks for them, LED
rails on the barriers, light gantries with screens, and turbo pads that fire the car forward
through TMNF's own pad surface.

## Controls
| action | keys | pad |
|---|---|---|
| drive / brake | W,S or ↑,↓ | triggers, A / X |
| steer | A,D or ←,→ | left stick |
| nitrous | Shift or Space | B / RB |
| respawn | Backspace | |
| restart | Enter | |
| pause | Esc | Start |

Garage: ←→ car, ↑↓ slot, `[`/`]` level, Enter fit, C cycle colour, Tab performance/look, R drive.

## Look rules
- Night, always. The sun never comes up in this game.
- Light comes from emitters that exist in the world: signs, windows, lamps, headlights, underglow.
  Ambient light stays low enough that an unlit wall reads as black.
- Glow is tuned to bite on real emitters only (HDR threshold 1.0), so the city blooms and the paint
  does not.
- Quality 0–3 scales the same scene; Ultra turns on SDFGI and SSIL, and on NVIDIA's fork the RTX
  path tracer replaces the screen-space approximations entirely.
