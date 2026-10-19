# audio module

All SpeedFest audio is synthesized by our own Python scripts (numpy + ffmpeg, no samples, no
scipy) and committed as Ogg Vorbis under `game/audio/generated/` (~2.1 MB in total).

## What it does

- **Engines** (`EngineAudio`): per car, four seamless loops rendered at known base rpms:
  `idle`, `mid`, `high` (on throttle, equal-power crossfaded by rpm) and `off` (off-throttle
  burble with overrun pops). `pitch_scale = rpm / base_rpm`.
  - **kaze**: twin-rotor rotary, idle 1100, redline 9000. Bright, buzzy, raspy, strong turbo.
  - **brute**: cross-plane V8 (firing order 1-8-4-3-6-5-7-2, two exhaust banks with different
    delays and gains), idle 800, redline 6800. Deep lumpy burble; big per-cycle variation at idle.
  - **veloce**: flat-plane V12, idle 1200, redline 8800. Smooth, dense, bright scream.
  - Extras (local car only): turbo whistle (boost builds with throttle × rpm, collapses on lift),
    blow-off one-shot on a quick lift from boost, nitro loop + kick-in whoosh, tire squeal
    (by drift, only grounded and moving), wind (by speed), landing thud (airtime > 0.25 s,
    louder for longer jumps), rev-limiter stutter when on the redline with throttle.
  - Remote cars: two `AudioStreamPlayer3D` layers (mid, high) with inverse-distance attenuation
    (unit size 14 m, max distance 220 m). Local: 8 loops + 3 one-shot players. 1 local + 7 remote
    = 25 players.
  - Silent layers are `stream_paused` (no mixing cost). Inputs are smoothed in `_process`, so
    raw per-frame values are fine.
- **Audio autoload** (`audio_manager.gd`): `play_ui`, `play_sfx`, `play_music` (1.4 s crossfade
  between two players), `stop_music`. Pools: 4 UI + 8 SFX players, never grow (idle player first,
  otherwise round-robin steal). The same sound is not retriggered within 45 ms (hover spam).
  Runs with `PROCESS_MODE_ALWAYS` (pause menu clicks work, music continues while paused).
  Unknown names warn once and do nothing. Missing files warn once and do nothing.
- **Music** (session 4, owner: "dark trap, Future / Southside / 808 Mafia type beat"): five original
  dark-trap loops from `tools/audio/gen_trap.py`, synthesized from scratch (no samples), so they are
  fully original and royalty-free. 32 bars each (~51–57 s), rendered circularly (seamless loop):
  intro (muffled melody + choir) → beat (kick + gliding saturated 808, half-time clap, 808-style
  hats with 1/16, triplet and 1/32 rolls) → break (sparse hats, riser, reverse cymbal) → beat with a
  counter line.
  - `music_menu` 140 BPM C# minor, dark FM bell + choir
  - `music_arena` 150 BPM F minor, synth brass stabs + bell (hype)
  - `music_downtown` 142 BPM A minor with the phrygian b2, felt piano + choir (rainy night)
  - `music_coast` 136 BPM E minor, breathy flute + dark pluck
  - `music_race` 144 BPM G minor, bell (any track without its own beat)
  `Audio.race_music(track_id)` → `"track_<id>"` if present, else `"race"`; race.gd uses it.
- **Web**: browsers start audio only after a user gesture. Godot resumes the AudioContext by
  itself; the Audio autoload additionally restarts the current music once on the first
  key/mouse/touch/joypad press (web only), in case the start was swallowed. Nothing errors before.

## Files

| file | what |
|---|---|
| `game/audio/engine_audio.gd` | `EngineAudio` (class_name), layered engine + car sounds |
| `game/audio/engine_layers.gd` | GENERATED table: base rpm of each loop, idle/redline, turbo amount |
| `game/audio/generated/*.ogg` (+ `.import`) | all sounds (loop flags set in `.import`) |
| `game/autoload/audio_manager.gd` | `Audio` autoload |
| `game/tests/audio/test_audio.{gd,tscn}` | headless test |
| `tools/audio/synth.py` | numpy synthesis toolkit (circular FFT filters, band-limited wavetables, reverb, ogg out, spectrograms) |
| `tools/audio/gen_engines.py` | engine model + car loops |
| `tools/audio/gen_sfx.py` | UI, race and car one-shots |
| `tools/audio/gen_trap.py` | the dark-trap beats (composition is in code) |
| `tools/audio/gen_all.py` | runs all generators, writes `engine_layers.gd` |
| `tools/audio/fix_loops.py` | sets `loop=true` in `.import` of loops, forces reimport |
| `tools/audio/build.sh` | generate + import + fix loops + reimport |

Sound files: `eng_<car>_<idle|mid|high|off>`, `car_turbo|nitro|squeal|wind` (loops),
`car_land|blowoff|nitro_start`, `ui_click|hover|back|confirm|error`,
`sfx_checkpoint|finish|pb|countdown|go|respawn|boost|wall_hit`, `music_menu|music_race`.

## How to regenerate and test

```bash
tools/audio/build.sh                       # everything (~45 s, music is the slow part)
tools/audio/build.sh --only engines        # or sfx / music
python3 tools/audio/gen_all.py --only sfx --png /abs/dir   # + spectrogram PNGs to look at
tools/run_scene.sh res://tests/audio/test_audio.tscn --headless -- --frames=5000
python3 tools/audio/check_loops.py            # seams of the encoded loops (no clicks)
```
The test prints `TEST_OK`/`TEST_FAIL`: every stream loads with the right loop flag and length;
per car (local) idle → full-throttle rpm sweep (gains finite, pitch in range, total power never
drops out, dominant layer only moves idle → mid → high), high layer dominant at redline, wind at
speed, boost builds, off layer and blow-off on lift, turbo collapses, nitro, squeal grounded only,
landing thud, extras paused at rest; remote cars use 2 positional players; 8-car player budget;
every Audio call, pools fixed, music crossfade/rapid switching/stop.

## API (contract + additions)

Contract (ARCHITECTURE.md) unchanged. Additions:
- `Audio.play_sfx` also accepts `"land"`, `"blowoff"`, `"nitro"` (besides checkpoint, finish, pb,
  countdown, go, respawn, boost, wall_hit).
- `Audio.current_music() -> String`, `Audio.is_music_playing() -> bool`,
  `Audio.get_player_count() -> int`.
- `EngineAudio.get_debug() -> Dictionary` (per layer gain/pitch/playing, rpm, boost,
  last_oneshot), `EngineAudio.get_player_count() -> int`, vars `car_id`, `is_local`,
  exports `local_engine_db`, `remote_engine_db`, `remote_unit_size`, `remote_max_distance`.
- `setup()` may be called before or after the node enters the tree, and again to switch car.

## Decisions / assumptions

- `rpm_ratio` is mapped to audio rpm per car: `[0.12, 1]` → `[idle_rpm, redline]` (physics
  reports ~0.12 at idle and never less while running; `EngineAudio.IDLE_RATIO`). Below 0.12 is
  idle. Values up to 1.05 are accepted.
- Engine level: local -4.5 dB, remote -2 dB before distance attenuation. Music: menu -4 dB, race
  -6 dB (on top of the Music bus), so engines and SFX sit on top of the race music.
- Vorbis quality 3 for SFX/engines, 2 for music (~80 kbps stereo) to keep the web download small.
- Loops are mono except music (stereo).

## Integration requests (for race / ui modules and the integrator)

- **race**: add one `EngineAudio` as a child of each car (local: `setup(car_id, true)`; remote:
  `setup(car_id, false)` on the RemoteCar node so it follows the car's position). Every frame:
  `set_params(car.get_rpm_ratio(), car.controls.throttle, car.get_speed_kmh(), car.get_drift_amount(), car.is_nitro_active(), car.is_grounded())`.
  For remotes use the snapshot's rpm/throttle/flags as available (drift/nitro/grounded can be
  false). Call `Audio.play_music("race")` on race start; `Audio.play_sfx("countdown")` for 3/2/1,
  `"go"`, `"checkpoint"`, `"finish"` (and `"pb"` ~0.4 s later when it's a PB), `"respawn"`,
  `"boost"` on boost pads, `"wall_hit"` on hard wall impacts (volume_db by impact speed, e.g.
  `linear_to_db(clamp(impact / 20.0, 0.2, 1.0))`, pitch `randf_range(0.9, 1.1)`).
- **race** (checked against `origin/module/race` and `origin/module/physics` at the time of
  writing): EngineAudio setup/set_params, countdown/go/checkpoint/finish/pb/respawn and
  `play_music("race")` are already wired. Still missing:
  - wall hits: `car.wall_hit.connect(func(lost: float) -> void: Audio.play_sfx("wall_hit", linear_to_db(clampf(lost / 15.0, 0.15, 1.0)), randf_range(0.9, 1.1)))`
  - boost pads: `Audio.play_sfx("boost")` when a pad fires.
  - `RemoteCar.update_config()` with a different car should call `engine_audio.setup(new_car_id, false)`
    (otherwise a remote player who switched cars keeps the old engine sound).
  - a finish that is a PB currently plays only `"pb"`; consider `"finish"` then `"pb"` 0.5 s later.
- **ui_menus / ui_hud**: `Audio.play_ui("hover")` on focus/hover, `"click"` on press, `"confirm"`
  on accept/start, `"back"` on back/cancel, `"error"` on invalid action.
  `Audio.play_music("menu")` in the main menu (calling it again while it plays is a no-op).
- If the chase camera sets `doppler_tracking`, remote engines could use Doppler too
  (`AudioStreamPlayer3D.doppler_tracking`); not enabled now.

## Test results (2026-10-15)

- `tools/check_scripts.sh`: `SCRIPT_ERRORS=0`.
- `tests/audio/test_audio.tscn` (headless): `TEST_SUMMARY ok=64 fail=0`.
- `tools/audio/check_loops.py`: all 18 loops seamless (`LOOP_CHECK_FAILURES=0`), exact lengths.
- Integration probe (local merge of this branch with physics/race/tracks/visuals/scenery/ui_*,
  not pushed): `race.tscn --autodrive` runs without audio errors; with real physics the rpm
  sits around 7000-8600 most of the time (so the `high` layer carries the sound), the landing
  thud fires on jumps, the limiter stutter engages at the redline.

## Known issues

- Synthesized engines are an approximation; they were tuned by waveform/spectrum inspection,
  not by ear. Tuning knobs are in `CARS` in `gen_engines.py` (resonances, brightness, rasp,
  drive, per-layer variation) and the gains in `engine_audio.gd`.
- Web: Godot's web "sample" playback mode (no threads) supports volume/pitch/3D panning per player
  but not bus effects; we use none. Not yet verified in a real browser by this module.

## Previewing without the game

`python3 tools/audio/preview_engine.py /abs/out_dir [car ...]` renders a 13 s drive per car
(idle, three full-throttle pulls, limiter, lift + blow-off, nitro, drift) from the generated
loops with the same mix logic as `EngineAudio` (a Python port: keep the two in sync when tuning),
writes `preview_<car>.ogg` and a spectrogram PNG, and prints the peak level.
