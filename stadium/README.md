# SpeedFest Stadium: a TMNF Stadium remake in Godot 4.7 (Forward+)

Owner request (session 9, docs/TRANSCRIPT.md): build, in a separate folder, a copy of TrackMania
Nations Forever "as close to the original as possible" (graphics, car feel, textures) on an enhanced
Godot. ManiaPlanet parts are out of scope.

Owner decisions (2026-10-16):
- **Assets: recreate only.** Every model, texture and sound here is our own, made in the TMNF style.
  No Nadeo files (meshes, textures, sounds, packs, decompiled code) are ever committed or shipped.
- **Tracks:** the official campaign and any `.Challenge.Gbx` (TMX downloads) are read **at runtime**
  from files the player owns (their TMNF install, their downloads) and drawn with our recreated
  blocks. They are never committed. Plus our own TM-style maps.
- **Engine:** Godot 4.7 Forward+ with high-end settings (an RTX fork may come later).

## Physics
The car is TMNF's force model 6 with the real tuning `20juin2006`, from our reverse engineering
(docs/research/tmnf_physics.md; numbers and behaviour only):
- `core/tm_tuning.gd` (`TmTuning`): every constant and curve, with its tuning offset.
- `core/tm_car_model.gd` (`TmCarModel`): one 10 ms tick of the handling (steering, side grip, yaw,
  drive/brake, slopes, walls, turbo, dirt, air), engine independent. SpeedFest's car uses the same
  model (task: TMNF handling as SpeedFest's default).
- Planned: `car/tm_car.gd`, a custom 100 Hz body (not RigidBody3D) with collision sub-steps of at
  most 0.3 m, ellipsoid wheels and chassis, and TMNF's contact impulses; Jolt is used for queries.

## Layout
| dir | contents |
|---|---|
| `core/` | tuning + car model (shared with SpeedFest) |
| `car/` | car body, visuals, camera (planned) |
| `gbx/` | `.Challenge.Gbx` reader: header, medals, LZO body, blocks (planned) |
| `blocks/` | recreated Stadium block library on the 32 × 8 × 32 m grid (planned) |
| `race/`, `ui/`, `env/` | race flow, menus, stadium environment (planned) |
| `tests/` | headless labs and scene tests |
| `tools/run.sh` | run a scene (100 fps fixed, Forward+ under Xvfb, or `--headless`) |

## Run
```bash
godot --headless --path stadium --import                         # once, and after a new class_name
stadium/tools/run.sh res://tests/test_model_lab.tscn --headless  # car model vs the reference (44 checks)
```
