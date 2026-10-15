extends Node3D
## Keyboard handling ease (owner, session 4: "make handling easy, but different for different
## cars"). Real key presses go through CarInput's steering ramp on a flat plane, per car:
##   flick:   200 km/h, full right for 0.7 s on throttle, then release. The car must settle:
##            peak slip and the time until the yaw rate is calm again.
##   slalom:  170 km/h, alternate left/right every 0.6 s for 6 s on throttle, then release. Peak
##            slip (a spin-out shows as a large slip angle); heading drift is printed for info.
##   lock:    150 km/h, full right for 2.5 s on throttle: must hold a grip turn, not spin out.
## Prints EASY lines; asserts the "easy" targets.
## tools/run_scene.sh res://tests/physics/test_easy.tscn --headless [-- --car=kaze]

const FLICK_SLIP_MAX := 25.0        # deg
const FLICK_SETTLE_MAX := 1.2       # s after release until |yaw rate| < 0.25 rad/s
const SLALOM_SLIP_MAX := 22.0
const LOCK_SLIP_MAX := 30.0

var _ground: StaticBody3D
var car: Car
var inp: CarInput


func _ready() -> void:
	_ground = StaticBody3D.new()
	_ground.collision_layer = 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(3000, 2, 3000)
	cs.shape = b
	_ground.add_child(cs)
	_ground.position = Vector3(0, -1, 0)
	add_child(_ground)
	var cars: Array = [TestHooks.arg("car", "")] if TestHooks.has_arg("car") else CarDefs.IDS
	for c in cars:
		await _flick(String(c))
		await _slalom(String(c))
		await _lock(String(c))
	_keys(false, false, false)
	TestHooks.finish()


func _spawn(car_id: String, kmh: float) -> void:
	if car:
		car.queue_free()
		await get_tree().physics_frame
	car = Car.create(CarDefs.default_config(car_id))
	add_child(car)
	inp = CarInput.new()
	car.add_child(inp)
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 1200)), Vector3(0, 0, -kmh / 3.6))
	_keys(false, false, false)
	for i in 20:
		await get_tree().physics_frame


func _keys(throttle: bool, left: bool, right: bool) -> void:
	for a in [["accelerate", throttle], ["steer_left", left], ["steer_right", right]]:
		if a[1]:
			Input.action_press(a[0])
		else:
			Input.action_release(a[0])


func _slip_deg() -> float:
	var v := car.linear_velocity
	v.y = 0.0
	if v.length() < 3.0:
		return 0.0
	var fwd := -car.global_transform.basis.z
	fwd.y = 0.0
	return rad_to_deg(absf(fwd.normalized().signed_angle_to(v.normalized(), Vector3.UP)))


func _heading() -> float:
	var f := -car.global_transform.basis.z
	return atan2(f.x, -f.z)


func _flick(car_id: String) -> void:
	await _spawn(car_id, 200.0)
	var slip := 0.0
	_keys(true, false, true)
	for i in 42:
		await get_tree().physics_frame
		slip = maxf(slip, _slip_deg())
	_keys(true, false, false)
	var settle := -1.0
	for i in 240:
		await get_tree().physics_frame
		slip = maxf(slip, _slip_deg())
		if settle < 0.0 and absf(car.angular_velocity.y) < 0.25 and i > 3:
			settle = i / 60.0
	if settle < 0.0:
		settle = 99.0
	print("EASY %s flick slip_max=%.1f settle=%.2f s speed=%.0f" % [car_id, slip, settle, car.get_speed_kmh()])
	TestHooks.check(slip < FLICK_SLIP_MAX, "easy_flick_slip_%s" % car_id, "%.1f deg" % slip)
	TestHooks.check(settle < FLICK_SETTLE_MAX, "easy_flick_settles_%s" % car_id, "%.2f s" % settle)


func _slalom(car_id: String) -> void:
	await _spawn(car_id, 170.0)
	var slip := 0.0
	var h0 := _heading()
	var worst := 0.0
	for k in 10:
		var right := k % 2 == 0
		_keys(true, not right, right)
		for i in 36:
			await get_tree().physics_frame
			slip = maxf(slip, _slip_deg())
			if TestHooks.has_arg("trace") and i % 6 == 0:
				print("  slalom %s k=%d i=%d slip=%.1f steer=%.2f yaw=%.2f v=%.0f drift=%.2f" % [car_id, k, i, _slip_deg(), float(car.controls["steer"]), car.angular_velocity.y, car.get_speed_kmh(), car.get_drift_amount()])
			worst = maxf(worst, rad_to_deg(absf(wrapf(_heading() - h0, -PI, PI))))
	_keys(true, false, false)
	for i in 60:
		await get_tree().physics_frame
		slip = maxf(slip, _slip_deg())
	print("EASY %s slalom slip_max=%.1f heading_dev_max=%.0f speed=%.0f" % [car_id, slip, worst, car.get_speed_kmh()])
	TestHooks.check(slip < SLALOM_SLIP_MAX, "easy_slalom_slip_%s" % car_id, "%.1f deg" % slip)
	# heading drift is the car's agility (info only); a spin shows up as a big slip angle
	TestHooks.check(slip < 45.0, "easy_slalom_no_spin_%s" % car_id, "slip %.1f deg" % slip)


func _lock(car_id: String) -> void:
	await _spawn(car_id, 150.0)
	var slip := 0.0
	_keys(true, false, true)
	for i in 150:
		await get_tree().physics_frame
		slip = maxf(slip, _slip_deg())
	_keys(false, false, false)
	print("EASY %s lock slip_max=%.1f speed=%.0f" % [car_id, slip, car.get_speed_kmh()])
	TestHooks.check(slip < LOCK_SLIP_MAX, "easy_lock_slip_%s" % car_id, "%.1f deg" % slip)
