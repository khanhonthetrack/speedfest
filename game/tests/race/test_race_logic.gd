extends Node
## Headless logic test of the race state machine on the race module's own test track.
## Run: tools/run_scene.sh res://tests/race/test_race_logic.tscn --headless -- --frames=4000

const TRACK_ID := "race_test"

var race: Node
var track: Track
var car: Car
var cp_events: Array = []
var finish_events: Array = []


func _ready() -> void:
	_run.call_deferred()


func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func until(cond: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func put(xf: Transform3D, vel := Vector3.ZERO) -> void:
	car.teleport(xf, vel)


func through_gate(i: int) -> void:
	# Out of all gates first (between gates), then into the gate.
	var tt: Variant = track
	var g: Transform3D = tt.gate_transform(i)
	put(Transform3D(g.basis, g.origin + g.basis.z * 8.0), -g.basis.z * 30.0)
	await ticks(2)
	put(g, -g.basis.z * 30.0)
	await ticks(3)


func _run() -> void:
	# Clean slate for the test track.
	Profile.pbs.erase(TRACK_ID)
	Profile.save_ghost(TRACK_ID, {})
	Game.mode = "solo"
	Game.round_info = {}
	Game.track_id = TRACK_ID
	race = (load("res://race/race.tscn") as PackedScene).instantiate()
	track = load("res://tests/race/test_track.gd").create()
	race.set("track_override", track)
	add_child(race)
	car = race.get("car")
	race.connect("checkpoint_passed", func(i: int, ms: int) -> void: cp_events.append([i, ms]))
	race.connect("run_finished", func(ms: int, pb: bool) -> void: finish_events.append([ms, pb]))
	TestHooks.check(car != null and race.get("camera") != null and race.get("hud") != null, "race_builds", "car/camera/hud missing")
	TestHooks.check(int(race.get("state")) == 1, "starts_in_countdown", "state=%d" % int(race.get("state")))
	TestHooks.check(car.frozen_controls, "frozen_during_countdown")
	var start_xf: Transform3D = track.get_start_transform()
	TestHooks.check(car.global_position.distance_to(start_xf.origin) < 0.5, "car_at_start", str(car.global_position))

	# Gates during the countdown are ignored.
	track.checkpoint_reached.emit(car, 0)
	TestHooks.check(int(race.get("next_cp")) == 0, "cp_ignored_in_countdown")

	var t0 := Engine.get_physics_frames()
	var went := await until(func() -> bool: return int(race.get("state")) == 2, 400)
	var waited := Engine.get_physics_frames() - t0
	TestHooks.check(went, "countdown_to_running")
	TestHooks.check(absi(waited - 180) <= 3, "countdown_3s", "took %d ticks" % waited)
	TestHooks.check(not car.frozen_controls, "unfrozen_at_go")

	# Order enforcement: wrong gates and an early finish are ignored.
	track.checkpoint_reached.emit(car, 1)
	track.checkpoint_reached.emit(car, 2)
	TestHooks.check(int(race.get("next_cp")) == 0, "wrong_cp_ignored", "next_cp=%d" % int(race.get("next_cp")))
	await ticks(70)
	track.finish_reached.emit(car)
	TestHooks.check(int(race.get("state")) == 2, "early_finish_ignored")

	# Real Area3D gate 0.
	await through_gate(0)
	TestHooks.check(int(race.get("next_cp")) == 1, "gate0_area_detected", "next_cp=%d" % int(race.get("next_cp")))
	TestHooks.check(cp_events.size() == 1 and cp_events[0][0] == 0, "cp_event0", str(cp_events))
	# Duplicate gate 0 ignored.
	await through_gate(0)
	TestHooks.check(int(race.get("next_cp")) == 1 and cp_events.size() == 1, "duplicate_cp_ignored")
	var split0: int = cp_events[0][1]
	TestHooks.check(split0 > 0 and split0 % 1 == 0, "split_recorded", str(split0))

	# Run time = ticks * 1000/60.
	var rt: int = race.call("get_run_ms")
	var rticks: int = race.get("run_ticks")
	TestHooks.check(rt == int(round(rticks * 1000.0 / 60.0)), "run_time_from_ticks")

	# Respawn: fall below kill_y -> back at checkpoint 0, clock running.
	var before_ms: int = race.call("get_run_ms")
	put(Transform3D(Basis.IDENTITY, Vector3(0, -30, 0)))
	await ticks(3)
	var g0: Transform3D = (track as Variant).gate_transform(0)
	TestHooks.check(car.global_position.distance_to(g0.origin) < 4.0, "auto_respawn_kill_y", str(car.global_position))
	TestHooks.check(int(race.get("state")) == 2 and int(race.call("get_run_ms")) > before_ms, "clock_keeps_running")
	# Manual respawn too, with the gate's speed.
	put(Transform3D(Basis.IDENTITY, Vector3(5, 1, -200)))
	await ticks(1)
	race.call("respawn")
	await ticks(1)
	TestHooks.check(car.global_position.distance_to(g0.origin) < 4.0, "manual_respawn", str(car.global_position))
	TestHooks.check(-car.linear_velocity.z > 10.0, "respawn_keeps_speed", str(car.linear_velocity))

	await through_gate(1)
	await through_gate(2)
	TestHooks.check(int(race.get("next_cp")) == 3, "all_cps", "next_cp=%d" % int(race.get("next_cp")))
	await through_gate(-2)
	TestHooks.check(int(race.get("state")) == 3, "finished", "state=%d" % int(race.get("state")))
	TestHooks.check(finish_events.size() == 1 and finish_events[0][1] == true, "first_finish_is_pb", str(finish_events))
	var run1: int = finish_events[0][0] if finish_events.size() > 0 else -1
	TestHooks.check(Profile.get_pb(TRACK_ID) == run1, "pb_saved", "%d vs %d" % [Profile.get_pb(TRACK_ID), run1])
	var ghost := Profile.load_ghost(TRACK_ID)
	TestHooks.check(GhostRecorder.is_valid_ghost(ghost), "ghost_saved", "keys=%s" % str(ghost.keys()))
	TestHooks.check(ghost.get("splits", []).size() == 3 and int(ghost.get("ms", 0)) == run1, "ghost_splits")
	var expect_samples := run1 / 50
	TestHooks.check(absi(ghost.get("samples", []).size() - expect_samples) <= 3, "ghost_20hz", "%d samples for %d ms" % [ghost.get("samples", []).size(), run1])
	TestHooks.check(car.get_node("Input") is CarInput and not (car.get_node("Input") as CarInput).enabled, "input_off_after_finish")

	# FINISHED (2.5 s) -> COUNTDOWN (1.5 s) -> RUNNING.
	t0 = Engine.get_physics_frames()
	await until(func() -> bool: return int(race.get("state")) == 1, 400)
	var fin_ticks := Engine.get_physics_frames() - t0
	TestHooks.check(absi(fin_ticks - 150) <= 6, "finish_shows_2_5s", "%d ticks" % fin_ticks)
	TestHooks.check(car.global_position.distance_to(start_xf.origin) < 1.0, "back_at_start")
	t0 = Engine.get_physics_frames()
	await until(func() -> bool: return int(race.get("state")) == 2, 400)
	var hold := Engine.get_physics_frames() - t0
	TestHooks.check(absi(hold - 90) <= 3, "restart_hold_1_5s", "%d ticks" % hold)
	TestHooks.check((race.get("pb_splits") as Array).size() == 3, "pb_splits_loaded")
	var gp: GhostPlayer = race.get("ghost_player")
	TestHooks.check(gp.has_ghost(), "ghost_player_loaded")
	await ticks(5)
	await RenderingServer.frame_post_draw if not DisplayServer.get_name() == "headless" else get_tree().process_frame
	await get_tree().process_frame
	TestHooks.check(gp.visible == Settings.show_pb_ghost, "ghost_visible_in_run")

	# Second run faster: gates quickly -> split deltas negative, new PB.
	cp_events.clear()
	await ticks(30)
	await through_gate(0)
	TestHooks.check(cp_events.size() == 1 and cp_events[0][1] < split0, "faster_split", str(cp_events))
	# Restart mid-run.
	race.call("restart_run")
	TestHooks.check(int(race.get("state")) == 1 and int(race.get("next_cp")) == 0, "restart_resets")
	await until(func() -> bool: return int(race.get("state")) == 2, 200)
	await ticks(65)
	for i in 3:
		await through_gate(i)
	await through_gate(-2)
	TestHooks.check(finish_events.size() == 2 and finish_events[1][1] == true and finish_events[1][0] < run1, "second_run_pb", str(finish_events))
	TestHooks.check(Profile.get_pb(TRACK_ID) == finish_events[1][0], "pb_updated")
	# Slower run is not a PB.
	await until(func() -> bool: return int(race.get("state")) == 2, 400)
	await ticks(600)
	for i in 3:
		await through_gate(i)
	await through_gate(-2)
	TestHooks.check(finish_events.size() == 3 and finish_events[2][1] == false, "slower_not_pb", str(finish_events))
	TestHooks.check(Profile.get_pb(TRACK_ID) == finish_events[1][0], "pb_kept")

	# Pause (solo pauses the tree).
	race.call("open_pause")
	TestHooks.check(get_tree().paused, "solo_pause_pauses_tree")
	race.call("close_pause")
	TestHooks.check(not get_tree().paused, "unpause")

	# Cleanup
	Profile.pbs.erase(TRACK_ID)
	Profile.save()
	TestHooks.finish()
