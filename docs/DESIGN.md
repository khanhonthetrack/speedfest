# SpeedFest — Game Design

> Working title **SpeedFest**. An arcade stunt/time-attack racer: the core loop of
> *Trackmania* (instant restarts, checkpoints, ghosts, time attack) mixed with the
> street-tuner style of *Need for Speed: Underground 2* (night city, neon, underglow,
> body kits, nitrous). All names, cars, tracks and art are original.

## 1. Pillars

1. **"One more run."** Instant restart and respawn, a standing start every run, checkpoint
   splits against your personal best, no loading between attempts.
2. **Tuner fantasy.** Your car is *yours*: paint, hood, kit, spoiler, rims, underglow, plate.
   Friends see your build in the race.
3. **Speed you can feel.** High speeds, strong downforce, loops and jumps, FOV kick, nitrous flames,
   speed lines, bloom.
4. **Night neon beauty.** Wet asphalt, neon reflections, glowing cars. Desktop and console get the full
   Forward+ treatment. Web gets a lighter Compatibility version that still looks good.

## 2. Game mode: Online Time Attack (v0.1's only multiplayer mode)

Confirmed by the owner: **Time Attack only**. Cars are ghosts and never collide.

- 2–8 players in a **room**. One player is the **host**: they pick the track and the round length
  (3 / 5 / 7 / 10 min, default 5) and press Start.
- **Countdown** 3-2-1-GO, synchronized to server time.
- During the round every player drives **as many runs as they like**:
  - Each run is a **standing start** at the start line.
  - The run timer starts at GO. It counts in physics ticks, so frame drops don't distort times.
  - Pass all **checkpoints** in order, then the **finish** gate. On circuit tracks the finish is the
    start line after one lap.
  - **Respawn** (Backspace / R) puts you back at the last checkpoint with the velocity you
    had when you crossed it. The timer keeps running.
  - **Restart** (Delete / Enter) starts a new run with a 1.5 s hold countdown.
  - Falling off or below the track's kill height respawns you automatically.
- Each finish sends its time to the server. Your **best** counts.
- Live **leaderboard** (Tab to expand). **Splits** at each checkpoint versus your PB:
  blue when faster, red when slower.
- When the round timer hits 0, the round ends immediately and a run still in progress doesn't count.
  **Results** screen ranks players by best time (no finish = DNF). The room returns to the lobby
  after ~12 s.
- Other players appear as **live opaque cars with name tags**. They fade out when close to your camera
  and pass straight through you. Optionally your own **PB ghost** shows as a translucent car.
- Late joiners can drop into a running round.

**Solo Time Attack** (offline practice): pick a track, no time limit, with your PB ghost. PBs are saved
locally per track.

## 3. Cars (3 originals)

| id | Name | Archetype | Drive | Personality |
|---|---|---|---|---|
| `kaze` | **Kaze RS** | JDM tuner coupe (pop-up-lamp-era rotary-coupe vibe, original design) | RWD | Light and rev-happy. Easiest to drift. Balanced. |
| `brute` | **Brute V8** | American muscle (long hood, fastback, wide hips) | RWD | Huge torque and acceleration. Heavy, loose rear, great nitro. |
| `veloce` | **Veloce GT** | Euro mid-engine supercar (low wedge, big intakes) | AWD | Highest grip and top speed. Stable, least drifty. |

All three are competitive and **easy to drive** (owner, session 4: "Remove tuning, it's too
complicated. Make handling easy (but different for different cars)"). There is **no performance
tuning** any more: every car drives stock, and the cars differ by their stock character:

| car | handling character |
|---|---|
| Kaze RS | lightest and quickest to turn; slides grow into drifts most easily on throttle (`power_oversteer` 0.4), lively stability assist (`yaw_damp` 1.0) |
| Brute V8 | heavy, huge acceleration and the biggest nitro tank; neutral rear grip now (no snap oversteer), firmer assist (1.2) |
| Veloce GT | AWD grip and the highest top speed; no power oversteer, firmest assist (1.3) |

Easy handling = slides happen when you ask for them (handbrake, or brake + steer for a brake drift)
and a hands-off stability assist catches the tail stepping out when you aren't steering. Measured by
`tests/physics/test_easy.tscn` (keyboard flick, slalom, full lock).

### 3.1 Performance tuning (removed in session 4; kept for reference)
The physics code still supports these sliders (`Tuning.physics_params`), but `Profile.get_config()`
always returns 0 for all of them and the garage has no tuning UI.

| key | −1 | +1 |
|---|---|---|
| `gearing` | acceleration | top speed |
| `turbo` | low-end torque | top-end power |
| `downforce` | low drag (top speed) | grip in corners |
| `suspension` | soft (absorbs bumps, more roll) | stiff (responsive, twitchy over bumps) |
| `balance` | planted/understeer | loose/oversteer (drift-friendly) |
| `steering` | stable, slower | sharp, faster |
| `nitro` | long and gentle | short and strong |

The garage shows each car's stock stat bars (Top Speed, Acceleration, Handling, Drift, Nitro), plus a
top speed in km/h and an estimated 0–100 time.

### 3.2 Visual tuning (NFSU2 style)

- **Paint**: body color plus finish (`gloss`, `metallic`, `pearl`, `matte`, `chrome`).
- **Livery**: `none`, `racing_stripes`, `side_stripe`, `two_tone`, `fade`, `checker`, using an
  **accent** color.
- **Hood**: 4 variants (stock, vented, scoop, race/twin-scoop) plus a **carbon** toggle.
- **Body kit**: front bumper, rear bumper, side skirts, 3 variants each (stock, street, race).
- **Spoiler**: 5 variants (none, lip, ducktail, GT wing, high wing).
- **Rims**: 5 designs, rim color, brake caliper color.
- **Underglow**: color plus mode (`off`, `static`, `pulse`, `strobe`, `rainbow`). It lights the ground
  under the car.
- **Window tint** amount, **headlight** color, **ride height**, and a **license plate** text (≤ 8 chars).

## 4. Tracks: three Trackmania-style stunt tracks and two ground sprints

> **Owner decision (2026-10-15):** *all three* tracks are Trackmania-style stunt tracks. The
> themes stay as the **setting** around the track. Must-haves: floating roads and big jumps, loops and
> wall rides, turbo pads and boosters, and short, tight 30–45 s tracks. (The first version had only one
> stunt track; downtown and coast were a normal street circuit and a highway sprint. That was a
> misunderstanding.)

Common style ("platform" roads, like Trackmania's stadium blocks):
- Roads float in the air on slim pillars, with neon edge strips and low curbs. Edges are mostly
  **open**: falling off is the penalty and respawns you at the last checkpoint within ~1.5 s. Walls
  only where fairness needs them (banked walls, wall rides).
- Every track packs stunts into 30–45 s with 4–6 checkpoint arches. Pieces: **turbo pads** (yellow
  boost, red super boost), launch ramps and **big gap jumps** between platforms, a **vertical loop**,
  a **wall ride** (road rolled to ~80–90° along a curve), banked turns and half-pipe walls, drops, and a
  final jump through the finish arch.
- Each track has its own character and doesn't repeat the others' pieces in the same order.

| id | Name | Setting (theme) | Stunt identity | Target time |
|---|---|---|---|---|
| `downtown` | **Neon Downtown** | Rainy neon night city. The track runs at rooftop height between and over skyscrapers | Rooftop gap jumps, a wall ride along a building face, a loop around a giant neon sign, a dive between towers | ~35–45 s |
| `arena` | **Pulse Arena** | Night stunt stadium: neon stands, floodlights, giant screens | Classic stadium: start ramp, turbo straight, loop, wall ride, banked half-pipe turn, big final jump | ~30–40 s |
| `coast` | **Sunset Coast** | Dusk cliffs, sea and palms. The track hangs over the cliffs and the bay | A huge jump across the bay, a wall ride along a cliff face, a loop on a headland, fast banked sweepers, a drop to the finish | ~35–45 s |

Roads are wide (14–20 m on platforms). Every stunt must be makeable by a keyboard player at
a sensible speed (verified with the keyboard-emulation test). Turbo pads tell you where full speed is needed.

**Sprints (owner, session 4: "2-3 short maps (around 10s) on the stadium or the coast which actually
use grass, or gravel or sand").** Two ~12 s maps whose twist is the ground, not stunts. Ground patches
lie on the road and change grip and rolling drag (TrackSurface `KIND_GRIP` / `KIND_DRAG`):

| ground | grip | drag | feel |
|---|---|---|---|
| grass | x0.74 | light | slides a bit, keeps speed: a fair short cut |
| gravel | x0.62 | medium | loose: brake, turn in, let it drift |
| sand | x0.68 | heavy | bogs you down: fly over it or lose seconds |

| id | Name | Setting | The choices |
|---|---|---|---|
| `infield` | **Infield Rush** | Stadium lawn at night | Banked 120° whose inside half is grass (short line, less grip) vs. the asphalt outside (long line, full grip; in rain it has a puddle). A full-width gravel flick. A kicker over a sand trap: carry speed or land in the sand. |
| `dunes` | **Dune Dash** | Beach at dusk | A sweeper with loose sand on the inside (cut it, heavy drag) or the boardwalk outside. A dune jump with a sand landing. A banked gravel bend. A clifftop straight with grass verges into the finish jump. |

Weather stacks with the ground (wet gravel is the worst). Rain and storm add puddles on the asphalt lines.

### 4.1 Weather: our twist on Trackmania (owner request, 2026-10-15)

> Owner: *"consider weather and how this can be different from trackmania. E.g. when in the rain,
> there are puddles which makes cars slide more. Include this in the stage design."*

In Trackmania a track's surfaces are fixed: a block is road, dirt, grass, ice or water forever.
Here **weather is a round setting**, so the same stage plays three ways. The host picks it in
the lobby. Solo players pick it on the track card ("Auto" means the stage's signature weather).

| Weather | Asphalt grip | Puddles | Looks and sound |
|---|---|---|---|
| **Dry** | 100% | none, they've dried up | the stage's normal light |
| **Rain** | 94% everywhere | the stage's rain puddles fill (grip ×0.5 in the middle, small water drag) | rain streaks, wet glossy road, rippling puddles, tire spray, rain ambience. Arena and coast get darker and foggier |
| **Storm** | 90% everywhere | rain puddles grow ~30% **plus storm-only puddles** (grip ×0.42) | heavier, slanted rain, lightning flashes that light up the world, thunder |

**Puddles are stage design, not decoration.** Each one is placed by hand in the layout
(`{"puddle": len, "w": width, "x": lateral, "at": offset, "storm": bool}`) as a **line choice**:
- the **dry line** is longer or tighter, or the **wet line** is faster if you keep the car straight,
  because a puddle mostly punishes steering, braking and throttle while you're in it (aquaplaning);
- water collects where it would in real life: apexes and the bottoms of banked turns, landing
  zones, runoff on downhill dives;
- **never** on a kicker, loop, wall ride or boost pad (tested): weather must never make a stunt
  impossible, only make the line around it matter;
- puddles read at speed: dark mirror water, a bright rim, rain ripples and a fake reflection of the
  stage's lights (real SSR reflections on Forward+).

Stage by stage:
- **Neon Downtown** (signature weather **rain**): a "rooftop pool" on the turn-in line of the
  first right-hander after the gap jump; a flooded apex in that turn; a **dive slalom**, with
  puddles alternating sides down the tower dive (thread the dry centre or drive straight through);
  in a storm, runoff on the last banked exit and standing water before the final super boost.
- **Pulse Arena** (signature **dry**): a stadium-floor pool on the outside line into the first
  banked 90; water at the bottom of the banked half-pipe. Storm adds a flooded gap-jump landing and
  the half-pipe's outside line.
- **Sunset Coast** (signature **dry**): both fast-sweeper apexes hold water; a pool on the turn-in
  line before the left 70. Storm adds water on the bay-jump landing and runoff down the final drop.

Fairness and records: weather is the **same for everyone in a round** (it comes with `round_start`).
**PBs and PB ghosts are kept per stage *and* weather** (`arena@rain`), so a wet run never competes
with a dry one.

Future weather ideas (not built yet): crosswind gusts on the coast bay jump (air drift),
coast fog banks, a drying line (puddles shrink over a long round after the rain stops),
night/day per round, a snow/ice winter stage.

## 5. Controls (keyboard first; gamepad also mapped)

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / ↑ | RT / R2 |
| Brake / reverse | S / ↓ | LT / L2 |
| Steer | A D / ← → | Left stick, D-pad |
| Handbrake (drift) | Space | B / Circle |
| Nitro | Shift / N | A / Cross |
| Respawn at checkpoint | Backspace / R | Y / Triangle |
| Restart run | Delete / Enter | Back / Select |
| Camera | C | RB |
| Look back | Q | LB |
| Leaderboard | Tab (hold) | — |
| Pause | Esc / P | Start |

Keyboard steering is smoothed: ramp speed depends on vehicle speed, and steering self-centers.

## 6. Camera and game feel

- Chase camera (near/far), bumper camera, and hood camera. The chase camera lags behind on a spring.
- FOV widens with speed, with an extra kick when nitro fires. Subtle shake at very high speed and on landings.
- Speed lines and a radial-blur overlay above ~200 km/h (desktop quality ≥ High).
- Exhaust flames and a blue nitro plume. Tire smoke when drifting. Sparks on wall scrapes.

## 7. HUD (NFSU2-inspired)

- Bottom-right: tachometer arc, digital speed, gear, nitro bar (compact, 70% scale). No minimap (owner: "no one cares").
- **Nitro is a fixed tank per run** (owner, session 4): it never refills while driving, so when to
  spend it is a strategic choice. Respawn keeps the current amount; restart refills.
- Top-center: run time, checkpoint counter, split pop-ups (blue/red), round time left (online).
- Top-right: live leaderboard (rank, name, best).
- Center: countdown, "CHECKPOINT", "FINISH", "NEW PB!" banners.
- Angular, skewed panels with neon edges. Orbitron for numbers and headings, Rajdhani for labels.
- Palette: cyan `#00E5FF`, magenta `#FF2BD6`, amber `#FFB300`, lime `#A6FF00` on deep navy `#070B1A`.

## 8. Audio

All sounds are synthesized by our own scripts, so there are no licensing issues:
- Engine: layered loops crossfaded and pitch-shifted by RPM, with a separate sound per car (high rotary
  buzz, V8 rumble, flat-plane V12-like scream).
- Turbo whistle and blow-off, nitro whoosh, tire squeal, wind rush, landing thud, wall scrape.
- UI clicks, checkpoint chime, countdown beeps, finish fanfare.
- A short synthwave menu loop and an in-race loop.

## 9. Platforms

- **v0.1: Web** (desktop Chrome/Edge/Firefox, keyboard) for the first game night. Uses the Compatibility renderer.
- Desktop builds (Windows/Linux/macOS) use Forward+ at full quality and join the same servers.
- **Nintendo Switch / Switch 2**: the end goal. See `docs/SWITCH.md`.

## 10. Out of scope for v0.1 (future ideas)

Track editor (Trackmania's heart), replays and ghost sharing, more environments and cars, car
collisions mode, lap races, campaigns with medals (bronze/silver/gold/author), progression and unlocks,
split-screen (great for Switch), touch controls.
