# SpeedFest

An arcade **time-attack racer** with TrackMania-faithful handling and the street-tuner night vibe of
**Need for Speed Underground 2**. Built with **Godot 4.7.2**, Forward+ only, PC first (an RTX path
exists through NVIDIA's Godot fork). The world is a **neon city at night**.

The game is built on the Stadium branch: the car is TMNF's force model 6 with the `20juin2006`
tuning, reverse engineered in `docs/research/tmnf_physics.md` and implemented in `game/core/`.

- **Garage with 5 cars** — an FIA F4 single-seater, two sportscars, a Polonez-style classic and an
  offroad truck. Each has its own specs (top speed, acceleration, grip, boost gain, weight).
- **Tuning, NFSU2 style** — ten-plus slots per car: engine, turbo, tyres, brakes, suspension,
  gearbox, weight, body kit, spoiler, rims, paint & finish, vinyl, neon underglow, headlights, tint.
- **Night city tracks** — procedural downtown with tall towers, animated billboards, neon tube
  barriers, wet reflective asphalt, volumetric fog and light shafts.

> Status: under construction. Start at [docs/HANDOFF.md](docs/HANDOFF.md).

## Develop
Open `game/project.godot` in Godot 4.7.2. Agents and contributors: read [CLAUDE.md](CLAUDE.md) first.

```bash
tools/godot_import.sh                                            # import assets / register class_names
tools/check_scripts.sh                                           # compile-check every .gd
tools/test_all.sh                                                # every headless test scene
tools/run_scene.sh res://race/main.tscn                          # play (Xvfb + software Vulkan here)
```

## `old/`
Everything from the previous, browser-first SpeedFest (its Godot project, the node server and its
tooling) is archived under [`old/`](old/README.md). The browser build itself is gone: the game is a
PC title now.
