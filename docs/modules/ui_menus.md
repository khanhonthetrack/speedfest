# ui_menus — menus, garage, lobby

Branch: `module/ui_menus`. All screens are built in code on top of the core `UITheme`
(`game/ui/ui_theme.gd`, not edited). Scene files are a bare `Control` + script.

## File map
| file | what |
|---|---|
| `game/ui/main_menu.tscn/.gd` | Logo, Solo / Online / Garage / Settings / Quit (Quit hidden on web), 3D showroom backdrop of the selected car (drag to spin), first-run name dialog, driver name + CHANGE. |
| `game/ui/track_select.tscn/.gd` | Three track cards with procedural poster art, theme, circuit/sprint, blurb, target time, your PB → `Game.start_solo(id)`. Focusing a card sets `Game.track_id`. |
| `game/ui/garage.tscn/.gd` | 3D preview (auto-rotate, mouse drag orbit, wheel zoom, per-tab camera presets), car picker, tabs TUNE / PAINT / BODY / WHEELS / LIGHTS / PLATE, live stat panel, Reset look / Reset tuning, DONE → `Game.leave_garage()`. |
| `game/ui/online_lobby.tscn/.gd` | Connect view (name, server URL) → room browser (auto-refreshing list, create, join by code, name, garage) → room view (players with host/you/ready badges and best, host track + round-length chips, ready toggle, START, chat, garage, leave, "join the running round"). |
| `game/ui/settings_menu.tscn/.gd` | Quality, render scale, fullscreen + vsync (not web), FPS, PB ghost, units, camera, master/music/sfx volume, server URL, controls reference. Live `Settings.apply()`, saved on Back/Esc. |
| `game/ui/menu/menu_kit.gd` | `MenuKit`: buttons (mouse hover = focus), focus sounds, headers, captions, panels, chip rows, color swatch rows + ColorPicker popup, slider rows, key hints, backdrop. |
| `game/ui/menu/menu_backdrop.gdshader` | Animated synthwave grid/horizon backdrop (canvas_item, both renderers). |
| `game/ui/menu/showroom.gd` | `Showroom` Node3D: glossy floor, neon turntable, light strips for paint reflections, key + 2 rim lights (3 lights total), orbit camera, `show_car`, `focus_view`, `orbit_drag`, `zoom`. |
| `game/ui/menu/track_art.gd` | `TrackArt`: `_draw` posters for city / arena / coast. |
| `game/ui/menu/stat_bar.gd` | `StatBar`: segmented skewed bar with a stock-value tick. |
| `game/tests/ui_menus/*` | tests (below). |

## Behaviour notes / decisions
- **Lobby starts the race**: on `Net.round_started` it calls `Game.start_online_round(info)` (once).
  The **garage also does this when you're in a room**, so a player tuning their car doesn't miss
  the start (it saves and pushes the profile first).
- Lobby auto-connects on entry when offline (`Settings.resolve_server_url()` or the URL field).
  A typed URL different from the automatic one is stored in `Settings.server_url`.
- Coming back from a race/garage while in a room shows the room view right away. If the room is
  in `countdown`/`racing` and `Net.current_round` is set, a **JOIN THE RUNNING ROUND** button appears.
- Esc in the room view does **not** leave the room (too easy to hit by accident); it moves focus to
  LEAVE ROOM, a second Esc leaves. Esc elsewhere goes back to the main menu (leaving the room).
- The host can START any time in phase lobby/results; the button shows "(n/m ready)". Ready is
  informational (the server doesn't require it).
- Chat history is a static var keyed by room code, so it survives race/garage round trips.
  Player text is BBCode-escaped.
- First run = `user://profile.json` doesn't exist → name dialog (skipped under TestHooks args
  unless `--name_prompt`). Closing it saves the profile.
- Garage changes call `Profile.set_tuning/set_style/set_selected_car` immediately and save after a
  1 s debounce (web: survives closing the tab). Tuning values snap to 0.1. Plate goes through
  `CarDefs.sanitize_plate` on every keystroke.
- Garage keys: Q/E (or PgUp/PgDn, LB/RB) switch tabs, Z/X switch car, drag orbits, wheel zooms.
- Settings menu has `static var return_scene` (default main menu).

## Tests
```bash
tools/run_scene.sh res://tests/ui_menus/garage_test.tscn --headless -- --frames=600       # 17 checks
tools/run_scene.sh res://tests/ui_menus/lobby_fake_test.tscn --headless -- --frames=600 --lobby_no_autoconnect  # 19 checks
game/tests/ui_menus/lobby_smoke.sh 3      # real server + 3 headless clients press the real lobby buttons → race (PASS)
game/tests/ui_menus/screenshots.sh [dir]  # every screen + every garage tab, Forward+ and Compatibility
```
`lobby_driver.tscn` drives the lobby UI (`--role=host|guest --url=... --room=... --players=N`,
`--stay=1` to idle in the room for screenshots).

## API additions (beyond the contract)
- `MenuKit`, `Showroom`, `TrackArt`, `StatBar` classes (above).
- Lobby: `show_view(name)`, `current_view`, public button/field vars used by tests.
- Garage: `select_car(id)`, `set_tuning_value(key, v)`, `set_style_value(key, v)`, `reset_tuning()`, `reset_style()`.
- Showroom calls `CarVisual.set_headlights_real(false)` if the method exists.

## Known issues
- Screenshots used the stub `CarVisual` (a box) and stub `Tuning.stats` (all bars equal); camera
  presets may need a small distance tweak once real car meshes land.
- `Audio` is a stub here, so sounds were not heard; calls are `play_ui("hover"/"click"/"back"/"confirm"/"error")`
  and `play_music("menu")`.

## Integration requests
- None required. Nice to have: `Game.SCENE_SETTINGS` is already used; if the pause menu wants the
  full settings screen it can set `SettingsMenu.return_scene` (script static) before `Game.goto`.
