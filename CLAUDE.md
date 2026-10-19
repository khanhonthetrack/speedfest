# CLAUDE.md — rules for agents working on SpeedFest

SpeedFest is a time-attack racer with **TMNF-faithful physics** and a **Need for Speed Underground 2**
night-city look, built in **Godot 4.7.2**, **Forward+ only**, for PC (RTX path through NVIDIA's fork).
There is **no browser build** — it was removed on 2026-10-19 with the rest of the old game (`old/`).

## Read first
0. **`docs/HANDOFF.md`**: current state, work in progress, and how to continue (start here).
1. `docs/PLAN.md`: roadmap, milestone status, module ownership.
2. `docs/ARCHITECTURE.md`: **interface contracts** between modules (the source of truth).
3. `docs/DESIGN.md`: game design (cars, tuning, city, tracks, controls, look).
4. `docs/PROGRESS.md`: chronological log of what has been done. **Append to it.**
5. `docs/TRANSCRIPT.md`: the owner's requests, verbatim, and the answers to design questions.
6. `docs/research/tmnf_physics.md`: the reverse-engineered car model the game is built on.

## Layout
| dir | contents |
|---|---|
| `game/` | the Godot project (the former `stadium/` branch, now the game) |
| `game/core/` | TMNF tuning + car model + body integrator, and the procedural `MeshKit` |
| `game/cars/` | car definitions, tuning catalogue, the car node, procedural car models |
| `game/city/` | the night-city generator (towers, signs, props, skyline) |
| `game/track/` | track definitions and the road/neon builder |
| `game/race/`, `game/ui/` | race flow, garage, HUD, menus |
| `game/tests/` | headless labs and scene tests |
| `old/` | the archived browser-first SpeedFest. Reference only; never built or imported. |

## Persistence rule (from the owner)
Every step, plan and piece of progress must be saved to the GitHub repo
(`khanhonthetrack/speedfest`) so another agent can continue. After meaningful work:
update `docs/PROGRESS.md` (and `docs/PLAN.md` checkboxes), then commit and push.
Record new owner messages verbatim in `docs/TRANSCRIPT.md`.

## Work sequentially (owner rule, 2026-10-15)
**Don't run parallel sessions or parallel subagents.** When the account hits its usage limit, all of
their unpushed work is lost. One agent works through the plan one item at a time, commits and pushes
after every meaningful step, and records progress in `docs/PROGRESS.md` and `docs/HANDOFF.md`.

## Environment setup (fresh container)
```bash
# Godot 4.7.2. downloads.godotengine.org is blocked in some cloud environments; the GitHub release
# mirror works everywhere:
mkdir -p /opt/godot && cd /opt/godot
curl -sSL -o godot.zip "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
python3 -c "import zipfile;zipfile.ZipFile('godot.zip').extractall('.')"
chmod +x Godot_v4.7.2-stable_linux.x86_64 && ln -sf $PWD/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
# software Vulkan, so Forward+ renders under Xvfb:
apt-get update && apt-get install -y mesa-vulkan-drivers
# export templates (only for building exes): .../4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
# -> ~/.local/share/godot/export_templates/4.7.2.stable/
```

## Everyday commands
```bash
tools/godot_import.sh                       # import assets; ALSO after adding a new class_name
tools/check_scripts.sh                      # compile-check every .gd (must print SCRIPT_ERRORS=0)
tools/test_all.sh [name ...]                # every headless test scene in game/tests (TESTS PASS)
tools/run_scene.sh res://race/main.tscn -- --frames=240 --shot=/abs/out.png    # screenshot
tools/run_scene.sh res://tests/test_x.tscn --headless -- --frames=600          # logic test
```
- `run_scene.sh` forces `--fixed-fps 100` (one 100 Hz physics tick per frame), so simulation is
  deterministic regardless of the slow software renderer. Look at screenshots with the Read tool.
  They are your eyes for visuals.
- Tests print `TEST_OK name` / `TEST_FAIL name: why` and end with `TestHooks.finish()`.
- Scenes read custom args through `TestHooks.arg("track", "downtown")`.

## Code conventions
- GDScript with static typing (`var x: float`, `:=`, typed arrays where practical). Tabs for indentation.
- Use `class_name` for reusable types. Autoloads: `TestHooks`, `Settings`, `Garage`, `Game`.
- Prefer building geometry and materials **in code** (procedural). There are no binary art assets
  except fonts and generated audio. Keep generator scripts in the repo.
- Forward+ only. Scale the look with `Settings.quality` (0 low … 3 ultra/RT) and
  `Settings.tune_environment(env)`; never branch on a web renderer, there isn't one.
- Don't commit `game/.godot/`. Do commit `*.import` and `*.uid` files.
- Keep public APIs as documented in `docs/ARCHITECTURE.md`. If you must change one, update the doc
  in the same commit and note it in `docs/PROGRESS.md`.

## Git
- Main branch: `main`. Work happens on branches and is merged into `main`.
- Commit messages: `<module>: <what>`, e.g. `cars: FIA F4 single-seater model`.
