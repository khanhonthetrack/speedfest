extends Node3D
## Race scene: Time Attack run logic for solo and online rounds.
##
## Builds the Track, the local Car (CarInput or AutoDriver), ChaseCamera, HUD, pause menu,
## results overlay, EngineAudio, the PB ghost and (online) one RemoteCar per other player.
##
## State machine:
##   COUNTDOWN (car frozen; 3-2-1-GO) -> RUNNING -> FINISHED (2.5 s) -> COUNTDOWN (1.5 s hold) ...
##   online: round end -> ROUND_OVER (results overlay) -> Game.to_lobby() when the room is back in "lobby".
## Run time = physics ticks x 1000/60 ms. Checkpoints must be passed in order; the finish only
## counts after all of them.
##
## Command-line (TestHooks) args: --track=id (solo, when launched directly), --autodrive,
## --test_track (use res://tests/race/test_track.gd), --gate_runner=<m/s> (test driver that moves
## the car along the path), --quit_after_round (quit when going back to the lobby).
## Prints "RACE <event> ..." lines for test harnesses.
## See docs/modules/race.md.

signal state_changed(new_state: int)
signal checkpoint_passed(index: int, ms: int)
signal run_finished(ms: int, is_pb: bool)
signal respawned
signal round_over

enum State { LOADING, COUNTDOWN, RUNNING, FINISHED, ROUND_OVER }

const TICK_MS := 1000.0 / 60.0
const FIRST_COUNTDOWN_MS := 3000
const RESTART_HOLD_MS := 1500
const FINISH_SHOW_MS := 2500
const MIN_FINISH_MS := 1000              # ignore a finish trigger right after GO (teleport artifacts)
const STUCK_RESPAWN_S := 3.0             # upside down and not moving for this long -> respawn
const RESULTS_FALLBACK_MS := 9000        # show results from the live leaderboard if round_end is late
const LOBBY_FALLBACK_MS := 25000         # go back to the lobby even if the room never says so
const DISCONNECT_LOBBY_MS := 2500

## Set before adding to the tree to race on a custom track (tests).
var track_override: Track = null

var track: Track
var car: Car
var camera: ChaseCamera
var hud: CanvasLayer
var pause_menu: CanvasLayer
var results_overlay: CanvasLayer
var ghost_player: GhostPlayer
var engine_audio: Node3D
var input_node: Node                     # CarInput or AutoDriver
var autodrive := false
var recorder := GhostRecorder.new()
var remote_cars: Dictionary = {}         # player id -> RemoteCar

var online := false
var round_id := 0
var start_at_local_ms := 0
var end_at_local_ms := 0

var state: int = State.LOADING
var run_ticks := 0
var next_cp := 0
var checkpoint_count := 0
var splits: Array[int] = []
var runs_finished := 0
var last_finish_ms := -1
var pb_ms := -1
var pb_splits: Array = []
var round_best_ms := -1

var _respawn_xf := Transform3D.IDENTITY
var _respawn_vel := Vector3.ZERO
var _sync_go_ms := -1                    # online first countdown: local ms of GO
var _countdown_ticks := 0
var _last_countdown_n := -1
var _finish_ticks := 0
var _upside_down_s := 0.0
var _paused := false
var _pause_closed_ms := -100000
var _round_over_ms := -1
var _results_shown := false
var _leaving := false
var _get_ready_shown := false
var _leaderboard: Array = []
var _minimap_others: Array = []


# --- setup ----------------------------------------------------------------------------------------

func _ready() -> void:
	autodrive = TestHooks.has_arg("autodrive")
	online = Game.mode == "online" and not Game.round_info.is_empty()
	if not online and TestHooks.has_arg("track") and get_tree().current_scene == self:
		Game.track_id = String(TestHooks.arg("track", Game.track_id))
	_build_world()
	_build_ui()
	_connect_signals()
	Audio.play_music("race")
	pb_ms = Profile.get_pb(track.track_id)
	_load_ghost()
	hud.set_best(pb_ms if not online else -1)
	hud.set_minimap(track.get_minimap_points())
	hud.set_checkpoints(0, checkpoint_count)
	hud.set_run_time(-1)
	if online:
		_setup_online()
	else:
		hud.set_round_time_left(-1)
		_begin_countdown(FIRST_COUNTDOWN_MS)
	_log("ready mode=%s track=%s online=%s cps=%d" % [Game.mode, track.track_id, online, checkpoint_count])


func _build_world() -> void:
	if track_override != null:
		track = track_override
	elif TestHooks.has_arg("test_track"):
		var tt: Script = load("res://tests/race/test_track.gd")
		track = tt.call("create")
	else:
		track = Track.build(Game.track_id)
	if track.get_parent() == null:
		add_child(track)
	checkpoint_count = track.checkpoint_count

	car = Car.create(Profile.get_config())
	car.name = "LocalCar"
	add_child(car)
	car.teleport(track.get_start_transform())
	car.frozen_controls = true
	if car.visual and car.visual.has_method("set_headlights_real"):
		car.visual.call("set_headlights_real", true)

	if autodrive:
		var drv := AutoDriver.new()
		drv.path = track.path
		input_node = drv
		if drv.has_signal("stuck"):
			drv.connect("stuck", _on_autodriver_stuck)
	else:
		input_node = CarInput.new()
	input_node.name = "Input"
	car.add_child(input_node)

	engine_audio = EngineAudio.new()
	engine_audio.name = "EngineAudio"
	car.add_child(engine_audio)
	engine_audio.call("setup", String(car.config.get("car", "kaze")), true)

	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.set_target(car)

	ghost_player = GhostPlayer.new()
	ghost_player.name = "PBGhost"
	add_child(ghost_player)

	if TestHooks.has_arg("gate_runner"):
		var runner_script: Script = load("res://tests/race/gate_runner.gd")
		var runner: Node = runner_script.new()
		runner.set("race", self)
		runner.set("speed", float(TestHooks.arg("gate_runner", 40.0)))
		add_child(runner)


func _build_ui() -> void:
	hud = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	pause_menu = (load("res://ui/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pause_menu)
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	results_overlay = (load("res://ui/results.tscn") as PackedScene).instantiate()
	add_child(results_overlay)
	results_overlay.visible = false
	var listener := PauseListener.new()
	listener.race = self
	add_child(listener)


func _connect_signals() -> void:
	track.checkpoint_reached.connect(_on_checkpoint_reached)
	track.finish_reached.connect(_on_finish_reached)
	if pause_menu.has_signal("resumed"):
		pause_menu.connect("resumed", close_pause)
	if pause_menu.has_signal("restart_requested"):
		pause_menu.connect("restart_requested", _on_pause_restart)
	if pause_menu.has_signal("quit_requested"):
		pause_menu.connect("quit_requested", _on_pause_quit)
	Settings.changed.connect(_on_settings_changed)


func _setup_online() -> void:
	var info := Game.round_info
	round_id = int(info.get("round_id", 0))
	start_at_local_ms = int(info.get("start_at_local_ms", Net.local_ms()))
	end_at_local_ms = int(info.get("end_at_local_ms", Net.local_ms() + 300000))
	Net.player_state.connect(_on_player_state)
	Net.player_left.connect(_on_player_left)
	Net.leaderboard_changed.connect(_on_leaderboard)
	Net.round_ended.connect(_on_round_ended)
	Net.room_changed.connect(_on_room_changed)
	Net.round_started.connect(_on_round_started)
	Net.disconnected.connect(_on_disconnected)
	if Net.has_signal("finish_result"):
		Net.connect("finish_result", _on_finish_result)
	_leaderboard = Net.leaderboard.duplicate() if not Net.leaderboard.is_empty() else _leaderboard_from_room()
	hud.set_leaderboard(_leaderboard, Net.my_id)
	_on_room_changed(Net.room)
	var now := Net.local_ms()
	if now >= end_at_local_ms:
		_begin_round_over()
	elif now < start_at_local_ms:
		_begin_countdown(0, start_at_local_ms)
	else:
		# Late joiner: first run right away (short hold so the car settles at the start line).
		_begin_countdown(RESTART_HOLD_MS)


# --- state machine --------------------------------------------------------------------------------

func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	_log("state %s" % State.keys()[s])
	_update_input_enabled()
	state_changed.emit(s)


## Puts the car at the start and starts a countdown. sync_go_ms >= 0: GO at that local time.
func _begin_countdown(duration_ms: int, sync_go_ms: int = -1) -> void:
	recorder.stop()
	ghost_player.hide_ghost()
	run_ticks = 0
	next_cp = 0
	splits.clear()
	_upside_down_s = 0.0
	_respawn_xf = track.get_start_transform()
	_respawn_vel = Vector3.ZERO
	car.teleport(_respawn_xf)
	car.frozen_controls = true
	if car.has_method("refill_nitro"):
		car.refill_nitro()
	camera.snap()
	_sync_go_ms = sync_go_ms
	_countdown_ticks = int(ceil(duration_ms / TICK_MS))
	_last_countdown_n = -1
	_get_ready_shown = false
	hud.set_checkpoints(0, checkpoint_count)
	hud.set_run_time(0)
	_set_state(State.COUNTDOWN)


func _countdown_remaining_ms() -> float:
	if _sync_go_ms >= 0:
		return float(_sync_go_ms - Net.local_ms())
	return _countdown_ticks * TICK_MS


func _tick_countdown() -> void:
	if _sync_go_ms < 0:
		_countdown_ticks -= 1
	var remaining := _countdown_remaining_ms()
	if remaining <= 0.0:
		_go()
		return
	var n := int(ceil(remaining / 1000.0))
	if n > 3:
		if not _get_ready_shown:
			_get_ready_shown = true
			hud.show_message("GET READY", minf(remaining / 1000.0 - 3.0, 4.0))
		return
	if n != _last_countdown_n:
		_last_countdown_n = n
		hud.show_countdown(n)
		Audio.play_sfx("countdown")


func _go() -> void:
	if _sync_go_ms >= 0:
		_log("go synced late_ms=%d" % (Net.local_ms() - _sync_go_ms))
	_sync_go_ms = -1
	run_ticks = 0
	car.frozen_controls = false
	hud.show_countdown(0)
	Audio.play_sfx("go")
	recorder.start()
	_set_state(State.RUNNING)


func get_run_ms() -> int:
	return int(round(run_ticks * TICK_MS))


func _physics_process(_delta: float) -> void:
	if state == State.LOADING:
		return
	if online and state != State.ROUND_OVER and Net.local_ms() >= end_at_local_ms:
		_begin_round_over()
	match state:
		State.COUNTDOWN:
			_tick_countdown()
		State.RUNNING:
			run_ticks += 1
			recorder.tick(get_run_ms(), car, float(car.controls.get("steer", 0.0)), car.get_flags())
			_check_auto_respawn(1.0 / 60.0)
		State.FINISHED:
			_finish_ticks -= 1
			if _finish_ticks <= 0:
				_begin_countdown(RESTART_HOLD_MS)
		State.ROUND_OVER:
			_tick_round_over()
	if online:
		var s := car.get_net_state()
		s["t"] = get_run_ms() if state == State.RUNNING else -1
		s["ts"] = Time.get_ticks_msec() % 100000000
		if state == State.FINISHED:
			s["fl"] = int(s.get("fl", 0)) | 32
		Net.send_state(s)


func _process(_delta: float) -> void:
	if state == State.LOADING or car == null:
		return
	camera.look_back = Input.is_action_pressed("look_back") and not _paused
	var speed := car.get_speed_kmh()
	hud.set_speed(absf(speed))
	hud.set_rpm(car.get_rpm_ratio(), car.get_gear())
	hud.set_nitro(car.get_nitro_amount(), car.is_nitro_active())
	match state:
		State.RUNNING:
			hud.set_run_time(get_run_ms())
		State.COUNTDOWN:
			hud.set_run_time(0)
	if online:
		hud.set_round_time_left(maxi(0, end_at_local_ms - maxi(Net.local_ms(), mini(start_at_local_ms, end_at_local_ms))))
	if state == State.RUNNING and ghost_player.has_ghost() and Settings.show_pb_ghost:
		ghost_player.set_time(run_ticks * TICK_MS)
	elif ghost_player.visible:
		ghost_player.hide_ghost()
	_update_minimap()
	if engine_audio:
		engine_audio.call("set_params", car.get_rpm_ratio(), float(car.controls.get("throttle", 0.0)),
			absf(speed), car.get_drift_amount(), car.is_nitro_active(), car.is_grounded())


func _update_minimap() -> void:
	_minimap_others.clear()
	for id in remote_cars:
		var rc: RemoteCar = remote_cars[id]
		if rc.visible:
			_minimap_others.append(Vector2(rc.global_position.x, rc.global_position.z))
	hud.set_minimap_cars(Vector2(car.global_position.x, car.global_position.z), _minimap_others)


# --- checkpoints and finish ------------------------------------------------------------------------

func _on_checkpoint_reached(body: Node, index: int) -> void:
	if body != car or state != State.RUNNING:
		return
	if index != next_cp:
		return # wrong order or duplicate
	var ms := get_run_ms()
	splits.append(ms)
	next_cp += 1
	var has_delta := index < pb_splits.size() and int(pb_splits[index]) > 0
	var delta := ms - int(pb_splits[index]) if has_delta else 0
	hud.show_split(ms, delta, has_delta)
	hud.set_checkpoints(next_cp, checkpoint_count)
	Audio.play_sfx("checkpoint")
	_store_respawn(index)
	if online:
		Net.send_checkpoint(round_id, index, ms)
	_log("checkpoint %d ms=%d delta=%s" % [index, ms, str(delta) if has_delta else "-"])
	checkpoint_passed.emit(index, ms)


func _store_respawn(index: int) -> void:
	var xf := car.global_transform
	var vel := car.linear_velocity
	var cp_xf := track.get_checkpoint_transform(index)
	# Keep the car's own pose (Trackmania style) unless it is airborne, tumbling or sideways:
	# then use the gate's pose with the speed along it.
	var fwd := -xf.basis.z
	var ok := car.is_grounded() and xf.basis.y.dot(cp_xf.basis.y) > 0.7
	if ok and vel.length() > 2.0:
		ok = fwd.dot(vel.normalized()) > 0.85
	if ok:
		_respawn_xf = xf.orthonormalized()
		_respawn_vel = vel
	else:
		_respawn_xf = cp_xf
		_respawn_vel = -cp_xf.basis.z * maxf(0.0, vel.dot(-cp_xf.basis.z))


func _on_finish_reached(body: Node) -> void:
	if body != car or state != State.RUNNING:
		return
	if next_cp < checkpoint_count or get_run_ms() < MIN_FINISH_MS:
		return
	_finish_run()


func _finish_run() -> void:
	var ms := get_run_ms()
	var prev_pb := Profile.get_pb(track.track_id)
	var car_id := String(car.config.get("car", "kaze"))
	var is_pb := Profile.submit_time(track.track_id, ms, car_id)
	var has_delta := prev_pb > 0
	var delta := ms - prev_pb if has_delta else 0
	var ghost := recorder.finish(ms, car, splits, track.track_id, car.config,
		float(car.controls.get("steer", 0.0)), car.get_flags())
	if is_pb:
		pb_ms = ms
		pb_splits = splits.duplicate()
		if ghost.is_empty():
			ghost = {"version": GhostRecorder.VERSION, "track": track.track_id, "car": car.config, "ms": ms, "splits": pb_splits.duplicate(), "samples": []}
		Profile.save_ghost(track.track_id, ghost)
		_load_ghost_dict(ghost)
	runs_finished += 1
	last_finish_ms = ms
	if online:
		if Net.local_ms() <= end_at_local_ms + 1000:
			Net.send_finish(round_id, ms)
		if round_best_ms < 0 or ms < round_best_ms:
			round_best_ms = ms
		hud.set_best(round_best_ms)
	else:
		hud.set_best(pb_ms)
	hud.set_run_time(ms)
	hud.show_finish(ms, is_pb, delta, has_delta)
	Audio.play_sfx("pb" if is_pb else "finish")
	_finish_ticks = int(ceil(FINISH_SHOW_MS / TICK_MS))
	_set_state(State.FINISHED)
	_log("finish ms=%d pb=%s delta=%s" % [ms, is_pb, str(delta) if has_delta else "-"])
	run_finished.emit(ms, is_pb)
	if autodrive:
		print("AUTODRIVE finish %d" % ms)


# --- respawn / restart -------------------------------------------------------------------------------

## Back to the last checkpoint with the speed it was passed at. The clock keeps running.
func respawn() -> void:
	if state != State.RUNNING:
		return
	car.teleport(_respawn_xf, _respawn_vel)
	camera.snap()
	_upside_down_s = 0.0
	Audio.play_sfx("respawn")
	_log("respawn cp=%d" % (next_cp - 1))
	respawned.emit()


## New run from the start line (1.5 s hold).
func restart_run() -> void:
	if state == State.ROUND_OVER or state == State.LOADING:
		return
	if state == State.COUNTDOWN and _sync_go_ms >= 0:
		return # synchronized round start: everyone waits for GO
	_begin_countdown(RESTART_HOLD_MS)
	_log("restart")


func _check_auto_respawn(dt: float) -> void:
	if car.global_position.y < track.kill_y:
		respawn()
		return
	var up := car.global_transform.basis.y
	if up.y < -0.3 and car.linear_velocity.length() < 3.0:
		_upside_down_s += dt
		if _upside_down_s > STUCK_RESPAWN_S:
			respawn()
	else:
		_upside_down_s = 0.0


func _on_autodriver_stuck() -> void:
	respawn()


# --- input --------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif _paused:
		return
	elif event.is_action_pressed("respawn"):
		respawn()
	elif event.is_action_pressed("restart"):
		restart_run()
	elif event.is_action_pressed("camera_cycle"):
		camera.cycle_mode()
		hud.show_message(camera.mode_name(), 1.0)
	elif event.is_action_pressed("leaderboard"):
		pass # HUD reads the action itself


func _update_input_enabled() -> void:
	var on := not _paused and (state == State.COUNTDOWN or state == State.RUNNING)
	if input_node == null:
		return
	if input_node is CarInput:
		(input_node as CarInput).enabled = on
	else:
		input_node.set_physics_process(on)
		if not on:
			car.controls["throttle"] = 0.0
			car.controls["brake"] = 0.0
			car.controls["steer"] = 0.0
			car.controls["handbrake"] = false
			car.controls["nitro"] = false
	if not on and state != State.COUNTDOWN and state != State.RUNNING:
		# Roll to a stop after the finish / round end.
		car.controls["brake"] = 0.3


func toggle_pause() -> void:
	if _paused:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	if _paused or _leaving or Time.get_ticks_msec() - _pause_closed_ms < 200:
		return
	_paused = true
	if pause_menu.has_method("open"):
		pause_menu.call("open")
	else:
		pause_menu.visible = true
	if not online:
		get_tree().paused = true
	_update_input_enabled()


func close_pause() -> void:
	if not _paused:
		return
	_paused = false
	_pause_closed_ms = Time.get_ticks_msec()
	if pause_menu.has_method("close"):
		pause_menu.call("close")
	else:
		pause_menu.visible = false
	get_tree().paused = false
	_update_input_enabled()


func _on_pause_restart() -> void:
	close_pause()
	restart_run()


func _on_pause_quit() -> void:
	close_pause()
	get_tree().paused = false
	if online:
		_go_lobby()
	else:
		_leaving = true
		Game.to_menu()


func _on_settings_changed() -> void:
	if camera and camera.mode != Settings.camera_mode:
		camera.set_mode(Settings.camera_mode)


# --- ghost --------------------------------------------------------------------------------------------

func _load_ghost() -> void:
	_load_ghost_dict(Profile.load_ghost(track.track_id))


func _load_ghost_dict(g: Dictionary) -> void:
	pb_splits = []
	if g.is_empty():
		return
	# Only trust splits from a ghost of the current PB.
	if int(g.get("ms", -1)) == pb_ms and typeof(g.get("splits")) == TYPE_ARRAY:
		var s: Array = g["splits"]
		if s.size() == checkpoint_count:
			pb_splits = s.duplicate()
	ghost_player.load_ghost(g)


# --- online -------------------------------------------------------------------------------------------

func _leaderboard_from_room() -> Array:
	var out: Array = []
	for p in Net.room.get("players", []):
		out.append({"id": int(p.get("id", -1)), "name": String(p.get("name", "?")),
			"car": String(p.get("car", {}).get("car", "")), "best_ms": -1, "runs": 0})
	return out


func _on_player_state(id: int, s: Dictionary) -> void:
	if id == Net.my_id:
		return
	var rc: RemoteCar = remote_cars.get(id)
	if rc == null:
		rc = _add_remote_car(id)
	rc.push_state(s)


func _add_remote_car(id: int) -> RemoteCar:
	var p := Net.get_player(id)
	var rc := RemoteCar.new()
	add_child(rc)
	rc.setup(id, String(p.get("name", "Player %d" % id)), p.get("car", CarDefs.default_config("kaze")))
	var ea := EngineAudio.new()
	rc.set_engine_audio(ea)
	ea.call("setup", rc.car_id, false)
	remote_cars[id] = rc
	_log("remote_car add id=%d name=%s" % [id, rc.player_name])
	return rc


func _remove_remote_car(id: int) -> void:
	var rc: RemoteCar = remote_cars.get(id)
	if rc:
		remote_cars.erase(id)
		rc.queue_free()
		_log("remote_car remove id=%d" % id)


func _on_player_left(id: int) -> void:
	_remove_remote_car(id)


func _on_room_changed(room: Dictionary) -> void:
	if _leaving:
		return
	if room.is_empty():
		_go_lobby()
		return
	var ids := {}
	for p in room.get("players", []):
		var pid := int(p.get("id", -1))
		ids[pid] = true
		if remote_cars.has(pid):
			(remote_cars[pid] as RemoteCar).update_config(String(p.get("name", "?")), p.get("car", {}))
	for id in remote_cars.keys():
		if not ids.has(id):
			_remove_remote_car(id)
	var phase := String(room.get("phase", ""))
	if phase == "results" and state != State.ROUND_OVER:
		_begin_round_over()
	elif phase == "lobby":
		_go_lobby()


func _on_leaderboard(entries: Array) -> void:
	_leaderboard = entries
	hud.set_leaderboard(entries, Net.my_id)
	for e in entries:
		if int(e.get("id", -1)) == Net.my_id and int(e.get("best_ms", -1)) > 0:
			round_best_ms = int(e["best_ms"])
			hud.set_best(round_best_ms)


func _on_finish_result(accepted: bool, ms: int, _best_ms: int, reason: String) -> void:
	_log("finish_result accepted=%s ms=%d reason=%s" % [accepted, ms, reason])
	if not accepted and reason != "slower" and reason != "round_over" and reason != "too_late":
		hud.show_message("Time not counted (%s)" % reason, 2.5)


func _begin_round_over() -> void:
	if state == State.ROUND_OVER:
		return
	recorder.stop()
	ghost_player.hide_ghost()
	_round_over_ms = Net.local_ms()
	car.frozen_controls = false
	_set_state(State.ROUND_OVER)
	hud.set_round_time_left(0)
	hud.show_message("TIME UP!", 3.0)
	for id in remote_cars:
		_log("remote_stats id=%d snapshots=%d" % [id, (remote_cars[id] as RemoteCar).snapshot_count])
	Audio.play_sfx("finish")
	round_over.emit()


func _tick_round_over() -> void:
	var waited := Net.local_ms() - _round_over_ms
	if not _results_shown and waited > RESULTS_FALLBACK_MS:
		_show_results(_leaderboard if not _leaderboard.is_empty() else _leaderboard_from_room())
	if waited > LOBBY_FALLBACK_MS:
		_go_lobby()


func _on_round_ended(res: Array) -> void:
	_begin_round_over()
	_show_results(res)


func _show_results(res: Array) -> void:
	_results_shown = true
	if _paused:
		close_pause()
	results_overlay.visible = true
	if results_overlay.has_method("show_results"):
		results_overlay.call("show_results", res, Net.my_id)
	_log("results %s" % JSON.stringify(res))


func _on_round_started(info: Dictionary) -> void:
	# A new round while we are still here (missed the lobby phase): restart the scene for it.
	if int(info.get("round_id", -1)) != round_id and not _leaving:
		_leaving = true
		Game.start_online_round(info)


func _on_disconnected(reason: String) -> void:
	if _leaving:
		return
	hud.show_message("Disconnected: %s" % reason, 3.0)
	get_tree().create_timer(DISCONNECT_LOBBY_MS / 1000.0).timeout.connect(_go_lobby)


func _go_lobby() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	_log("to_lobby")
	Game.to_lobby()
	if TestHooks.has_arg("quit_after_round"):
		TestHooks.finish()


func _exit_tree() -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false


func _log(text: String) -> void:
	print("RACE %s" % text)


## Receives the pause action while the tree is paused (the race itself doesn't process then).
class PauseListener:
	extends Node
	var race: Node

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(event: InputEvent) -> void:
		if race and race.get("_paused") and get_tree().paused and event.is_action_pressed("pause") and not event.is_echo():
			race.call("close_pause")
			get_viewport().set_input_as_handled()
