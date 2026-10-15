extends Node3D
## Handling-feel tests (owner feedback 2026-10-15): barrier hits must not flip the car, braking
## while steering must start a controllable drift, and the car must not spin like a top in the air.
## Prints FEEL lines with the measurements; asserts the targets.
## tools/run_scene.sh res://tests/physics/test_feel.tscn --headless -- --frames=60000

var _ground: StaticBody3D
var _wall: StaticBody3D


func _ready() -> void:
	_build_world()
	var cars: Array = [TestHooks.arg("car", "")] if TestHooks.has_arg("car") else CarDefs.IDS
	for c in cars:
		await _wall_tests(String(c))
		await _brake_drift(String(c))
		await _air_spin(String(c))
	TestHooks.finish()


func _build_world() -> void:
	_ground = _box(Vector3(800, 2, 2000), Vector3(0, -1, -800))
	# right-hand wall (barrier collision is 2.6 m tall on the real tracks)
	_wall = _box(Vector3(1, 2.6, 2000), Vector3(7.5, 1.3, -800))


func _box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	add_child(b)
	return b


func _spawn(car_id: String, yaw_deg: float, kmh: float, pos := Vector3.ZERO) -> Car:
	var car := Car.create(CarDefs.default_config(car_id))
	add_child(car)
	for ch in car.get_children():
		if ch is CarInput:
			(ch as CarInput).enabled = false
	var basis := Basis(Vector3.UP, deg_to_rad(-yaw_deg))   # +yaw_deg turns the nose right
	var r := float(CarDefs.geometry(car_id)["wheel_radius"])
	var xf := Transform3D(basis, pos + Vector3(0, r + 0.05, 0))
	car.teleport(xf, -basis.z * kmh / 3.6)
	return car


func _ctl(car: Car, throttle: float, brake: float, steer: float, hb := false) -> void:
	car.controls = {"throttle": throttle, "brake": brake, "steer": steer, "handbrake": hb, "nitro": false}


## Drive into the right-hand wall at an angle. Flipping = the car's up vector leaves ~70 deg of
## world up; also report how high the hit pops the car and the speed kept.
func _wall_tests(car_id: String) -> void:
	for kmh in [150.0, 250.0]:
		for ang in [12.0, 25.0, 45.0]:
			for steer_away in [false, true]:
				var car := _spawn(car_id, ang, kmh)
				var max_tilt := 0.0
				var max_pop := 0.0
				var y0 := car.global_position.y
				var hit := false
				var speed_after := 0.0
				for i in 150:
					var s := 0.0
					if steer_away and hit:
						s = -1.0
					_ctl(car, 1.0, 0.0, s)
					await get_tree().physics_frame
					if car.global_position.x > 5.0:
						hit = true
					var tilt := rad_to_deg(acos(clampf(car.global_transform.basis.y.dot(Vector3.UP), -1.0, 1.0)))
					max_tilt = maxf(max_tilt, tilt)
					max_pop = maxf(max_pop, car.global_position.y - y0)
					speed_after = car.linear_velocity.length() * 3.6
				var flipped := max_tilt > 70.0
				var tag := "%s_wall_%d_%d%s" % [car_id, int(kmh), int(ang), "_away" if steer_away else ""]
				print("FEEL %s tilt_max=%.1f pop=%.2f m speed_after=%.0f" % [tag, max_tilt, max_pop, speed_after])
				TestHooks.check(not flipped and max_tilt < 35.0, tag + "_no_flip", "tilt %.1f deg" % max_tilt)
				TestHooks.check(max_pop < 0.6, tag + "_no_pop", "pop %.2f m" % max_pop)
				car.queue_free()
				await get_tree().physics_frame


## Brake + steer at speed (no handbrake): must break the rear loose into a drift and keep speed.
func _brake_drift(car_id: String) -> void:
	var car := _spawn(car_id, 0.0, 130.0, Vector3(-200, 0, 0))
	var max_slip := 0.0
	for i in 40:
		_ctl(car, 0.0, 1.0, 1.0)
		await get_tree().physics_frame
		max_slip = maxf(max_slip, absf(rad_to_deg(car.get_slip_angle())))
	for i in 60:
		_ctl(car, 1.0, 0.0, 0.6)
		await get_tree().physics_frame
		max_slip = maxf(max_slip, absf(rad_to_deg(car.get_slip_angle())))
	var kmh := car.linear_velocity.length() * 3.6
	var tilt := rad_to_deg(acos(clampf(car.global_transform.basis.y.dot(Vector3.UP), -1.0, 1.0)))
	print("FEEL %s_brake_drift slip_max=%.1f speed_after=%.0f tilt=%.1f" % [car_id, max_slip, kmh, tilt])
	TestHooks.check(max_slip > 14.0, car_id + "_brake_drift_slides", "slip %.1f deg" % max_slip)
	TestHooks.check(kmh > 75.0, car_id + "_brake_drift_keeps_speed", "%.0f km/h" % kmh)
	TestHooks.check(tilt < 20.0, car_id + "_brake_drift_upright", "%.1f deg" % tilt)
	car.queue_free()
	await get_tree().physics_frame


## Launch into the air holding full steering: the car may turn a little, not spin like a top.
func _air_spin(car_id: String) -> void:
	var car := _spawn(car_id, 0.0, 0.0, Vector3(-300, 30, 0))
	car.teleport(car.global_transform, Vector3(0, 6, -50))
	var yaw0 := car.global_transform.basis.get_euler().y
	for i in 60:
		_ctl(car, 1.0, 0.0, 1.0)
		await get_tree().physics_frame
	var dyaw := rad_to_deg(absf(wrapf(car.global_transform.basis.get_euler().y - yaw0, -PI, PI)))
	print("FEEL %s_air_yaw_1s=%.1f deg" % [car_id, dyaw])
	TestHooks.check(dyaw < 25.0, car_id + "_air_steer_subtle", "%.1f deg in 1 s" % dyaw)
	car.queue_free()
	await get_tree().physics_frame
