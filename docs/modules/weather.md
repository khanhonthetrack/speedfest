# weather: dry / rain / storm rounds with stage-designed puddles

Owner request (2026-10-15): *"consider weather and how this can be different from trackmania. E.g.
when in the rain, there are puddles which makes cars slide more. Include this in the stage design."*
Design: **docs/DESIGN.md §4.1**. Code: `game/weather/`, plus hooks in track, car, race, net and UI.

## How it works
- **Weather is a round setting.** Online, the host picks it in the lobby (picking a track also
  selects its signature weather). The server stores `settings.weather` and sends it in
  `round_start`, so everyone races the same conditions. Solo, the track select has
  AUTO / DRY / RAIN / STORM chips, where AUTO means `Weather.default_for(track)` (downtown = rain).
- `Weather` (`weather.gd`): all the numbers in one place:

  | | dry | rain | storm |
  |---|---|---|---|
  | road grip | 1.0 | 0.94 | 0.90 |
  | puddle grip (× road) | 1.0 | 0.50 | 0.42 |
  | water drag / wheel (m/s²) | 0 | 4 | 5 |
  | puddle size (× storm size) | 0 | 0.76 | 1.0 |
  | road shader wetness | 0.08 | 0.85 | 1.0 |
  | rain density | 0 | 1.0 | 1.6 |

- `TrackSurface` (`track_surface.gd`): the puddle ellipses of a track (center = road frame, half
  width/length at storm size, storm-only flag). `water_at(pos)` gives a 0..1 depth with a soft rim.
  `Track` builds it from the layout's `{"puddle": ...}` markers. `Track.apply_weather(mode)` switches
  modes, puddle meshes and road wetness.
- **Car** (`cars/car.gd`): `car.surface = track.surface` (set by race). Per wheel contact,
  `sgrip = surface.grip_for_water(water)` scales lateral grip (`mu`), the braking cap and
  (80%) traction. Water drag scrubs a little speed. `get_water_amount()` returns 0..1, and net flag
  `64` means "in a puddle". AutoDriver plans speeds with the wet-asphalt grip.
- Visuals: `shaders/track_puddle.gdshader`. It's opaque with discard, so Forward+ SSR reflects into it.
  It has an organic noisy outline, a bright rim, two layers of raindrop ripple rings, and a fake
  wet-street reflection (horizon glow + light streaks from the reflected view ray, tinted per
  theme: `Track.PUDDLE_SHEEN`). `WeatherFX` adds rain streaks on the camera
  (`SceneryRain.create(density)`) and dims and fogs dry-themed stages. In a storm it also adds
  lightning (sun, sky and ambient flash) and thunder 0.3–2 s later. `WaterSpray` (CPUParticles3D,
  web-safe) puts a splash plume behind the rear wheels in puddles and a mist on wet asphalt above
  90 km/h, on local and remote cars.
- Audio: `tools/audio/gen_weather.py` generates `amb_rain` (6 s seamless loop), `sfx_thunder`,
  and `sfx_splash`. `Audio.play_ambience("rain")` / `stop_ambience()`; sfx `"thunder"`, `"splash"`.
- PBs and ghosts are stored under `Weather.pb_key(track, weather)` (`"downtown@rain"`).

## Layout markers (stage design)
`{"puddle": length, "w": width, "x": lateral (+ right), "at": offset from the marker, "storm": bool}`.
Put the marker before the segment the puddle lies on. Rules (tested): never on a jump, loop,
wall ride or boost pad. Puddles are line choices (apexes, turn-in lines, banked-turn bottoms,
landings, downhill runoff). See DESIGN §4.1 for the per-stage list.

## Tests
- `tests/weather/test_weather.tscn` (headless, 38 checks): rules, surface math, puddle counts and
  visibility per track and mode, puddles clear of stunts, **a car really turns less in a puddle**
  (same input on flat ground, dry vs storm puddle), lightning, spray.
- `tests/weather/weather_view.tscn -- --track=downtown --weather=rain --puddle=1 --back=14 --frames=50 --shot=/abs.png`
  is a camera behind a puddle, for screenshots on both renderers.
- `WEATHER=storm game/tests/physics/run_real_tracks.sh` runs the 3×3 matrix in a storm. Online:
  `game/tests/race/online_round_test.sh 3 40 --autodrive --track=downtown --weather=storm`.

## Results (2026-10-15, session 3)
- The analog AutoDriver finishes **all 9 car×track runs with 0 respawns** in default weather
  (downtown in rain) **and in storm**. Storm runs are ~0.5–1.5 s slower.
- Keyboard emulation: 13/18 clean in both (same as dry before weather existed). Remaining falls
  are mostly not weather related (wall-ride exits and jumps at high speed).
- Online 3-client storm round on downtown: PASS (all finished, everyone raced in storm).

## Next ideas
Crosswind gusts on the coast bay jump, fog banks, a drying line during long rounds, wet-tire
carry-over (grip stays low ~0.5 s after a puddle), splash screen droplets on the camera.
