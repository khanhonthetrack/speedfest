extends Node3D
## Lab: the TmCar rigid body (100 Hz, sub-steps, ellipsoid contacts) on a world built in code.
## Checks that the full body reproduces the flat-ground model (tests/test_model_lab) and behaves
## like TMNF on the ground, in the air and against walls.
## Run: stadium/tools/run.sh res://tests/test_car_body.tscn --headless

const T := preload("res://core/tm_tuning.gd")

var car: TmCar
var _frames := 0
var _done := false


func _ready() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(4000, 1, 4000))                  # floor, top at y = 0
	_box(Vector3(300, 5, -150), Vector3(40, 10, 300))                   # platform, top y = 10, ends z = 0
	_box(Vector3(-300.5, 2, 0), Vector3(1, 4, 4000))                    # wall, face at x = -300
	car = TmCar.new()
	car.set_physics_process(false)
	add_child(car)


func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	add_child(body)
	return body


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 3 or _done:
		return
	_done = true
	_settle()
	_accel()
	_turn()
	_brake()
	_jump()
	_wall()
	TestHooks.finish()


func _check(name: String, value: float, lo: float, hi: float, unit: String = "") -> void:
	if value >= lo and value <= hi:
		TestHooks.ok("%s (%.3f%s)" % [name, value, unit])
	else:
		TestHooks.fail(name, "%.3f%s outside [%.3f, %.3f]" % [value, unit, lo, hi])


func _place(at: Vector3, heading_deg: float = 0.0, kmh: float = 0.0) -> void:
	car.place(Transform3D(Basis(Vector3.UP, deg_to_rad(heading_deg)), at))
	car.gas = 0.0
	car.brake = 0.0
	car.steer = 0.0
	for i in 30:
		car.step_tick()
	car.lin_vel = car.global_transform.basis.z * kmh / 3.6


func _run(ticks: int) -> void:
	for i in ticks:
		car.step_tick()


func _settle() -> void:
	car.place(Transform3D(Basis(), Vector3(0, 0.3, 0)))
	_run(300)
	var lens := car.model.susp_len
	_check("settle_susp_len_avg", (lens[0] + lens[1] + lens[2] + lens[3]) / 4.0, 0.005, 0.03, " m")
	_check("settle_height", car.global_position.y, 0.42, 0.47, " m")
	_check("settle_still", car.lin_vel.length(), 0.0, 0.05, " m/s")
	var all := car.wheel_contact.count(true)
	_check("settle_wheels_on_ground", all, 4, 4)
	_check("settle_level", car.global_transform.basis.y.y, 0.999, 1.001)


func _time_to(kmh: float, limit: float = 30.0) -> float:
	_place(Vector3(0, 0, -1000))
	car.gas = 1.0
	var t := 0.0
	while car.speed_kmh() < kmh and t < limit:
		car.step_tick()
		t += 0.01
	car.gas = 0.0
	return t


func _accel() -> void:
	# flat model: 0-100 1.74 s, 0-200 4.26 s
	_check("body_accel_0_100", _time_to(100.0), 1.65, 1.85, " s")
	_check("body_accel_0_200", _time_to(200.0), 4.05, 4.50, " s")
	print("LAB body substeps at 200 km/h: %d" % car.substeps)


func _turn() -> void:
	# flat model: full-lock radius 15.8 m @ 100 km/h, 48 m @ 200
	for k in [100.0, 200.0]:
		_place(Vector3(0, 0, 0), 0.0, k)
		car.steer = 1.0
		var max_slip := 0.0
		for i in 300:
			car.gas = 1.0 if car.speed_kmh() < k else 0.0
			car.step_tick()
			if i > 50:
				var lv := car.local_velocity()
				max_slip = maxf(max_slip, rad_to_deg(atan2(absf(lv.x), maxf(lv.z, 0.1))))
		var sp := Vector2(car.lin_vel.x, car.lin_vel.z).length()
		var r := sp / maxf(absf(car.ang_vel.y), 1e-6)
		var ref: float = 15.8 if k == 100.0 else 48.1
		print("LAB body turn %d km/h: radius %.1f m slip %.1f deg yaw %.2f tilt %.3f" % [k, r, max_slip, car.ang_vel.y, car.global_transform.basis.y.y])
		_check("body_turn_%d_radius" % k, r, ref * 0.9, ref * 1.1, " m")
		_check("body_turn_%d_slip" % k, max_slip, 0.0, 3.0, " deg")
		_check("body_turn_%d_upright" % k, car.global_transform.basis.y.y, 0.95, 1.0)
		car.steer = 0.0
		car.gas = 0.0


func _brake() -> void:
	# flat model: 200 km/h -> 1 m/s in 2.00 s, 39 m
	_place(Vector3(0, 0, -1000), 0.0, 200.0)
	var start := car.global_position
	car.brake = 1.0
	var t := 0.0
	while car.local_velocity().z > 1.0 and t < 10.0:
		car.step_tick()
		t += 0.01
	car.brake = 0.0
	_check("body_brake_200_time", t, 1.85, 2.2, " s")
	_check("body_brake_200_dist", (car.global_position - start).length(), 35.0, 44.0, " m")


func _jump() -> void:
	# off a 10 m platform at 150 km/h: 25 m/s^2 in the air -> about 0.9 s of fall
	_place(Vector3(300, 10, -60), 0.0, 150.0)
	var t := 0.0
	var left := -1.0
	var landed := -1.0
	while t < 4.0:
		car.gas = 1.0 if car.speed_kmh() < 150.0 else 0.0
		car.step_tick()
		t += 0.01
		var any := car.wheel_contact.has(true)
		if left < 0.0 and not any and car.global_position.z > 0.0:
			left = t
		if left > 0.0 and landed < 0.0 and any:
			landed = t
	car.gas = 0.0
	print("LAB body jump: airtime %.2f s, speed %.0f km/h, up.y %.3f" % [landed - left, car.speed_kmh(), car.global_transform.basis.y.y])
	_check("body_jump_airtime", landed - left, 0.8, 1.0, " s")
	_check("body_jump_lands_on_wheels", car.global_transform.basis.y.y, 0.95, 1.0)
	_check("body_jump_keeps_speed", car.speed_kmh(), 130.0, 160.0, " km/h")


func _wall() -> void:
	# 15 deg into a wall at 200 km/h: glances off, keeps going, no flip
	_place(Vector3(-295, 0, -1500), -15.0, 200.0)
	var hit := false
	var min_up := 1.0
	var t := 0.0
	car.gas = 1.0
	while t < 1.5:
		car.step_tick()
		t += 0.01
		if car.body_contact or car.model.wall_until_ms > car.now_ms:
			hit = true
		min_up = minf(min_up, car.global_transform.basis.y.y)
	car.gas = 0.0
	var fwd := car.global_transform.basis.z
	print("LAB body wall: hit=%s speed %.0f km/h, heading %.1f deg off the wall, min up.y %.3f, x %.2f" % [hit, car.speed_kmh(), rad_to_deg(atan2(-fwd.x, fwd.z)), min_up, car.global_position.x])
	TestHooks.check(hit, "body_wall_hit", "the car never reached the wall")
	_check("body_wall_no_flip", min_up, 0.8, 1.0)
	_check("body_wall_keeps_going", car.speed_kmh(), 60.0, 260.0, " km/h")
	_check("body_wall_not_through", car.global_position.x, -300.0, -280.0, " m")
