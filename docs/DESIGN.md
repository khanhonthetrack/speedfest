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

All three are competitive. Tuning moves each one along trade-offs instead of making it strictly better.

### 3.1 Performance tuning ("Dyno" sliders, each −1 … +1, 0 = stock)

| key | −1 | +1 |
|---|---|---|
| `gearing` | acceleration | top speed |
| `turbo` | low-end torque | top-end power |
| `downforce` | low drag (top speed) | grip in corners |
| `suspension` | soft (absorbs bumps, more roll) | stiff (responsive, twitchy over bumps) |
| `balance` | planted/understeer | loose/oversteer (drift-friendly) |
| `steering` | stable, slower | sharp, faster |
| `nitro` | long and gentle | short and strong |

The garage shows live stat bars (Top Speed, Acceleration, Handling, Drift, Nitro), plus a top speed in
km/h and an estimated 0–100 time.

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

## 4. Tracks (3 originals): Trackmania-style stunt tracks

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

- Bottom-right: tachometer arc, digital speed, gear, nitro bar.
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
