extends Node
## Lab: drives TmCarModel on ideal flat ground (four wheels in contact, planar body, no physics
## engine) and checks it against the reference model (tools/research/tmnf/tmnf_model.py) and the
## numbers in docs/research/tmnf_physics.md.
## Run: stadium/tools/run.sh res://tests/test_model_lab.tscn --headless

const T := preload("res://core/tm_tuning.gd")
const DT := 0.01


## Planar car on flat ground: forward/side speed in the car frame, yaw rate, position.
class Sim:
	var model := TmCarModel.new()
	var wheels: Array = []
	var v := Vector3.ZERO
	var w := Vector3.ZERO
	var heading := 0.0
	var pos := Vector2.ZERO
	var now_ms := 0
	var t := 0.0

	func _init(kmh: float = 0.0, surface: int = T.Surface.ASPHALT) -> void:
		v = Vector3(0.0, 0.0, kmh / 3.6)
		for i in 4:
			var wi := TmCarModel.WheelInput.new()
			wi.contact = true
			wi.surface = surface
			wi.pos = T.WHEELS[i]
			wheels.append(wi)

	func set_contact(on: bool) -> void:
		for wi in wheels:
			(wi as TmCarModel.WheelInput).contact = on

	func tick(gas: float, brake: float, steer: float) -> void:
		model.tick(DT, now_ms, gas, brake, steer, v, w, Vector3.UP, wheels, false)
		var f := model.force
		var tq := model.torque
		for i in 4:
			var wf: Vector3 = model.wheel_force[i]
			wf.y = 0.0   # the vertical part holds the car up on flat ground
			f += wf
			tq += (T.WHEELS[i] as Vector3).cross(wf)
		# semi-implicit Euler in the rotating car frame (same order as the reference model)
		v.z += (f.z + w.y * v.x) * DT
		v.x += (f.x - w.y * v.z) * DT
		w.y += tq.y / T.INERTIA.y * DT
		heading += w.y * DT
		var c := cos(heading)
		var s := sin(heading)
		pos += Vector2(v.z * s + v.x * c, v.z * c - v.x * s) * DT
		now_ms += 10
		t += DT

	func kmh() -> float:
		return v.z * 3.6

	func slip_deg() -> float:
		return rad_to_deg(atan2(absf(v.x), maxf(v.z, 1e-3)))


func _ready() -> void:
	_accel()
	_turns()
	_response()
	_brake()
	_drift()
	_coast_and_surfaces()
	_turbo()
	_walls_and_air()
	TestHooks.finish()


func _check(name: String, value: float, lo: float, hi: float, unit: String = "") -> void:
	if value >= lo and value <= hi:
		TestHooks.ok("%s (%.3f%s)" % [name, value, unit])
	else:
		TestHooks.fail(name, "%.3f%s outside [%.3f, %.3f]" % [value, unit, lo, hi])


func _time_to(kmh: float, surface: int = T.Surface.ASPHALT, limit: float = 60.0) -> float:
	var sim := Sim.new(0.0, surface)
	while sim.kmh() < kmh and sim.t < limit:
		sim.tick(1.0, 0.0, 0.0)
	return sim.t


func _accel() -> void:
	# reference: 0-100 1.74 s, 0-200 4.26 s, 0-300 8.21 s, 0-400 12.18 s
	_check("accel_0_100", _time_to(100.0), 1.70, 1.78, " s")
	_check("accel_0_200", _time_to(200.0), 4.18, 4.34, " s")
	_check("accel_0_300", _time_to(300.0), 8.05, 8.37, " s")
	_check("accel_0_400", _time_to(400.0), 11.95, 12.45, " s")


## Full lock with the speed held by the throttle: returns [radius m, yaw rad/s, slip deg, sliding].
func _steady_turn(kmh: float, secs: float = 3.0) -> Array:
	var sim := Sim.new(kmh)
	var max_slip := 0.0
	while sim.t < secs:
		sim.tick(1.0 if sim.kmh() < kmh else 0.0, 0.0, 1.0)
		if sim.t > 0.5:
			max_slip = maxf(max_slip, sim.slip_deg())
	var sp := Vector2(sim.v.x, sim.v.z).length()
	return [sp / absf(sim.w.y), sim.w.y, max_slip, sim.model.any_sliding]


func _turns() -> void:
	# reference full-lock radius: 9.6 m @ 50, 15.8 @ 100, 29.3 @ 150, 48.1 @ 200, 93.7 @ 300 km/h
	var ref := {50.0: 9.6, 100.0: 15.8, 150.0: 29.3, 200.0: 48.1, 300.0: 93.7, 400.0: 132.5}
	for k in ref:
		var r := _steady_turn(k)
		var tag := "turn_%d" % int(k)
		print("LAB turn %d km/h: radius %.1f m yaw %.2f rad/s slip %.1f deg sliding=%s" % [int(k), r[0], r[1], r[2], r[3]])
		_check(tag + "_radius", r[0], ref[k] * 0.93, ref[k] * 1.07, " m")
		_check(tag + "_slip", r[2], 0.0, 2.0, " deg")
		if r[3]:
			TestHooks.fail(tag + "_grip", "wheels sliding in a plain full-lock turn")


func _response() -> void:
	# yaw builds with a ~0.15 s time constant and dies as fast on release
	var sim := Sim.new(150.0)
	var steady := _steady_turn(150.0)[1] as float
	var t90 := -1.0
	while sim.t < 2.0:
		sim.tick(1.0 if sim.kmh() < 150.0 else 0.0, 0.0, 1.0)
		if t90 < 0.0 and sim.w.y >= 0.9 * steady:
			t90 = sim.t
	var t0 := sim.t
	var t10 := -1.0
	while sim.t < t0 + 2.0:
		sim.tick(1.0 if sim.kmh() < 150.0 else 0.0, 0.0, 0.0)
		if t10 < 0.0 and absf(sim.w.y) <= 0.1 * steady:
			t10 = sim.t - t0
	_check("response_turn_in_t90", t90, 0.05, 0.45, " s")
	_check("response_release_t10", t10, 0.05, 0.45, " s")


## Full brake down to 1 m/s (below that the car switches into reverse).
func _brake_stop(kmh: float) -> Array:
	var sim := Sim.new(kmh)
	var start := sim.pos
	while sim.v.z > 1.0 and sim.t < 30.0:
		sim.tick(0.0, 1.0, 0.0)
	return [sim.t, (sim.pos - start).length()]


func _brake() -> void:
	# reference, down to 1 m/s: 100 km/h 1.36 s / 12.9 m, 200 2.00 s / 39.2 m, 300 2.53 s / 76.1 m
	var r100 := _brake_stop(100.0)
	_check("brake_100_time", r100[0], 1.31, 1.41, " s")
	_check("brake_100_dist", r100[1], 12.2, 13.7, " m")
	var r200 := _brake_stop(200.0)
	_check("brake_200_time", r200[0], 1.94, 2.06, " s")
	_check("brake_200_dist", r200[1], 37.2, 41.2, " m")
	var r300 := _brake_stop(300.0)
	_check("brake_300_time", r300[0], 2.45, 2.61, " s")
	_check("brake_300_dist", r300[1], 72.3, 79.9, " m")


func _drift() -> void:
	# reference: brake tap 0.15 s + full lock from 200 km/h, 1.5 s: heading 99.7 deg, exit 223 km/h
	var sim := Sim.new(200.0)
	var tagged := false
	while sim.t < 1.65 - 1e-6:
		var tap := sim.t < 0.15
		sim.tick(0.0 if tap else 1.0, 1.0 if tap else 0.0, 1.0)
		if tap and sim.model.sliding.has(true):
			tagged = true
	if tagged:
		TestHooks.ok("drift_brake_flags_sliding")
	else:
		TestHooks.fail("drift_brake_flags_sliding", "a full brake at 200 km/h must hit the cap and flag the wheels")
	_check("drift_heading", rad_to_deg(sim.heading), 92.0, 107.0, " deg")
	_check("drift_exit", sim.kmh(), 212.0, 232.0, " km/h")


func _coast_and_surfaces() -> void:
	# coasting: dv/dt = -1 - 0.3 v -> from 200 km/h, 2 s: (v0 + 1/0.3) e^-0.6 - 1/0.3
	var sim := Sim.new(200.0)
	while sim.t < 2.0 - 1e-6:
		sim.tick(0.0, 0.0, 0.0)
	var v0 := 200.0 / 3.6
	var expect := ((v0 + 1.0 / 0.3) * exp(-0.6) - 1.0 / 0.3) * 3.6
	_check("coast_200_2s", sim.kmh(), expect - 1.5, expect + 1.5, " km/h")
	# no drag under throttle: 600 km/h -> stays on the 5.5 m/s^2 step
	var fast := Sim.new(600.0)
	fast.tick(1.0, 0.0, 0.0)
	_check("no_drag_under_throttle", (fast.v.z - 600.0 / 3.6) / DT, 5.49, 5.51, " m/s^2")
	# speed cap: push back above 1000 km/h
	var capped := Sim.new(1010.0)
	capped.tick(1.0, 0.0, 0.0)
	_check("speed_cap_push", (capped.v.z - 1010.0 / 3.6) / DT, -10.01, -9.99, " m/s^2")
	# grass: accel x0.4 -> 0-100 in 100/3.6/(16*0.4) = 4.34 s; dirt x0.9 -> 1.93 s (TMNF's runs:
	# 6.33 and 14.2 m/s^2 below 100 km/h, M10-3)
	_check("grass_0_100", _time_to(100.0, T.Surface.GRASS), 4.25, 4.45, " s")
	_check("dirt_0_100", _time_to(100.0, T.Surface.DIRT), 1.88, 2.0, " s")
	# braking on grass barely works: 30 x 0.05 + coasting 1 + 0.3 v (TMNF at 200-240 km/h: 20.7)
	var gb := Sim.new(220.0, T.Surface.GRASS)
	gb.tick(0.0, 1.0, 0.0)
	_check("grass_brake_220", (gb.v.z - 220.0 / 3.6) / DT, -21.0, -20.5, " m/s^2")
	# ice: accel x0.1, 2 s of throttle -> 1.6 m/s^2 x 2 s = 11.5 km/h
	var ice := Sim.new(0.0, T.Surface.ICE)
	while ice.t < 2.0:
		ice.tick(1.0, 0.0, 0.0)
	_check("ice_slow_drive", ice.kmh(), 10.5, 12.5, " km/h")
	# reverse: brake from a standstill backs up
	var rev := Sim.new(0.0)
	while rev.t < 2.0:
		rev.tick(0.0, 1.0, 0.0)
	_check("reverse_from_standstill", rev.kmh(), -200.0, -5.0, " km/h")


func _turbo() -> void:
	# yellow pad at 250 km/h: drive = 7 (curve) x 5 (turbo) + 7 (throttle) = 42 m/s^2
	var sim := Sim.new(250.0)
	for wi in sim.wheels:
		(wi as TmCarModel.WheelInput).surface = T.Surface.TURBO
		(wi as TmCarModel.WheelInput).pad_dir = Vector3(0, 0, 1)
	sim.tick(1.0, 0.0, 0.0)
	_check("turbo_yellow_drive", sim.model.drive_now, 41.99, 42.01, " m/s^2")
	# off the pad it lasts 250 ms more, then stops
	for wi in sim.wheels:
		(wi as TmCarModel.WheelInput).surface = T.Surface.ASPHALT
	var boosted := 0
	for i in 40:
		sim.tick(1.0, 0.0, 0.0)
		if sim.model.drive_now > 10.0:
			boosted += 1
	_check("turbo_yellow_duration", boosted * DT, 0.23, 0.27, " s")
	# red pad at 250 km/h: 7 x 20 + 7 = 147
	var red := Sim.new(250.0)
	for wi in red.wheels:
		(wi as TmCarModel.WheelInput).surface = T.Surface.TURBO2
		(wi as TmCarModel.WheelInput).pad_dir = Vector3(0, 0, 1)
	red.tick(1.0, 0.0, 0.0)
	_check("turbo_red_drive", red.model.drive_now, 146.99, 147.01, " m/s^2")


func _walls_and_air() -> void:
	# a wheel touching a wall: the 200 km/h slow-down curve (48 m/s^2) on top of the drive, 500 ms
	var sim := Sim.new(200.0)
	(sim.wheels[0] as TmCarModel.WheelInput).side_contact = true
	var before := sim.v.z
	sim.tick(1.0, 0.0, 0.0)
	(sim.wheels[0] as TmCarModel.WheelInput).side_contact = false
	_check("wall_slowdown_200", (sim.v.z - before) / DT, -37.5, -36.0, " m/s^2")
	var slowed := 1
	for i in 80:
		before = sim.v.z
		sim.tick(1.0, 0.0, 0.0)
		if (sim.v.z - before) / DT < 0.0:
			slowed += 1
	_check("wall_slowdown_duration", slowed * DT, 0.48, 0.53, " s")
	# air: 2.5 g gravity, 0.03 linear damping, steering adds no yaw torque, no drive
	var air := Sim.new(200.0)
	air.set_contact(false)
	air.tick(1.0, 0.0, 1.0)
	_check("air_gravity_coef", air.model.gravity_coef, 2.5, 2.5)
	_check("air_linear_damp", air.model.linear_damp, 0.03, 0.03)
	_check("air_no_steer_torque", absf(air.model.torque.y), 0.0, 1e-6)
	_check("air_no_drive", air.model.drive_now, 0.0, 0.0)
	# air: a yaw spin taken off the ground decays by 0.4|w| + 0.2|w|^2
	var spin := Sim.new(200.0)
	spin.set_contact(false)
	spin.w = Vector3(0.0, 2.0, 0.0)
	spin.tick(0.0, 0.0, 0.0)
	_check("air_spin_drag", spin.model.torque.y, -1.61, -1.59)
