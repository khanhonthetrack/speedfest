extends Node3D
## Lab: the TmCar on curved geometry (TestArena): 15 deg kicker, helix loop, wall-ride pipe.
## Run: stadium/tools/run.sh res://tests/test_car_shapes.tscn --headless

const T := preload("res://core/tm_tuning.gd")

var car: TmCar
var _frames := 0
var _done := false


func _ready() -> void:
	add_child(TestArena.new())
	car = TmCar.new()
	car.set_physics_process(false)
	add_child(car)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 3 or _done:
		return
	_done = true
	_kicker()
	_loop(250.0, true)
	_loop(180.0, false)
	_pipe()
	TestHooks.finish()


func _check(name: String, value: float, lo: float, hi: float, unit: String = "") -> void:
	if value >= lo and value <= hi:
		TestHooks.ok("%s (%.3f%s)" % [name, value, unit])
	else:
		TestHooks.fail(name, "%.3f%s outside [%.3f, %.3f]" % [value, unit, lo, hi])


func _place(at: Vector3, heading_deg: float, kmh: float) -> void:
	car.place(Transform3D(Basis(Vector3.UP, deg_to_rad(heading_deg)), at))
	car.gas = 0.0
	car.brake = 0.0
	car.steer = 0.0
	for i in 20:
		car.step_tick()
	car.lin_vel = car.global_transform.basis.z * kmh / 3.6


func _kicker() -> void:
	_place(Vector3(0, 0, 60), 0.0, 200.0)
	car.gas = 1.0
	var t := 0.0
	var streak := 0
	var best := 0
	var top := 0.0
	var min_up := 1.0
	var body := false
	while t < 5.0:
		car.step_tick()
		t += 0.01
		var any := car.wheel_contact.has(true)
		if car.global_position.z > TestArena.KICKER_Z:
			streak = 0 if any else streak + 1
			best = maxi(best, streak)
			top = maxf(top, car.global_position.y)
			if not any:
				min_up = minf(min_up, car.global_transform.basis.y.y)
			body = body or car.body_contact
	car.gas = 0.0
	print("LAB kicker 200 km/h: airtime %.2f s, apex %.1f m, min up.y in the air %.2f, body hit %s, speed after %.0f km/h" % [
		best * 0.01, top, min_up, body, car.speed_kmh()])
	_check("kicker_airtime", best * 0.01, 0.9, 1.6, " s")
	_check("kicker_flies_level", min_up, 0.85, 1.0)
	_check("kicker_lands_upright", car.global_transform.basis.y.y, 0.95, 1.0)
	TestHooks.check(not body, "kicker_no_body_hit", "the chassis touched down")


func _loop(kmh: float, must_finish: bool) -> void:
	var r := TestArena.LOOP_R
	var head := rad_to_deg(atan2(TestArena.LOOP_SHIFT, TAU * r))
	var dir := Basis(Vector3.UP, deg_to_rad(head)) * Vector3(0, 0, 1)
	_place(TestArena.LOOP_START - dir * 60.0, head, kmh)
	var t := 0.0
	var top := 0.0
	var top_kmh := 0.0
	var air := 0
	var ticks := 0
	var body := false
	var finished := false
	var turns := 0.0
	var last_th := 0.0
	while t < 6.0:
		car.gas = 1.0 if car.speed_kmh() < kmh else 0.0
		# a player steering to stay on the ribbon: the car's left is +X all the way round
		var q := car.global_position
		var th := atan2(q.z - TestArena.LOOP_START.z, r - q.y)
		if q.z > TestArena.LOOP_START.z - 1.0 or turns > 0.0:
			var dth := wrapf(th - last_th, -PI, PI)
			if dth > 0.0 and dth < 0.5:
				turns += dth
		last_th = th
		var x_want := TestArena.LOOP_START.x + TestArena.LOOP_SHIFT * clampf(turns, 0.0, TAU) / TAU
		var vx_want := TestArena.LOOP_SHIFT / (TAU * r) * car.speed_kmh() / 3.6
		car.steer = clampf(0.25 * (x_want - q.x) + 0.15 * (vx_want - car.lin_vel.x), -1.0, 1.0)
		car.step_tick()
		t += 0.01
		var p := car.global_position
		if p.y > top:
			top = p.y
			top_kmh = car.speed_kmh()
		if p.y > 1.0:
			ticks += 1
			if not car.wheel_contact.has(true):
				air += 1
		body = body or car.body_contact
		if top > 2.0 * r - 3.0 and p.y < 1.0 and p.z > TestArena.LOOP_START.z + 5.0:
			finished = true
			break
	car.steer = 0.0
	var up := car.global_transform.basis.y.y
	print("LAB loop %d km/h: finished %s, top %.1f m at %.0f km/h, air %d/%d ticks, body hit %s, exit %.0f km/h, up.y %.2f" % [
		kmh, finished, top, top_kmh, air, ticks, body, car.speed_kmh(), up])
	if must_finish:
		TestHooks.check(finished, "loop_%d_completes" % kmh, "top %.1f m" % top)
		TestHooks.check(not body, "loop_%d_no_body_hit" % kmh)
		_check("loop_%d_exit_upright" % kmh, up, 0.95, 1.0)
		_check("loop_%d_air_share" % kmh, float(air) / maxf(1.0, ticks), 0.0, 0.15)


func _pipe() -> void:
	# 25 deg into the quarter pipe at 220 km/h: rides up the curve and stays on its wheels (since
	# contacts turn the car at TMNF's 0.55 of r x j it bounces along the pipe: all four wheels
	# touch again in the last second, not at every tick)
	car.place(Transform3D(Basis(Vector3.UP, deg_to_rad(-25.0)), Vector3(TestArena.PIPE_X + 30.0, 0, -150.0)))
	for i in 20:
		car.step_tick()
	car.lin_vel = car.global_transform.basis.z * 220.0 / 3.6
	var t := 0.0
	var top := 0.0
	var body := false
	var on4_late := 0
	car.gas = 1.0
	while t < 5.0:
		car.step_tick()
		t += 0.01
		top = maxf(top, car.global_position.y)
		body = body or car.body_contact
		if t > 4.0 and car.wheel_contact.count(true) == 4:
			on4_late += 1
	car.gas = 0.0
	var tilt := rad_to_deg(acos(clampf(car.global_transform.basis.y.y, -1.0, 1.0)))
	print("LAB pipe 220 km/h 25 deg: top %.1f m, body hit %s, end tilt %.0f deg, wheels %s, on 4 wheels %d of the last 100 ticks, end speed %.0f km/h, x %.1f" % [
		top, body, tilt, str(car.wheel_contact), on4_late, car.speed_kmh(), car.global_position.x])
	_check("pipe_rides_up", top, 3.0, 40.0, " m")
	TestHooks.check(not body, "pipe_no_body_hit", "the chassis hit the pipe")
	_check("pipe_on_wheels_at_end", on4_late, 1, 100, " ticks of the last 100 on 4 wheels")
