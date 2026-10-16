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
- `core/tm_body.gd` (`TmBody`) and `car/tm_car.gd` (`TmCar`): a custom 100 Hz body (not RigidBody3D)
  with collision sub-steps of at most 0.3 m, ellipsoid wheels and chassis, and TMNF's contact
  impulses; Jolt is used for queries only.

## Layout
| dir | contents |
|---|---|
| `core/` | tuning + car model (shared with SpeedFest) |
| `car/` | car body, input, visuals (placeholder), chase camera |
| `gbx/` | `.Challenge.Gbx` reader: header, medals, LZO body, blocks |
| `blocks/` | recreated Stadium block library on the 32 × 8 × 32 m grid: catalogue (layout data), placement, map builder, shape families in `blocks/shapes/` |
| `race/` | race rules (`TmRace`), waypoint triggers (`TmTriggers`), race scene + HUD, map viewer, drive test |
| `ui/`, `env/` | menus, stadium environment (planned) |
| `tests/` | headless labs and scene tests |
| `tools/run.sh` | run a scene (100 fps fixed, Forward+ under Xvfb, or `--headless`) |

## Play it (A01 and the rest of the campaign)
1. Install TrackMania Nations Forever (free, from Ubisoft/Nadeo or Steam): the remake reads the
   official tracks from your own install and never ships them.
2. Install Godot 4.7.2, clone this repo, check out branch `stadium`, open `stadium/project.godot`
   and press Play (F5). It finds TMNF in its usual install folder and starts A01.
   Elsewhere: run with `-- --tmnf="D:/Games/TmNationsForever"`, or set `TMNF_DIR`.
   Another track: `-- --track=B05`; any track file: `-- --map="C:/path/X.Challenge.Gbx"`.
3. Keys: arrows / WASD (or a pad) to drive, Enter respawns at the last checkpoint,
   Backspace / Delete restarts.
4. Your best time per track and its ghost are saved (Godot's user folder, `records/`; another
   folder with `-- --records=<dir>`). From the next attempt the record's ghost races with you,
   and every checkpoint shows the difference to the record (blue ahead, red behind).
Not there yet: our own car model (a placeholder body), textures (flat colours), sounds, menus.

## Continue the work
Agents: read `stadium/CLAUDE.md`. The TMNF install and measurements are recreated locally with
`tools/research/tmnf/setup_measurements.sh` (never committed).

## Run
```bash
godot --headless --path stadium --import                         # once, and after a new class_name
stadium/tools/run.sh res://tests/test_model_lab.tscn --headless  # car model vs the reference (44 checks)
TMNF_DIR=/path/to/TmNationsForever stadium/tools/test_all.sh     # every lab (STADIUM_TESTS PASS)
stadium/tools/run.sh res://race/race.tscn --realtime -- --tmnf=/path/to/TmNationsForever --track=A01
                                         # play a campaign track (or --map=/path/X.Challenge.Gbx)
stadium/tools/run.sh res://race/map_view.tscn -- --tmnf=/path/to/TMNF --track=A01 --shot=/abs/out.png
```
Race keys: arrows/WASD (or a pad) drive, Enter respawns at the last checkpoint, Backspace/Delete
restarts.
