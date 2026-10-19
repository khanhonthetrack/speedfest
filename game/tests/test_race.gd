extends Node3D
## Race logic without a driver: the track is built, the car is teleported around the lap, and the
## checkpoints, the lap counter and the respawn point have to follow. Also checks the circuits
## themselves (closed, smooth, wide enough) and the nitrous meter.

var race: Race
var cps: Array[int] = []
var laps_done: Array[int] = []


func _ready() -> void:
	_tracks_are_sane()
	_build()


func _tracks_are_sane() -> void:
	for id: String in TrackDefs.IDS:
		var path := TrackDefs.build_path(id)
		TestHooks.check(path.length > 800.0, "%s is a real lap" % id, "%.0f m" % path.length)
		TestHooks.check(path.is_circuit, "%s is a circuit" % id)
		# the loop closes: the start and the end of the baked curve are the same place
		var gap := path.sample_position(0.0).distance_to(path.sample_position(path.length - 0.01))
		TestHooks.check(gap < 2.0, "%s closes" % id, "%.2f m" % gap)
		# no kink sharper than a hairpin anywhere on the lap
		var worst := 0.0
		var d := 0.0
		while d < path.length:
			var a := path.sample_position(d)
			var b := path.sample_position(fposmod(d + 8.0, path.length))
			var c := path.sample_position(fposmod(d + 16.0, path.length))
			var v1 := b - a
			var v2 := c - b
			v1.y = 0.0
			v2.y = 0.0
			if v1.length() > 0.1 and v2.length() > 0.1:
				worst = maxf(worst, absf(v1.normalized().angle_to(v2.normalized())))
			d += 8.0
		TestHooks.check(worst < 0.95, "%s has no kinks" % id, "%.2f rad per 8 m" % worst)
		TestHooks.check(path.width_at(0.0) >= 12.0, "%s is wide enough to race on" % id,
			str(path.width_at(0.0)))
		var def := TrackDefs.get_def(id)
		TestHooks.check((def["checkpoints"] as Array).size() >= 3, "%s has checkpoints" % id)
		TestHooks.check((def["pads"] as Array).size() >= 1, "%s has boost pads" % id)


func _build() -> void:
	# the logic test runs without the city: it tests timing, not towers
	TestHooks.args["nocity"] = "true"
	TestHooks.args["laps"] = "3"
	race = Race.new()
	add_child(race)
	await get_tree().process_frame
	TestHooks.check(race.path != null and race.path.length > 0.0, "the track built")
	TestHooks.check(race.car != null, "the car is on the grid")
	TestHooks.check(race.city == null, "the logic test runs without the city")
	race.checkpoint_passed.connect(func(i: int, _t: int) -> void: cps.append(i))
	race.lap_done.connect(func(l: int, _t: int, _b: bool) -> void: laps_done.append(l))
	_check_start()
	await _drive_a_lap()
	_check_drive()
	_check_boost()
	_check_respawn()
	TestHooks.finish()


func _check_start() -> void:
	var start: Transform3D = race.info["start"]
	var on_road := race.path.edge_clearance(start.origin)
	TestHooks.check(on_road < 0.5, "the grid slot is on the road", "%.2f m past the edge" % on_road)
	# the car faces the way the track goes
	var ahead := race.path.sample_position(30.0) - race.path.sample_position(0.0)
	var facing := race.car.global_transform.basis.z
	TestHooks.check(facing.normalized().dot(ahead.normalized()) > 0.9, "the car faces the first corner",
		"%.2f" % facing.normalized().dot(ahead.normalized()))
	TestHooks.check(race.car.global_transform.origin.y > race.path.sample_position(0.0).y,
		"the car sits on the road, not in it")


## Teleport the car around the lap and watch the race logic follow.
func _drive_a_lap() -> void:
	race.started = true
	race.car.controls_enabled = true
	var n := 240
	for i in range(1, n + 1):
		var d := race.path.length * float(i) / float(n)
		var t := race.path.sample_transform(fposmod(d, race.path.length))
		race.car.place(Transform3D(Basis(-t.basis.x, t.basis.y, -t.basis.z), t.origin))
		await get_tree().process_frame
	var expected: int = (race.info["checkpoints"] as Array).size()
	TestHooks.check(cps.size() >= expected - 1, "every checkpoint fired",
		"%d of %d: %s" % [cps.size(), expected, str(cps)])
	var ordered := true
	for i in cps.size():
		if cps[i] != i % expected:
			ordered = false
	TestHooks.check(ordered, "checkpoints fired in order", str(cps))
	TestHooks.check(laps_done.size() == 1 and laps_done[0] == 1, "one lap counted", str(laps_done))
	TestHooks.check(race.lap == 2, "the lap counter moved on", str(race.lap))
	TestHooks.check(Game.best_lap(race.track_id, race.car.car_id) > 0, "the lap time was recorded")


## Actually drive: full throttle down the main straight for 4 s of simulation (stepped by hand at
## 100 Hz). The car has to gain speed, stay on the road surface and keep its wheels on the ground.
func _check_drive() -> void:
	race.car.configure(race.car.car_id, _with_nitrous(race.car.car_id))
	race._place_at(10.0)
	race.car.controls_enabled = true
	# the player's input node would zero the throttle every physics frame
	for n in get_tree().get_nodes_in_group("car_input"):
		n.queue_free()
	var ticks := 400
	var on_ground := 0
	var asphalt := 0
	for i in ticks:
		race.car.gas = 1.0
		race.car.brake = 0.0
		race.car.steer = 0.0
		race.car.step_tick()
		if race.car.wheel_contact.has(true):
			on_ground += 1
		if race.car.body.wheel_surface[0] == TrackBuilder.SURFACE_ASPHALT \
				or race.car.body.wheel_surface[0] == TrackBuilder.SURFACE_TURBO:
			asphalt += 1
	var kmh := race.car.speed_kmh()
	TestHooks.check(kmh > 90.0, "full throttle gets the car moving", "%.0f km/h" % kmh)
	TestHooks.check(on_ground > ticks * 0.9, "the wheels stay on the road",
		"%d of %d ticks" % [on_ground, ticks])
	TestHooks.check(asphalt > ticks * 0.8, "and on the track surface",
		"%d of %d ticks" % [asphalt, ticks])
	var clear := race.path.edge_clearance(race.car.global_transform.origin)
	TestHooks.check(clear < 2.0, "it is still between the barriers", "%.1f m" % clear)
	race.car.gas = 0.0


func _check_boost() -> void:
	var car := race.car
	car.configure(car.car_id, _with_nitrous(car.car_id))
	TestHooks.check(car.boost_tank > 0.0, "the bottle is fitted", str(car.boost_tank))
	car.boost_meter = 1.0
	car.boost_input = true
	var top_before := car.model.max_speed
	car.step_tick()
	TestHooks.check(car.boosting, "the nitrous lights up")
	TestHooks.check(car.body.extra_accel.length() > 1.0, "it pushes the car", str(car.body.extra_accel))
	TestHooks.check(car.model.max_speed > top_before, "it lifts the speed cap")
	TestHooks.check(car.boost_meter < 1.0, "the bottle drains", str(car.boost_meter))
	var drained := car.boost_meter
	car.boost_input = false
	car.lin_vel = car.global_transform.basis.z * 40.0
	for i in 20:
		car.step_tick()
	TestHooks.check(not car.boosting, "it stops when you let go")
	TestHooks.check(car.body.extra_accel == Vector3.ZERO, "and stops pushing")
	TestHooks.check(car.boost_meter > drained, "the bottle refills as you drive",
		"%.3f -> %.3f" % [drained, car.boost_meter])


func _with_nitrous(car_id: String) -> Dictionary:
	var s := Tuning.default_setup(car_id)
	s["nitrous"] = 2
	return s


func _check_respawn() -> void:
	# drop the car far off the track and ask for a respawn
	race.car.place(Transform3D(Basis(), race.path.sample_position(400.0) + Vector3(0, 60, 180)))
	race.respawn()
	var p := race.car.global_transform.origin
	var clear := race.path.edge_clearance(p)
	TestHooks.check(clear < 1.0, "respawn puts the car back on the road", "%.2f m" % clear)
	TestHooks.check(race.car.lin_vel.length() < 0.01, "and at a standstill")
	var up := race.car.global_transform.basis.y.dot(Vector3.UP)
	TestHooks.check(up > 0.9, "the right way up", str(up))
	# the safety net: a car that falls out of the world is picked up without being asked
	race.car.place(Transform3D(Basis(), race.path.sample_position(200.0) + Vector3(0, -120, 0)))
	race._track_progress(0.016)
	var y := race.car.global_transform.origin.y
	TestHooks.check(y > race.path.sample_position(200.0).y - 25.0,
		"a car that falls through the world is rescued", "y=%.1f" % y)
