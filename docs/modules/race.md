# Module: race (race scene, Time Attack logic, camera, remote cars, ghosts)

Branch: `module/race`. Implements ARCHITECTURE.md "Race".

## File map
| file | what |
|---|---|
| `game/race/race.gd` / `race.tscn` | race scene: builds everything, Time Attack state machine, online round flow |
| `game/race/chase_camera.gd` | `ChaseCamera` (Camera3D): chase near/far, bumper, hood, look back, FOV, shake, collision |
| `game/race/remote_car.gd` | `RemoteCar` (Node3D): snapshot buffer + interpolation, CarVisual, name tag, fade |
| `game/race/ghost_recorder.gd` | `GhostRecorder` (RefCounted): 20 Hz samples `{t, p, q, st, fl}` |
| `game/race/ghost_player.gd` | `GhostPlayer` (Node3D): translucent PB ghost playback |
| `game/tests/race/test_track.gd` | tiny test track (`extends Track`): 600 m straight, 3 CP gates + finish (real Area3Ds) |
| `game/tests/race/gate_runner.gd` | test driver: teleports the car along `track.path` at a fixed speed while RUNNING |
| `game/tests/race/test_race_logic.tscn` | headless state machine test (41 checks) |
| `game/tests/race/test_remote_car.tscn` | headless RemoteCar interpolation test (jitter, loss, silence, teleports) |
| `game/tests/race/test_camera_loop.tscn` | camera through a vertical loop + banked turn (headless checks or screenshots) |
| `game/tests/race/online_round_test.sh` | end-to-end online round: Node server + N headless Godot clients (AutoPilot) |

## State machine (race.gd)
```
LOADING -> COUNTDOWN (car frozen, 3-2-1-GO) -> RUNNING -> FINISHED (2.5 s) -> COUNTDOWN (1.5 s hold) -> ...
online: local clock passes end_at, or room phase "results", or Net.round_ended -> ROUND_OVER
        -> results overlay on Net.round_ended -> Game.to_lobby() when the room phase is "lobby"
```
- Run time = physics ticks × 1000/60 ms (`get_run_ms()`); countdowns also count ticks, except the
  first online countdown, which uses the wall clock to hit `round_info.start_at_local_ms` exactly
  (measured GO skew between clients in tests: 12–16 ms, i.e. at most one tick).
- Countdown shows "GET READY" while more than 3 s remain (online, waiting for the synced start),
  then `hud.show_countdown(3..1)` + `Audio.play_sfx("countdown")`, then `show_countdown(0)` + `"go"`.
- Checkpoints: only `index == next_cp` counts (wrong order and duplicates are ignored; gates are
  ignored outside RUNNING). The finish counts only when all checkpoints are passed and the run is
  at least 1 s old (protects against teleport artifacts on the start/finish gate).
- On a checkpoint: split recorded, compared with the PB splits (stored in the ghost), `hud.show_split`,
  `hud.set_checkpoints`, respawn snapshot, `Net.send_checkpoint` (online).
- Respawn snapshot: the car's own transform + velocity when it crossed the gate (Trackmania
  style), unless it was airborne, tilted or sideways (> ~30° from its velocity): then the gate pose
  from `track.get_checkpoint_transform(i)` with the forward speed.
- Respawn (`respawn` action, below `track.kill_y`, upside down and stopped for 3 s, or the
  AutoDriver's `stuck` signal): teleport to the snapshot, clock keeps running.
- Restart (`restart` action, or pause menu): new run with the 1.5 s hold. Ignored while waiting for
  the synchronized online start and after the round ended.
- On finish: `Profile.submit_time`; on a PB the ghost (with splits) is saved with `Profile.save_ghost`
  and immediately becomes the ghost/splits reference. `Net.send_finish` online. `hud.show_finish`,
  `Audio.play_sfx("pb"|"finish")`. Input is disabled until the next countdown (car coasts).
- Late joiners (`now > start_at`): first run starts after the 1.5 s hold (no wait for anyone).
- Pause: `pause` action toggles the pause menu. Solo pauses the tree (a PROCESS_MODE_ALWAYS
  listener closes it again on the same key); online the tree keeps running and car input is off
  while the menu is open. `restart_requested` restarts, `quit_requested` goes to the lobby (online,
  stays in the room) or the menu (solo).
- Online robustness: results fall back to the live leaderboard if `round_end` is 9 s late; the scene
  goes to the lobby 25 s after the round ended even if the room never reports "lobby"; on
  `Net.disconnected` it shows a message and goes to the lobby after 2.5 s; if a new `round_started`
  arrives while still in the race scene, it restarts the scene for that round.
- HUD every frame: speed (abs km/h), rpm/gear, nitro, run time, round time left (online, `-1` solo),
  minimap cars. `set_best`: the local PB in solo, my best of this round online.
- Online `send_state` every physics tick with `t` (run ms or -1) and an extra `ts` (sender
  `Time.get_ticks_msec() % 1e8`) used by RemoteCar for jitter-free timing. Flag 32 is set during
  FINISHED.

## ChaseCamera
- Follow frame = quaternion that turns toward the car's heading (`rot_follow` 7/s) and up vector
  (`up_follow` 4/s), slowed to 35 % in the air, so loops and banking rotate the camera smoothly and
  the car stays upright on screen (tested through an r = 18 m loop: camera up · car up ≥ 0.86,
  max up change 0.05 rad/frame).
- Offset lags in that frame (rotational lag) plus a small velocity-change lag (falls back when
  boosting) and a speed pullback; distance does not grow with speed like a world-space spring would.
- FOV: base 68 (near) / 66 (far) / 74 (bumper, hood) + up to 20° at 300 km/h + 7° nitro kick.
- Shake above 240 km/h and on landings after > 0.35 s airtime.
- Collision: ray on layer 1 from the pivot to the camera; snaps in, eases out.
- `camera_cycle` cycles modes and saves `Settings.camera_mode`; `look_back` (held) mirrors.
- Uses `get_global_transform_interpolated()`, so it's ready for physics interpolation.
- Knobs: `CHASE_PRESETS`, `rot_follow`, `up_follow`, `air_follow_scale`, `accel_lag`,
  `speed_pullback`, `fov_speed_gain`, `nitro_fov_kick`, `shake_speed_kmh`, `shake_amount`.

## RemoteCar
- Buffer of 32 snapshots. Render time = now − offset − 100 ms, where offset is the minimum of
  `rx_ms − ts` (min one-way delay + clock offset, allowed to creep up 2 %/ms), eased into the
  playback clock at ±10 % rate so it never jumps. Without `ts` it falls back to `rx_ms`.
- Cubic Hermite positions (snapshot velocities), slerped rotations; jumps > 30 m snap (respawns).
- Extrapolates ≤ 250 ms on packet loss, then holds; hidden after 3 s of silence.
- Wheels spin from forward speed, steer = `st` × 0.55 rad, lights/nitro from flags, EngineAudio
  (non-local) driven from rpm/flags/speed.
- Name tag: Label3D, billboard, fixed size, no depth test, Rajdhani 700.
- Fades with camera distance: alpha 0.18 at 2.5 m → 1.0 at 7 m via `CarVisual.set_ghost`.
- Test (synthetic 50 m/s circle, 40–110 ms jitter, 4 lost packets): avg error 0.6 m budget, max frame
  step < 1.5 m (expected 0.83 m), passes.

## Ghosts
- `GhostRecorder` samples at 20 Hz on the run clock; the ghost Dictionary:
  `{version: 1, track, car: CarConfig, ms, splits: [ms per CP], hz: 20, samples: [{t, p:[3], q:[4], st, fl}]}`.
  Runs over 10 min don't record. A PB always saves a ghost (with empty samples if it overflowed)
  so the splits survive.
- `GhostPlayer` plays it translucent (`set_ghost(0.35)`, underglow off), Catmull-Rom positions,
  shown while RUNNING if `Settings.show_pb_ghost`, parked 1.5 s at the end. Splits are only
  trusted when the ghost's `ms` equals the Profile PB and the CP count matches the track.

## API additions (beyond the contract)
race.gd: signals `state_changed(int)`, `checkpoint_passed(index, ms)`, `run_finished(ms, is_pb)`,
`respawned`, `round_over`; `var track_override: Track` (set before `_ready`, for tests);
`get_run_ms()`, `respawn()`, `restart_run()`, `open_pause()`, `close_pause()`, `toggle_pause()`;
public vars `state`, `next_cp`, `splits`, `pb_splits`, `run_ticks`, `remote_cars`, `car`, `track`,
`camera`, `hud`, `ghost_player`. Net state snapshots carry an extra `ts` key.
Command-line args: `--autodrive`, `--track=id` (solo when launched directly), `--test_track`,
`--gate_runner=<m/s>`, `--quit_after_round`. Logs `RACE <event>` lines.

## How to test
```bash
tools/run_scene.sh res://tests/race/test_race_logic.tscn --headless -- --frames=6000   # 41 ok
tools/run_scene.sh res://tests/race/test_remote_car.tscn --headless -- --frames=100    # 10 ok
for m in 0 1 2 3; do tools/run_scene.sh res://tests/race/test_camera_loop.tscn --headless -- --frames=3000 --cam_mode=$m; done
game/tests/race/online_round_test.sh 2 20                 # PASS (server + 2 clients, full round)
LATE=1 game/tests/race/online_round_test.sh 2 30          # PASS (+ a late joiner)
# with the real Car/Track/AutoDriver merged:
game/tests/race/online_round_test.sh 2 60 --autodrive --track=arena
tools/run_scene.sh res://race/race.tscn -- --frames=400 --shot=/abs/race.png --track=arena --autodrive
```

## Known issues / notes
- Car and Track were stubs while this was written: tested with the module's own test track and
  the gate runner. Real driving (`--autodrive`) on real tracks must be re-checked after merging.
- Human players also auto-restart 2.5 s after a finish (state diagram); restart works any time.
- `--test_track` in online mode ignores the room's track (test only).

## Integration requests
1. **ui_menus / online lobby**: when the lobby scene opens while `Net.room.phase` is `countdown` or
   `racing` and `Net.current_round` is not empty (player quit the race to the lobby, or a
   `round_started` arrived during the scene change), offer "Rejoin race" →
   `Game.start_online_round(Net.current_round)` (or auto-rejoin).
2. **ui_hud**: `set_minimap_cars(local_pos, others)` is called with `others` = `Array` of `Vector2`
   (world XZ). The pause menu should emit `resumed` when it closes itself (Esc); race.gd also handles
   the `pause` action while paused and tolerates double close.
3. **physics**: race.gd sets `car.frozen_controls` during countdowns, calls `teleport()`,
   `refill_nitro()` at every run start, connects `AutoDriver.stuck` (if present) to respawn, and
   toggles `CarInput.enabled` (CarInput) or `set_physics_process` (AutoDriver) between runs.
   If the AutoDriver keeps state between runs, a `reset()` method would help (race.gd would call it).
4. **core / project.godot**: consider enabling `physics/common/physics_interpolation=true` for
   smooth motion on high-refresh displays; ChaseCamera already uses interpolated transforms.
5. **visuals**: race.gd calls `visual.set_headlights_real(true)` on the local car if it exists.
