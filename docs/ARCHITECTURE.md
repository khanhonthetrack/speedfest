# SpeedFest — Architecture & Interface Contracts

This is the **source of truth** for how modules talk to each other. If you change a
public API, update this file in the same commit.

- Engine: **Godot 4.7.2-stable**, GDScript with static typing.
- Physics: **Jolt** (`physics/3d/physics_engine="Jolt Physics"`), 60 Hz ticks.
- Renderer: `forward_plus` on desktop/console, `gl_compatibility` on **web** (set via the
  `rendering_method.web` override in `project.godot`). Code must look acceptable on both.
  Use `Settings.is_compat()` to branch.
- Online: Node.js WebSocket server (`server/`) that also serves the exported web build. The web
  client connects to the same origin at `/ws`.

## Repository layout

```
README.md              how to play / host
CLAUDE.md              rules for agents working in this repo
docs/                  DESIGN, ARCHITECTURE (this), PLAN, PROGRESS, TRANSCRIPT, SWITCH, HOSTING
game/                  Godot project (open game/project.godot)
  autoload/            Settings, Profile, Game, Net, Audio singletons
  cars/                car_defs.gd (ids/geometry/default styles), car.gd (physics), tuning.gd
    physics/           physics helpers and per-car physics params
    visual/            CarVisual + procedural mesh builders + parts
  tracks/              track.gd (built track node), track_path.gd, track_defs.gd, track_builder.gd
    defs/              one file per track layout
    scenery/           environment and prop kits per theme
  race/                race.tscn/race.gd (run logic), chase camera, remote cars, ghosts
  ui/                  menus, garage, lobby, HUD, results, theme
  audio/               generated sound assets plus EngineAudio
  shaders/             shared .gdshader files
  assets/fonts/        Orbitron + Rajdhani (OFL)
  tests/               test_runner.tscn + per-module test scenes
server/                Node.js server (ws + static). public/ = committed web export
tools/                 build, export, screenshot, test scripts
```

## Coordinate conventions

- Godot: **−Z is forward**, +Y up, +X right. Units are meters, seconds, kg.
- **Car origin** is the center of the wheelbase and track, at **wheel-center height when at rest**.
  At rest the ground is at `y = -wheel_radius`. Wheel centers at rest are
  `FL(-tf/2, 0, -wb/2)`, `FR(+tf/2, 0, -wb/2)`, `RL(-tr/2, 0, +wb/2)`, `RR(+tr/2, 0, +wb/2)`,
  where `wb`=wheelbase, `tf/tr`=front/rear track. Wheel index order is always **FL, FR, RL, RR**.
- Track frames: `TrackPath.sample_transform(d)` returns a transform whose origin is on the road
  surface centerline, `basis.x` = right, `basis.y` = road normal (up), `-basis.z` = forward
  (direction of travel).

## Collision layers

| layer | name | who | mask |
|---|---|---|---|
| 1 | world | track road/walls/props (StaticBody3D) | — |
| 2 | car | the local `Car` (RigidBody3D) | 1 |
| 3 | trigger | checkpoints, finish, boost pads (Area3D) | 2 (detect cars) |

Car suspension rays use mask 1 only and ignore areas. Remote cars are visuals only (no physics bodies),
so players never collide.

## Data schemas (JSON-serializable Dictionaries)

### CarConfig — what a player drives (stored by Profile, sent over the network)

```jsonc
{
  "car": "kaze",                 // CarDefs.IDS: "kaze" | "brute" | "veloce" | "kitsune" | "pixie" | "goliath"
  "tuning": {                    // floats in [-1, 1]; ALWAYS 0 since session 4 (tuning removed, DESIGN §3.1)
    "gearing": 0, "turbo": 0, "downforce": 0, "suspension": 0,
    "balance": 0, "steering": 0, "nitro": 0
  },
  "style": {
    "paint": "#ff6a00", "finish": "metallic",   // gloss|metallic|pearl|matte|chrome
    "accent": "#111111", "livery": "none",      // none|racing_stripes|side_stripe|two_tone|fade|checker
    "hood": 0, "hood_carbon": false,            // hood 0..3
    "front": 0, "rear": 0, "skirts": 0,         // 0..2 each
    "spoiler": 0,                               // 0..4 (0 = none)
    "rims": 0, "rim_color": "#c8c8c8", "caliper": "#d01010",   // rims 0..4
    "underglow": "#00e5ff", "underglow_mode": "static",      // off|static|pulse|strobe|rainbow
    "tint": 0.5,                                // 0..1
    "headlight": "#dfefff",
    "ride_height": 0.0,                         // -1 (slammed) .. 1 (raised)
    "plate": "SPDFST"                           // <= 8 chars, A-Z0-9 and space
  }
}
```

`CarDefs.sanitize_config(cfg)` clamps or fills any missing or invalid field. Always call it on
configs received from the network.

### Net state snapshot (sent by each racing client ~20 Hz)

```jsonc
{ "t": 12345,                    // run time in ms (-1 when not in a run)
  "p": [x, y, z], "q": [x, y, z, w], "v": [vx, vy, vz],
  "st": 0.0,                     // steer -1..1
  "rpm": 0.0,                    // 0..1
  "fl": 0 }                      // flags: 1 braking, 2 nitro, 4 drifting, 8 reversing, 16 grounded, 32 finished-display, 64 in a puddle
```

## Autoload singletons (`game/autoload/`)

| Name | File | Owner | Purpose |
|---|---|---|---|
| `Settings` | settings.gd | core | quality, audio volume, units, server URL, input map setup, environment tuning helper |
| `Profile` | profile.gd | core | player name, selected car, per-car tuning/style, PBs and ghosts (user://) |
| `Game` | game.gd | core | scene flow and mode state (solo/online, track, round info) |
| `Net` | net.gd | networking | WebSocket client, rooms, clock sync, relays |
| `Audio` | audio_manager.gd | audio | music, UI sounds, one-shot SFX |

### Settings (implemented)
```gdscript
var quality: int            # 0 Low, 1 Medium, 2 High, 3 Ultra
var units_mph: bool
var master_volume, music_volume, sfx_volume: float   # 0..1
var server_url: String      # "" = auto (same origin on web, ws://localhost:8080/ws on desktop)
var show_fps: bool, show_pb_ghost: bool
var camera_mode: int
func is_web() -> bool
func is_compat() -> bool    # running the Compatibility renderer
func tune_environment(env: Environment) -> void   # enable/disable SSR/SSAO/SDFGI/volumetrics/glow by quality+renderer
func apply() -> void; func save() -> void
signal changed
```

### Profile (implemented)
```gdscript
var player_name: String
var selected_car: String
func get_config(car_id := "") -> Dictionary      # CarConfig for car (default = selected)
func set_tuning(car_id: String, tuning: Dictionary) -> void   # deprecated no-op (tuning removed); get_config() returns stock tuning
func set_style(car_id: String, style: Dictionary) -> void
func get_pb(track_id: String) -> int             # ms, -1 if none
func submit_time(track_id: String, ms: int, car_id: String) -> bool   # true if new PB
func save_ghost(track_id: String, ghost: Dictionary) -> void; func load_ghost(track_id: String) -> Dictionary
func save() -> void
signal changed
```

### Game (implemented)
```gdscript
const SCENE_MENU := "res://ui/main_menu.tscn"
const SCENE_GARAGE := "res://ui/garage.tscn"
const SCENE_LOBBY := "res://ui/online_lobby.tscn"
const SCENE_TRACK_SELECT := "res://ui/track_select.tscn"
const SCENE_RACE := "res://race/race.tscn"
var mode: String            # "solo" | "online"
var track_id: String
var round_info: Dictionary  # from Net.round_started (online)
func goto(scene_path: String) -> void
var weather: String          # solo pick; online = round_info.weather ("" = Weather.default_for(track))
func start_solo(track_id: String, weather := "") -> void
func start_online_round(info: Dictionary) -> void
func to_menu() -> void; func to_lobby() -> void; func to_garage(return_to := "") -> void
var garage_return_scene: String
```

### Net (networking module)
```gdscript
signal connected
signal disconnected(reason: String)
signal rooms_listed(rooms: Array)                  # [{code, name, players, phase, track}]
signal room_changed(room: Dictionary)              # full room state, see protocol
signal round_started(info: Dictionary)             # {round_id, track, duration_s, weather, start_at_local_ms, end_at_local_ms}
signal round_ended(results: Array)                 # [{id, name, car, best_ms, runs}] sorted
signal leaderboard_changed(entries: Array)         # same shape as results, live
signal player_state(id: int, state: Dictionary)    # snapshot (see schema) from another player
signal player_left(id: int)
signal chat(from_name: String, text: String)
signal net_error(message: String)
var my_id: int
var room: Dictionary                               # latest room state ({} if not in room)
func connect_to_server(url := "") -> void
func disconnect_from_server() -> void
func is_online() -> bool
func in_room() -> bool
func is_host() -> bool
func list_rooms() -> void
func create_room(room_name := "") -> void
func join_room(code: String) -> void
func leave_room() -> void
func set_profile(player_name: String, car_config: Dictionary) -> void
func set_ready(ready: bool) -> void
func host_set_settings(settings: Dictionary) -> void   # {track, duration_s, weather} (all optional)
func host_start_round() -> void
func send_state(state: Dictionary) -> void             # call every physics tick; Net throttles to ~20 Hz
func send_checkpoint(round_id: int, cp_index: int, time_ms: int) -> void
func send_finish(round_id: int, time_ms: int) -> void
func send_chat(text: String) -> void
func local_ms() -> int                                 # Time.get_ticks_msec()
func server_to_local_ms(server_ms: int) -> int
func get_player(id: int) -> Dictionary
# --- additions (networking module, merged) ---
signal player_checkpoint(id: int, cp: int, ms: int)                         # another player passed a checkpoint
signal finish_result(accepted: bool, ms: int, best_ms: int, reason: String)  # server verdict on send_finish
var current_round: Dictionary                      # last round_started payload ({} when none)
var leaderboard: Array                             # last leaderboard entries
var last_results: Array                            # last round_ended results
var ping_ms: int                                   # smoothed round-trip time, -1 until measured
func connection_state() -> String                  # "offline" | "connecting" | "online"
func server_now_ms() -> int                        # current server time estimate
func round_time_left_ms() -> int                   # ms left in the round (0 = over, -1 = no round)
# --- LIVE rotation (session 6) ---
const LIVE_CODE := "LIVE"
func join_live() -> void                           # join_room("LIVE"): the running round starts for us at once
func is_live() -> bool                             # in the LIVE room (room.live)
```
`player_state` snapshots also carry `"rx_ms"` (the local receive time) for interpolation.
`rooms_listed` entries also carry `max_players` and `host_name`.

### Audio (audio module)
```gdscript
func play_ui(name: String) -> void        # "click","hover","back","confirm","error"
func play_sfx(name: String, volume_db := 0.0, pitch := 1.0) -> void   # "checkpoint","finish","pb","countdown","go","respawn"
func play_music(name: String) -> void     # "menu","race"; ""/stop_music() to stop
func play_ambience(name: String, volume_db := 0.0) -> void   # looping bed: "rain"; stop_ambience()
# sfx also: "thunder", "splash"
func stop_music() -> void
```
`EngineAudio` (`res://audio/engine_audio.gd`, `class_name EngineAudio extends Node3D`):
```gdscript
func setup(car_id: String, is_local: bool) -> void
func set_params(rpm_ratio: float, throttle: float, speed_kmh: float, drift: float, nitro: bool, grounded: bool) -> void
```

## Cars

### CarDefs (`res://cars/car_defs.gd`, implemented, core-owned)
`CarDefs.IDS`, `CarDefs.get_def(id)` → `{name, archetype, blurb, drive, geometry{…}, parts{…}, default_style{…}}`,
`CarDefs.default_config(id)`, `CarDefs.default_tuning()`, `CarDefs.sanitize_config(cfg)`.
**Geometry is shared by physics and visuals. Don't change it without updating both.**

### Tuning (`res://cars/tuning.gd`, physics module)
```gdscript
class_name Tuning
static func physics_params(car_id: String, tuning: Dictionary) -> Dictionary   # resolved physics params for Car
static func stats(car_id: String, tuning: Dictionary) -> Dictionary
# -> {top_speed, accel, handling, drift, nitro (all 0..1), top_speed_kmh: float, zero_to_100_s: float}
```

### Car (`res://cars/car.gd`, `class_name Car extends RigidBody3D`, physics module)
```gdscript
static func create(config: Dictionary) -> Car    # builds collision, rays, CarVisual child; not yet in tree
var config: Dictionary
var visual: CarVisual
var controls := {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "handbrake": false, "nitro": false}
var frozen_controls := false                      # true during countdown: car held in place
func get_speed_kmh() -> float                     # signed forward speed
func get_rpm_ratio() -> float                     # 0..1
func get_gear() -> int                            # -1 R, 0 N, 1..6
func get_nitro_amount() -> float                  # 0..1
func is_nitro_active() -> bool
func get_drift_amount() -> float                  # 0..1
func is_grounded() -> bool                        # >= 2 wheels touching
func get_flags() -> int                           # see net snapshot flags
func get_net_state() -> Dictionary                # snapshot schema (without "t")
func teleport(xform: Transform3D, linear_velocity := Vector3.ZERO) -> void
func refill_nitro() -> void
func apply_boost(direction: Vector3, accel: float, duration: float) -> void   # boost pads
var surface: TrackSurface                         # weather grip map (set by race = track.surface); null = dry
func get_water_amount() -> float                  # 0..1 tire contact in puddles (spray, sound, flag 64)
func get_ground_kind() -> int                     # TrackSurface kind under the rear wheels: 0 asphalt, 1 grass, 2 gravel, 3 sand
```
Car reads `controls` every physics tick. `CarInput` (`res://cars/car_input.gd`, a Node child of
the car) fills them from the InputMap for the local player. `AutoDriver`
(`res://cars/auto_driver.gd`) fills them by following a `TrackPath`, for tests and bots.

### CarVisual (`res://cars/visual/car_visual.gd`, `class_name CarVisual extends Node3D`, visuals module)
```gdscript
func build(car_id: String, style: Dictionary) -> void        # (re)build all meshes; origin = car origin
func apply_style(style: Dictionary) -> void                  # live update (garage); rebuilds parts only if needed
func set_wheel_state(steer_angle_rad: float, spin_rad: Array, susp_offsets: Array) -> void  # 4 each, FL FR RL RR
func set_lights(braking: bool, reversing: bool) -> void
func set_nitro(active: bool) -> void                         # exhaust flame/plume
func set_ghost(alpha: float) -> void                         # 1 = opaque; <1 translucent (PB ghost / near-camera fade)
func set_underglow_enabled(on: bool) -> void
```
CarVisual adds its own underglow light and blob, headlights and taillights. The model is
procedural; a future glTF model must plug into the same API.

## Tracks

### TrackPath (`res://tracks/track_path.gd`, implemented, track module may refine)
```gdscript
class_name TrackPath
func _init(curve: Curve3D, circuit: bool, width: float)
var length: float, is_circuit: bool
var zones: Array   # [{from: float, to: float, kind: String}] kinds: "loop","jump","tunnel","bridge","boost","no_props"
func sample_transform(d: float) -> Transform3D
func sample_position(d: float) -> Vector3
func width_at(d: float) -> float
func set_width_profile(points: Array) -> void    # [[d, width], ...]
func closest_distance(p: Vector3) -> float       # distance along path of nearest centerline point
func lateral_offset(p: Vector3) -> float         # signed meters from centerline (+ = right)
func edge_clearance(p: Vector3) -> float         # meters outside road edge (negative = on road)
func in_zone(d: float, kind: String) -> bool
```

### Track (`res://tracks/track.gd`, `class_name Track extends Node3D`, track module)
```gdscript
static func build(track_id: String) -> Track          # full track: road, walls, gates, pads, scenery, environment
signal checkpoint_reached(car: Node, index: int)       # 0..checkpoint_count-1, in order along path
signal finish_reached(car: Node)
var track_id: String
var path: TrackPath
var checkpoint_count: int
var kill_y: float
func get_start_transform() -> Transform3D               # car origin pose for a standing start
func get_checkpoint_transform(index: int) -> Transform3D   # respawn pose at checkpoint (index -1 = start)
func get_minimap_points() -> PackedVector2Array          # XZ centerline (the HUD minimap was removed in session 4)
var surface: TrackSurface                                # puddles ({"puddle": ...}) and ground patches ({"surface": ...})
var weather: String
func apply_weather(mode: String) -> void                 # "dry"|"rain"|"storm": puddles, road wetness, grip
```
Track signals fire for **any** `Car` body. `race.gd` filters for the local car.
`TrackDefs` (`res://tracks/track_defs.gd`, core) has ids, display names, `short_name(id)` (one word, for
the lobby chips), themes, descriptions and target times (under 15 s = a "SPRINT" in the track select).

### Scenery & environment (`res://tracks/scenery/`, scenery module)
```gdscript
# One kit per theme: "city", "arena", "coast"
class_name SceneryKit
static func build_environment(theme: String) -> Node3D    # WorldEnvironment + sun/moon + sky + fog; uses Settings.tune_environment
static func build_props(theme: String, path: TrackPath, rng_seed: int) -> Node3D   # buildings, lamps, neon, stands, palms...
```
Props must not intrude on the road: keep `path.edge_clearance(p) > 2` unless intentional,
for example tunnel walls or overhead gantries. Collision is only needed on props a car can reach.

## Weather (`res://weather/`, core)

- `Weather` (static rules): `MODES` dry/rain/storm, `default_for(track_id)` (TrackDefs "weather"),
  `road_grip`, `puddle_grip`, `puddle_drag`, `puddle_extent`, `road_wetness`, `rain_density`,
  `pb_key(track_id, mode)` → `"arena@rain"` (PBs and ghosts are per weather).
- `TrackSurface`: puddle ellipses (built at storm size, shrunk in rain, storm-only ones inactive in
  rain). `water_at(pos)`, `grip_for_water(w)`, `grip_at(pos)`, `drag_for_water(w)`, `set_mode(m)`.
  Car samples it per wheel contact: lateral grip, traction and braking scale by the grip, and water
  drag scrubs a little speed.
  Ground patches (session 4): `KINDS` asphalt/grass/gravel/sand with `KIND_GRIP` and `KIND_DRAG`,
  `add_patch(kind, d0, d1, x0, x1, boxes)`, `kind_at(pos) -> int`, `centerline_grip(d)` (AutoDriver
  plans corner speeds with it). Car multiplies each wheel's grip by `KIND_GRIP` and adds the drag.
  Weather and ground stack (wet gravel = road_grip x 0.62). Per-car physics param `loose_grip`
  (0..1, session 6; Kitsune 0.75, Goliath 0.45) lerps `KIND_GRIP` toward 1 and cuts the drag by
  60% of it. The drag fades in with speed (`Car.LOOSE_DRAG_FULL_SPEED` 15 m/s; 15% at standstill).
- `DirtSpray` (`res://weather/dirt_spray.gd`): grass clippings / gravel dust / sand from the rear
  tires of the local car, driven by `Car.get_ground_kind()`.
- `WeatherFX` (race scene): rain streaks on the camera (`SceneryRain.create(density)`), darker and
  foggier light for wet rounds on dry-themed stages, storm lightning + thunder, rain ambience.
- `WaterSpray`: tire spray (splash in puddles, mist on wet asphalt) for local and remote cars.
- Design and stage placement: DESIGN §4.1. Tests: `tests/weather/test_weather.tscn`.

## Race (`res://race/`, race module)

`race.tscn` / `race.gd`: reads `Game.mode`, `Game.track_id`, `Game.round_info`; builds the
Track, the local Car (from `Profile.get_config()`), a `ChaseCamera`, the HUD, and the pause menu.
In online mode it also builds a `RemoteCar` per other player and an `EngineAudio` per car. It runs
the Time Attack state machine:

```
COUNTDOWN (car frozen) -> RUNNING -> FINISHED (show time 2.5s) -> COUNTDOWN (1.5s restart) ...
round end (online) -> RESULTS overlay -> Game.to_lobby() when room phase returns to "lobby"
```
- Run time = physics ticks × (1000/60) ms.
- On checkpoint: record split, store respawn snapshot (transform + velocity), send `Net.send_checkpoint`.
- On finish (all CPs passed): `Profile.submit_time`, `Net.send_finish`, save the PB ghost.
- Respawn: `car.teleport(cp_transform, cp_velocity)`. Restart: back to the start transform, run reset.
- `RemoteCar` (`remote_car.gd`): interpolates snapshots about 100 ms in the past, drives a
  CarVisual, shows a name tag (`Label3D`), and fades near the camera.
- `GhostRecorder`/`GhostPlayer`: 20 Hz samples `{t, p, q, st, fl}`.
- `ChaseCamera` (`res://race/chase_camera.gd`): modes chase-near, chase-far, bumper, hood. FOV by speed.

### HUD (`res://ui/hud.tscn`, `hud.gd`, UI module)
```gdscript
func set_speed(kmh: float) -> void            # handles mph via Settings.units_mph
func set_rpm(ratio: float, gear: int) -> void
func set_nitro(amount: float, active: bool) -> void
func set_run_time(ms: int) -> void            # -1 = show --:--.---
func set_best(ms: int) -> void
func set_checkpoints(passed: int, total: int) -> void
func show_split(ms: int, delta_ms: int, has_delta: bool) -> void   # blue if delta<0, red if >0
func show_finish(ms: int, is_pb: bool, delta_ms: int, has_delta: bool) -> void
func show_countdown(n: int) -> void           # 3,2,1 then 0 = "GO!"
func show_message(text: String, seconds := 2.0) -> void
func set_round_time_left(ms: int) -> void     # -1 hides (solo)
func set_leaderboard(entries: Array, my_id: int) -> void
```
`pause_menu.tscn`: signals `resumed`, `restart_requested`, `quit_requested`. `results.tscn`:
`show_results(results: Array, my_id: int)`.

## Network protocol (WebSocket, JSON text frames, path `/ws`)

Every message is `{"type": "...", ...fields}`. Server time is in ms (`Date.now()`).

Client → Server:
| type | fields | notes |
|---|---|---|
| `hello` | `name`, `version` | first message → `welcome` |
| `ping` | `t` (client ms) | → `pong {t, server_t}` |
| `list_rooms` | | → `rooms` |
| `create_room` | `name?` | creator becomes host → `room` |
| `join_room` | `code` | → `room` (or `error`) |
| `leave_room` | | |
| `profile` | `name`, `car` (CarConfig) | |
| `ready` | `ready` (bool) | |
| `settings` | `track`, `duration_s`, `weather` (each optional) | host only; weather ∈ dry/rain/storm |
| `start` | | host only; needs ≥ 1 player |
| `state` | snapshot fields | relayed to the room as `state {id, ...}` |
| `cp` | `round_id`, `cp`, `ms` | relayed as `cp {id, cp, ms}` |
| `finish` | `round_id`, `ms` | server updates best → `leaderboard` |
| `chat` | `text` (≤ 200 chars) | relayed as `chat {id, name, text}` |

Server → Client: `welcome {id, server_t, version}`, `pong {t, server_t}`, `rooms {rooms:[…]}`,
`room {room}`, `round_start {round_id, track, duration_s, weather, start_at, end_at}`
(server ms; the client converts to local with its clock offset), `round_end {results}`,
`leaderboard {entries}`, `state {id, …}`, `cp {id, cp, ms}`, `left {id}`, `chat {id, name, text}`,
`error {message}`.

Room object:
```jsonc
{ "code": "ABCD", "name": "...", "host": 3, "phase": "lobby",   // lobby|countdown|racing|results
  "settings": {"track": "arena", "duration_s": 300, "weather": "dry"},
  "players": [{"id": 3, "name": "Khanh", "car": {CarConfig}, "ready": true, "best_ms": -1, "runs": 0}],
  "round": {"round_id": 2, "track": "arena", "start_at": 0, "end_at": 0} }
```
Room objects also carry `max_players`, `phase_end_at`, `server_t`, `live` (bool) and `next`
(LIVE only: `{track, weather, duration_s}` of the round after the current one, else `null`);
`rooms` entries carry `live` too (the LIVE room is listed first).

Server rules: 4-letter room codes. A room is deleted when it's empty. If the host leaves, the
host passes to the next player. Round flow: `start` → phase `countdown` (start_at = now + 4000) →
`racing` at start_at → `results` at end_at (sends `round_end`) → `lobby` after 12 s. A late
joiner during `countdown` or `racing` receives `round_start` immediately. The server rejects
finishes that arrive after `end_at + 1500` ms or carry a stale round_id.

### LIVE room (session 6, `server/lib/rotation.js`)

An always-on public room with the code `LIVE` (generated codes never contain L or I). It has no host
(`host: -1`): `settings` and `start` are refused with `error {code: "live_room"}`, ready flags are
ignored. Joining it while idle starts a round straight away; a late joiner gets `round_start` at
once as usual. After a round, `results` lasts `LIVE_RESULTS_MS` (10 s) and then the next round of the
rotation starts by itself (`countdown` again, never `lobby` while anyone is in). When the last
player leaves it goes idle (`phase: "lobby"`, timers stopped). The rotation plays every track once per
cycle in a shuffled order, never the same track twice in a row, with a round length per track
(90–240 s, aiming at 6–12 runs) and the track's usual weather, sometimes a wet one. Capacity
`LIVE_MAX_PLAYERS` (12). Client: main menu "ONLINE · LIVE" → the online screen calls
`Net.join_live()` and the race starts on `round_start`; the race scene stays between LIVE rounds
(results show "NEXT UP" with a countdown; the next `round_start` reloads the race on the new track).
Tests: `server/test/live.test.js`, `tools/live_smoke_test.sh` (Godot clients).

## Testing & tooling

- `tools/godot_import.sh` imports assets (run once per checkout, and after adding assets).
- `tools/check_scripts.sh` compile-checks every `.gd` file. It must print `SCRIPT_ERRORS=0`.
- `tools/run_scene.sh <res://scene.tscn> [--compat|--headless] -- [--frames=N] [--shot=/abs/out.png] [--key=value...]`
  runs any scene under Xvfb with `--fixed-fps 60`. The `TestHooks` autoload reads the args after `--`:
  `--frames` auto-quits, `--shot`/`--shots=a.png@60,b.png@120` save screenshots, and scenes read
  other keys with `TestHooks.arg(key, default)`.
- `tools/export_web.sh [outdir]` creates the web export (default `server/public`).
- Each module puts its tests in `game/tests/<module>/`. Tests print `TEST_OK <name>` or
  `TEST_FAIL <name>: reason` through `TestHooks.ok/fail/check`, then call `TestHooks.finish()`.
