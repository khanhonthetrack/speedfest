# CLAUDE.md — rules for agents working on SpeedFest

SpeedFest is a Trackmania-style time-attack racer with a Need for Speed Underground 2 vibe,
built in **Godot 4.7.2**. The web build comes first; Nintendo Switch / Switch 2 is the long-term target.

## Read first
1. `docs/PLAN.md`: roadmap, milestone status, and who owns which files.
2. `docs/ARCHITECTURE.md`: **interface contracts** between modules (the source of truth).
3. `docs/DESIGN.md`: game design (modes, cars, tuning, tracks, controls, look).
4. `docs/PROGRESS.md`: chronological log of what has been done. **Append to it.**
5. `docs/TRANSCRIPT.md`: the owner's requests, verbatim, and the answers to design questions.

## Persistence rule (from the owner)
Every step, plan and piece of progress must be saved to the GitHub repo
(`khanhonthetrack/speedfest`) so another agent can continue. After meaningful work:
update `docs/PROGRESS.md` (and `docs/PLAN.md` checkboxes), then commit and push.
Record new owner messages verbatim in `docs/TRANSCRIPT.md`.

## Environment setup (fresh container)
```bash
# Godot 4.7.2 editor + export templates. downloads.godotengine.org is blocked in some cloud
# environments; the GitHub release mirror works everywhere:
mkdir -p /opt/godot && cd /opt/godot
curl -sSL -o godot.zip "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
python3 -c "import zipfile;zipfile.ZipFile('godot.zip').extractall('.')"
chmod +x Godot_v4.7.2-stable_linux.x86_64 && ln -sf $PWD/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
# templates (~1.2 GB; curl -C - resumes): .../4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz, unzip web_* and
# linux_*/windows_* into ~/.local/share/godot/export_templates/4.7.2.stable/
# software Vulkan, so Forward+ renders under Xvfb:
apt-get update && apt-get install -y mesa-vulkan-drivers
```

## Everyday commands
```bash
tools/godot_import.sh                       # import assets; ALSO after adding a new class_name (registers it)
tools/check_scripts.sh                      # compile-check every .gd (must print SCRIPT_ERRORS=0)
tools/run_scene.sh res://path/scene.tscn -- --frames=120 --shot=/abs/out.png    # Forward+ screenshot
tools/run_scene.sh res://path/scene.tscn --compat -- --frames=120 --shot=/abs/out.png  # web renderer
tools/run_scene.sh res://tests/x/test.tscn --headless -- --frames=600          # logic test
tools/integration/check_all.sh [--quick]    # integration gate: compile + every test suite + server tests
                                            # + AutoDriver finishes all tracks + online rounds (CHECK_ALL PASS)
tools/export_web.sh                         # web build -> server/public (committed)
cd server && npm install && npm start       # local server on :8080 (serves game + /ws)
cd server && npm test                       # server unit tests
tools/net_smoke_test.sh                     # 3 headless Godot clients play an online round
NODE_PATH=$(npm root -g) node tools/integration/online_browser_test.js http://127.0.0.1:8090 /abs/out 3 arena 45
                                            # N headless Chromium clients vs a running server (PUBLIC_DIR=web export)
```
- `run_scene.sh` forces `--fixed-fps 60`, so simulation is deterministic regardless of the slow
  software renderer. Look at screenshots with the Read tool. They are your eyes for visuals.
- Tests print `TEST_OK name` / `TEST_FAIL name: why` and end with `TestHooks.finish()`.
- Scenes read custom args through `TestHooks.arg("track", "arena")`.

## Code conventions
- GDScript with static typing (`var x: float`, `:=`, typed arrays where practical). Tabs for indentation.
- Use `class_name` for reusable types. Autoloads: `Settings`, `Profile`, `Game`, `Net`, `Audio`, `TestHooks`.
- Prefer building geometry and materials **in code** (procedural). There are no binary art assets
  except fonts and generated audio. Keep generator scripts in the repo.
- Must run on **both** renderers: Forward+ (desktop/console) and Compatibility (web). Branch on
  `Settings.is_compat()` and `Settings.quality`. Use `Settings.tune_environment(env)`.
- Don't commit `game/.godot/`. Do commit `*.import` and `*.uid` files.
- Keep public APIs as documented in `docs/ARCHITECTURE.md`. If you must change one, update the doc
  in the same commit and note it in `docs/PROGRESS.md`.
- Only edit files your module owns (see `docs/PLAN.md` ownership table) unless you are integrating.

## Git
- Main branch: `main`. Module work happens on branches and is merged into `main`.
- Commit messages: `<module>: <what>`, e.g. `cars: arcade raycast suspension`.
