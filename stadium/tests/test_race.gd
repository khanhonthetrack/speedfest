extends Node
## Race layer test. Always: TmRace's rules (countdown, clock, checkpoints in any order, finish,
## laps, respawn point, medals) and TmTriggers' crossing test on placed blocks. With
## --tmnf=/path/to/TMNF it also races official tracks (--tracks=A01,B05 or all; default A01): the car
## rests on the start block through the countdown and accelerates on it, then is put before each
## checkpoint's respawn point and driven through its trigger, and finally through the finish,
## which must end the race.

const W := TmBlockCatalogue.Waypoint


func _ready() -> void:
	_rules()
	_laps()
	_triggers()
	var root: String = TestHooks.arg("tmnf", "")
	if root.is_empty():
		print("TEST_SKIP tracks: pass --tmnf=/path/to/TMNF to race the official tracks")
	else:
		var tracks := String(TestHooks.arg("tracks", "A01"))
		for track in (TmStage.campaign_tracks(root) if tracks == "all" else Array(tracks.split(","))):
			await _track(track)
	TestHooks.finish()


func _rules() -> void:
	var r := TmRace.new(3, 1)
	var started := [false]
	r.started.connect(func() -> void: started[0] = true)
	for i in 149:
		r.tick()
	TestHooks.check(r.state == TmRace.State.COUNTDOWN and not started[0], "countdown_holds", "%d" % r.countdown_ms)
	r.cross(5, W.CHECKPOINT)
	TestHooks.check(r.taken.is_empty(), "no_checkpoint_in_countdown")
	r.tick()
	TestHooks.check(r.state == TmRace.State.RACING and started[0] and r.time_ms == 0, "countdown_1500ms")
	for i in 123:
		r.tick()
	TestHooks.check(r.time_ms == 1230, "clock_10ms_ticks", "%d" % r.time_ms)
	r.cross(7, W.CHECKPOINT)
	r.cross(7, W.CHECKPOINT)
	r.cross(2, W.CHECKPOINT)
	TestHooks.check(r.taken.size() == 2 and r.respawn_index == 2, "checkpoints_once_any_order", "%s" % [r.taken])
	r.cross(9, W.FINISH)
	TestHooks.check(r.state == TmRace.State.RACING, "finish_needs_all_checkpoints")
	r.tick()
	r.cross(4, W.CHECKPOINT)
	r.cross(9, W.FINISH)
	TestHooks.check(r.state == TmRace.State.FINISHED and r.finish_ms == 1240 and r.splits == [1230, 1230, 1240, 1240],
		"finish_time", "%d %s" % [r.finish_ms, r.splits])
	r.tick()
	TestHooks.check(r.time_ms == 1240, "clock_stops_at_finish")
	r.restart()
	TestHooks.check(r.state == TmRace.State.COUNTDOWN and r.time_ms == 0 and r.taken.is_empty() and r.respawn_index == -1,
		"restart_resets")
	var ch := TmChallenge.new()
	ch.author_ms = 24540
	ch.gold_ms = 26000
	ch.silver_ms = 30000
	ch.bronze_ms = 37000
	TestHooks.check(TmRace.medal(24540, ch) == "author" and TmRace.medal(25000, ch) == "gold"
		and TmRace.medal(36990, ch) == "bronze" and TmRace.medal(40000, ch) == "", "medals")
	TestHooks.check(TmRace.time_text(83450) == "1:23.45", "time_text", TmRace.time_text(83450))


func _laps() -> void:
	var r := TmRace.new(2, 3)
	for i in 150:
		r.tick()
	r.cross(0, W.START_FINISH)
	TestHooks.check(r.lap == 0, "lap_line_needs_checkpoints")
	var laps_seen := []
	r.lap_done.connect(func(l: int, _ms: int) -> void: laps_seen.append(l))
	for lap in 3:
		r.tick()
		r.cross(1, W.CHECKPOINT)
		r.cross(2, W.CHECKPOINT)
		r.cross(0, W.START_FINISH)
		if lap < 2:
			TestHooks.check(r.respawn_index == 0 and r.taken.is_empty(), "lap_%d_resets_checkpoints" % (lap + 1))
	TestHooks.check(r.state == TmRace.State.FINISHED and r.lap == 3 and laps_seen == [1, 2] and r.finish_ms == 30,
		"three_laps", "%d %s %d" % [r.lap, laps_seen, r.finish_ms])


## A world point from block-local TMNF coordinates of a block placed at xf.
static func _w(xf: Transform3D, x: float, y: float, z: float) -> Vector3:
	return xf * Vector3(-x, y, z)


func _triggers() -> void:
	var cp := TmTriggers.of("StadiumRoadMainCheckpoint")
	TestHooks.check(not cp.is_empty() and TmTriggers.of("StadiumRoadMainStartLine").is_empty(), "trigger_table")
	var entry := TmBlockCatalogue.info("StadiumRoadMainCheckpoint")
	for dir in 4:
		var xf := TmBlockCatalogue.block_transform(entry, Vector3i(5, 2, 7), dir, false)
		var t := TmTriggers.crossed(cp, xf, _w(xf, 16, 2.5, 10), _w(xf, 16, 2.5, 22))
		TestHooks.check(absf(t - 0.5) < 0.001, "road_gate_dir%d" % dir, "%.3f" % t)
		var back := TmTriggers.crossed(cp, xf, _w(xf, 20, 2.5, 17), _w(xf, 20, 2.5, 15))
		TestHooks.check(back >= 0.0, "road_gate_either_way_dir%d" % dir)
		var beside := TmTriggers.crossed(cp, xf, _w(xf, 1.0, 2.5, 10), _w(xf, 1.0, 2.5, 22))
		var over := TmTriggers.crossed(cp, xf, _w(xf, 16, 9.0, 10), _w(xf, 16, 9.0, 22))
		var short := TmTriggers.crossed(cp, xf, _w(xf, 16, 2.5, 10), _w(xf, 16, 2.5, 15.9))
		TestHooks.check(beside < 0.0 and over < 0.0 and short < 0.0, "road_gate_misses_dir%d" % dir,
			"%.2f %.2f %.2f" % [beside, over, short])
	var fin := TmTriggers.of("StadiumRoadMainFinishLine")
	var xf0 := TmBlockCatalogue.block_transform(TmBlockCatalogue.info("StadiumRoadMainFinishLine"), Vector3i(1, 1, 1), 0, true)
	var tf := TmTriggers.crossed(fin, xf0, _w(xf0, 16, 2.0, 11.0), _w(xf0, 16, 2.0, 13.0))
	TestHooks.check(absf(tf - 0.5) < 0.001, "finish_gate_at_z12", "%.3f" % tf)
	var ring := TmTriggers.of("StadiumCheckpointRingV")
	var through := TmTriggers.crossed(ring, xf0, _w(xf0, 16, 16, 10), _w(xf0, 16, 16, 20))
	var outside := TmTriggers.crossed(ring, xf0, _w(xf0, 16, 1.0, 10), _w(xf0, 16, 1.0, 20))
	TestHooks.check(through >= 0.0 and outside < 0.0, "ring_gate")
	var left := TmTriggers.of("StadiumPlatformCheckpointLeft")
	var right := TmTriggers.of("StadiumPlatformCheckpointRight")
	var a := _w(xf0, 28, 22.5, 15)
	var b := _w(xf0, 28, 22.5, 17)
	TestHooks.check(TmTriggers.crossed(right, xf0, a, b) >= 0.0 and TmTriggers.crossed(left, xf0, a, b) < 0.0,
		"platform_tilt_gates_mirrored")


## Race an official track: rest through the countdown, launch, then every checkpoint and the finish.
func _track(track: String) -> void:
	TestHooks.args["track"] = track
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var race: TmRace = scene.race
	var car: TmCar = scene.car
	var builder: TmMapBuilder = scene.builder
	scene.input.set_physics_process(false)   # the test drives
	var p0 := car.global_position
	for i in TmRace.COUNTDOWN_MS / TmRace.TICK_MS + 100:
		await get_tree().physics_frame
	TestHooks.check(race.state == TmRace.State.RACING and absi(race.time_ms - 1000) <= 10, "%s_countdown" % track,
		"%s %d" % [race.state, race.time_ms])
	TestHooks.check(not car.wheel_contact.has(false) and car.global_position.distance_to(p0) < 0.3,
		"%s_rests_on_start" % track, "contacts %s, moved %.2f m" % [car.wheel_contact, car.global_position.distance_to(p0)])
	car.gas = 1.0
	for i in 100:
		await get_tree().physics_frame
	TestHooks.check(car.speed_kmh() > 45.0 and not car.wheel_contact.has(false), "%s_launch" % track,
		"%.0f km/h after 1 s, contacts %s" % [car.speed_kmh(), car.wheel_contact])
	# every checkpoint, then the finish (each lap for a lap race)
	var cps := []
	var goal := -1
	for i in builder.waypoints.size():
		var k := int(builder.waypoints[i]["kind"])
		if k == W.CHECKPOINT:
			cps.append(i)
		elif k == W.FINISH or (k == W.START_FINISH and goal < 0):
			goal = i
	# waypoint blocks not recreated yet have no floor: they are taken by hand (race.cross)
	var unbuilt := []
	for i in builder.waypoints.size():
		if not bool(builder.waypoints[i]["built"]):
			unbuilt.append(String(builder.waypoints[i]["block"]))
	var missed := []
	for lap in race.laps:
		for i in cps:
			if not await _drive_through(scene, i):
				missed.append(i)
		if goal >= 0:
			if not await _drive_through(scene, goal):
				missed.append(goal)
	TestHooks.check(missed.is_empty(), "%s_waypoints_%d" % [track, cps.size() + 1],
		"missed %s" % [missed.map(func(i: int) -> String: return String(builder.waypoints[i]["block"]))])
	TestHooks.check(race.state == TmRace.State.FINISHED and race.finish_ms > 0, "%s_finish" % track,
		"state %s, lap %d, %d/%d checkpoints, goal %d" % [race.state, race.lap, race.taken.size(), race.checkpoint_count, goal])
	print("%s: %d checkpoints, %d lap(s), finished at %s%s" % [track, cps.size(), race.laps, TmRace.time_text(race.finish_ms),
		(", not recreated yet (taken by hand): %s" % [unbuilt]) if not unbuilt.is_empty() else ""])
	scene.respawn()
	TestHooks.check(race.state == TmRace.State.COUNTDOWN and race.time_ms == 0, "%s_restart_after_finish" % track)
	scene.queue_free()
	await get_tree().physics_frame


## Put the car on a waypoint block before its respawn point (which can sit on the trigger itself),
## up to 10 m back but inside the block, at 25 m/s, and drive on until it takes the waypoint. A
## block not recreated yet (no floor) is taken by hand.
func _drive_through(scene: Node, index: int) -> bool:
	var race: TmRace = scene.race
	var car: TmCar = scene.car
	var wp: Dictionary = scene.builder.waypoints[index]
	if not bool(wp["built"]):
		race.cross(index, int(wp["kind"]))
		return true
	var before := _progress(race)
	var spawn: Transform3D = wp["spawn"]
	var local_z := ((wp["xform"] as Transform3D).affine_inverse() * spawn.origin).z
	# on a slope the road 10 m back can be up to 5 m higher than the spawn
	scene.place_car(spawn.translated(-spawn.basis.z * clampf(local_z - 1.0, 0.0, 10.0)), 6.0)
	car.lin_vel = car.global_transform.basis.z * 25.0
	car.gas = 1.0
	for i in 150:
		await get_tree().physics_frame
		if _progress(race) != before:
			return true
	return false


static func _progress(race: TmRace) -> int:
	return race.taken.size() + race.lap * 1000 + (100000 if race.state == TmRace.State.FINISHED else 0)
