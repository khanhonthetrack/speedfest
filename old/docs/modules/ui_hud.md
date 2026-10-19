# ui_hud: HUD, pause menu, results

Branch: `module/ui_hud`. Status: complete for M1, tested on both renderers at 1280×720 and 1920×1080.

## What's built
- **HUD** (`res://ui/hud.tscn`, `hud.gd`, CanvasLayer layer 5), the full ARCHITECTURE.md contract, NFSU2 style:
  - bottom-right: `HudTachometer` has 40 LED segments on a 270° arc (cyan→magenta, red past the 84 % redline),
    0–9 tick numbers, a needle, big digital speed with neon glow (magenta pulse during nitro), KM/H or MPH,
    a gear box (R/N/1–6, flashes amber/red at the redline, lime flash on upshift), and a 16-cell NOS bar that pulses while active;
  - top-center: `HudTimerPanel` shows the run time (Orbitron 900 in fixed-width cells, so the digits don't jitter),
    `CP n/m`, `BEST`, and the online round clock tab (amber ≤ 30 s, flashing red ≤ 10 s). The run time
    flashes blue or red on splits and magenta on a PB;
  - below it: `HudSplitPopup` shows `CP n  0:23.456  [-0.123]` with a blue block when faster and a red one when slower;
  - top-right: `HudLeaderboard` with medal-colored rank chips and my row highlighted. Compact mode shows the top 5,
    or the top 4 plus my row. Holding `leaderboard` (Tab) expands it to everyone (max 16). Hidden while empty (solo);
  - center: the countdown 3-2-1 (red/amber/cyan, slams in) and GO! (lime, zooms out); a CHECKPOINT banner;
    FINISH with the time and delta on a skewed light band; NEW PB! (elastic pop, magenta/amber blink);
    and `show_message` toasts at 70 % height;
  - bottom-left: `HudMinimap` fits the centerline into a 260×190 box and picks the rotation that makes the
    track largest (it stays unrotated unless rotating gains > 8 %). It draws a start/finish tick, other cars
    as colored dots, and the local car as a pulsing lime dot;
  - overlay: `ui_speed_lines.gdshader`, radial streaks plus a vignette from 200 km/h (full at 330 km/h),
    tinted pink while nitro is on, only when `Settings.quality >= 2`. The node is hidden when idle (no fill cost);
  - an FPS counter (top-left) when `Settings.show_fps`. It follows `Settings.changed`.
- **Pause menu** (`pause_menu.tscn`, layer 10, `PROCESS_MODE_ALWAYS`): RESUME, RESTART RUN, SETTINGS (inline
  panel with master/music/effects sliders and a camera-mode dropdown; changes apply live and are saved on close),
  and QUIT TO MENU / QUIT TO LOBBY. Solo pauses the tree. Online it doesn't, and an amber hint says so.
  Esc/P (`pause`) or `ui_cancel` closes the settings panel, then resumes. The press that opened the menu is ignored.
  Gamepad and keyboard focus start on RESUME.
- **Results** (`results.tscn`, layer 9): a ranked table (POS, DRIVER, CAR, BEST, RUNS). Gold, silver and bronze
  edge bars mark the top 3, DNF rows go last with "NO TIME", and my row is cyan with "(YOU)". It shows up to
  10 rows, and my row is always included. The subtitle says "YOU FINISHED P2 OF 6". The entrance is
  animated (dim fade, title slide, staggered rows), with a "RETURNING TO LOBBY IN N" countdown footer.

## Performance
Setters only store values. A gauge redraws (`queue_redraw`) only when its *visible* value changes. Time and
speed digits are codepoint arrays (`PackedInt32Array`, resized in place) drawn with `Font.draw_char`,
so there is no String formatting per tick. The rpm LEDs are a single `draw_multiline_colors` call.
Measured: **~6 µs per tick** for the full setter set (headless), with no node or object churn over 3000 ticks.
Tweens only run on events (countdown, splits, banners).

## File map
| file | what |
|---|---|
| `game/ui/hud.gd`, `hud.tscn` | HUD root, contract API, layout, center banners/toasts, speed lines |
| `game/ui/hud/hud_text.gd` | `HudText`: allocation-free tabular digit drawing, skewed quads |
| `game/ui/hud/tachometer.gd` | `HudTachometer` |
| `game/ui/hud/timer_panel.gd` | `HudTimerPanel` |
| `game/ui/hud/split_popup.gd` | `HudSplitPopup` |
| `game/ui/hud/leaderboard.gd` | `HudLeaderboard` |
| `game/ui/hud/minimap.gd` | `HudMinimap` |
| `game/ui/hud/banner_band.gd` | `HudBannerBand` (light band behind center banners) |
| `game/shaders/ui_speed_lines.gdshader` | speed-lines overlay |
| `game/ui/pause_menu.gd`, `.tscn` | pause menu |
| `game/ui/results.gd`, `.tscn` | results overlay |
| `game/tests/ui_hud/hud_demo.*` | visual demo with fake data |
| `game/tests/ui_hud/test_hud.*` | headless logic and perf test |

## API additions (beyond ARCHITECTURE.md)
- HUD: `clear_banners()` hides the countdown, banners and split pop-up. `set_hud_visible(v: bool)` hides the whole HUD (e.g. under results).
- HUD `set_minimap_cars(local_pos, others)`: each element of `others` can be a `Vector2` or `{"pos": Vector2, "color": Color}`.
- Pause menu: `is_open() -> bool`. If nothing is connected to `quit_requested`, it calls `Game.to_lobby()` or `Game.to_menu()` itself.
- Results: `hide_results()` (also re-shows sibling HUDs), and `return_seconds: float = 12.0` (set it before `show_results` to change the countdown).
  `car` in a row can be an id string (as the server sends it) or a CarConfig dict.

## Notes for the race module (how to drive it)
- The split pop-up's "CP n" follows `set_checkpoints`, in either call order.
- `show_countdown(3)` also clears any FINISH banner left over from the previous run. `show_countdown(-1)` hides it.
- `show_finish` holds about 3 s, which matches the 2.5 s FINISHED state.
- `show_results` hides sibling HUDs automatically (any sibling node with `set_hud_visible`) and `hide_results` restores them.
- The pause menu consumes the Esc that closes it (`set_input_as_handled`). The race should open it with
  `pause` in `_unhandled_input` and skip that if `pause_menu.is_open()`.

## How to test
```bash
tools/run_scene.sh res://tests/ui_hud/test_hud.tscn --headless -- --frames=2000      # 31 TEST_OK
S=/abs/dir
tools/run_scene.sh res://tests/ui_hud/hud_demo.tscn -- --frames=780 --shots=$S/a.png@20,$S/b.png@345,$S/c.png@600,$S/d.png@775
tools/run_scene.sh res://tests/ui_hud/hud_demo.tscn --compat -- --show=results --frames=150 --shot=$S/results.png
tools/run_scene.sh res://tests/ui_hud/hud_demo.tscn -- --show=pause --settings=1 --frames=40 --shot=$S/pause.png
# extra demo args: --online=false (solo look), --expand=true (hold Tab), --quality=1 (no speed lines)
```

## Tuning knobs
- `hud.gd`: `SPEED_LINES_FROM` and `SPEED_LINES_FULL` (km/h).
- `tachometer.gd`: `REDLINE` (0..1), `SEGMENTS`, `NITRO_CELLS`.
- `leaderboard.gd`: `COMPACT` (5), `MAX_ROWS` (16).
- `results.gd`: `MAX_ROWS` (10), `return_seconds`.

## Known issues
- The tachometer tick labels read 0–9 ×1000 rpm, as a visual scale only (rpm is a 0..1 ratio).
- The minimap has no car heading (the contract passes only positions), so the local car is a dot, not an arrow.

## Integration requests
- None. (Verified against `origin/module/race`: its call order and pause handling work with this module as is.)

## Session 4 (owner feedback)
- Minimap removed (`HudMinimap`, `set_minimap*`, race.gd's per-tick updates).
- Checkpoints no longer show the big centred "CHECKPOINT" banner; the split pop-up under the timer
  ("CP n  time  ±delta") and the timer flash are the checkpoint feedback. FINISH / NEW PB! unchanged.
- Tachometer + NOS cluster scaled to `TACHO_SCALE` = 0.7 (pivot at its bottom-right corner).
