extends Node3D
## Trackmania-feel lab (M7, owner: "The physics is horrible. There is no feel ... learn or copy from
## Trackmania how the car behaves"). Open-loop scenarios with fixed inputs (no AutoDriver, except on
## the wall ride and loop where it holds the line), each printing a TM line with the measurement and
## asserting the target from docs/research/m7_physics.md "Target spec".
##   tools/run_scene.sh res://tests/physics/test_tm.tscn --headless -- [--car=kaze] [--only=accel,turn,...]
## Groups: accel, response, turn, spin, drift, wall, wallride, loop, landing, air.

var _cars: Array = []
var _only: Array = []


func _ready() -> void:
	_cars = [String(TestHooks.arg("car", ""))] if TestHooks.has_arg("car") else Array(CarDefs.IDS)
	_only = String(TestHooks.arg("only", "")).split(",", false)
	add_child(PhysicsTestGround.flat_pad(3000, 3000, Vector3(0, 0, -1000)))
	for c in _cars:
		var id := String(c)
		if _want("accel"):
			await _accel(id)
		if _want("response"):
			await _response(id)
		if _want("turn"):
			await _grip_turn(id)
		if _want("spin"):
			await _no_spin(id)
		if _want("drift"):
			await _drift(id)
		if _want("wall"):
			await _barriers(id)
		if _want("wallride"):
			await _wallride(id)
		if _want("loop"):
			await _loop(id)
		if _want("landing"):
			await _landing(id)
		if _want("air"):
			await _air(id)
	TestHooks.finish()


func _want(g: String) -> bool:
	return _only.is_empty() or g in _only


# --- helpers ------------------------------------------------------------------------------------

func _spawn(car_id: String, kmh: float, pos := Vector3.ZERO, yaw_deg := 0.0) -> Car:
	var car := Car.create(PhysicsTestGround.test_config(car_id))
	add_child(car)
	for ch in car.get_children():
		if ch is CarInput:
			(ch as CarInput).enabled = false
	var basis := Basis(Vector3.UP, deg_to_rad(-yaw_deg))
	var r := float(CarDefs.geometry(car_id)["wheel_radius"])
	car.teleport(Transform3D(basis, pos + Vector3(0, r + 0.02, 0)), -basis.z * kmh / 3.6)
	# settle on the suspension
	for i in 3:
		_ctl(car, 0.0, 0.0, 0.0)
		await get_tree().physics_frame
	car.linear_velocity = -car.global_transform.basis.z * kmh / 3.6
	return car


func _ctl(car: Car, throttle: float, brake: float, steer: float, hb := false) -> void:
	car.controls = {"throttle": throttle, "brake": brake, "steer": steer, "handbrake": hb, "nitro": false}


func _yaw_rate(car: Car) -> float:
	return car.angular_velocity.dot(Vector3.UP)


func _heading(car: Car) -> float:
	var f := -car.global_transform.basis.z
	return atan2(-f.x, -f.z)


func _slip_deg(car: Car) -> float:
	var v := car.linear_velocity
	v.y = 0.0
	if v.length() < 3.0:
		return 0.0
	var f := -car.global_transform.basis.z
	f.y = 0.0
	return rad_to_deg(absf(f.normalized().signed_angle_to(v.normalized(), Vector3.UP)))


func _tilt_deg(car: Car) -> float:
	return rad_to_deg(acos(clampf(car.global_transform.basis.y.dot(Vector3.UP), -1.0, 1.0)))


func _done(car: Car) -> void:
	car.queue_free()
	await get_tree().physics_frame


# --- scenarios ----------------------------------------------------------------------------------

## Full throttle from a standstill on flat ground.
func _accel(id: String) -> void:
	var car := await _spawn(id, 0.0)
	var t100 := -1.0
	var t200 := -1.0
	var v10 := 0.0
	for i in 60 * 30:
		_ctl(car, 1.0, 0.0, 0.0)
		await get_tree().physics_frame
		var kmh := car.get_speed_kmh()
		var t := float(i + 1) / 60.0
		if t100 < 0.0 and kmh >= 100.0:
			t100 = t
		if t200 < 0.0 and kmh >= 200.0:
			t200 = t
		if i == 60 * 10 - 1:
			v10 = kmh
	var vmax := car.get_speed_kmh()
	print("TM accel %s t100=%.2fs t200=%.2fs v@10s=%.0f v@30s=%.0f km/h" % [id, t100, t200, v10, vmax])
	TestHooks.check(t100 > 0.0 and t100 <= 2.4, "tm_accel_100_%s" % id, "%.2f s" % t100)
	TestHooks.check(t200 > 0.0 and t200 <= 7.5, "tm_accel_200_%s" % id, "%.2f s" % t200)
	await _done(car)


## Steering response at 150 km/h: time to 90% of the steady yaw rate, and to settle on release.
func _response(id: String) -> void:
	var car := await _spawn(id, 150.0, Vector3(-600, 0, 0))
	var rates: Array[float] = []
	for i in 60:
		_ctl(car, 0.6, 0.0, 1.0)
		await get_tree().physics_frame
		rates.append(absf(_yaw_rate(car)))
	var steady := rates[rates.size() - 1]
	var t90 := -1.0
	for i in rates.size():
		if rates[i] >= steady * 0.9:
			t90 = float(i + 1) / 60.0
			break
	var t_rel := -1.0
	for i in 60:
		_ctl(car, 0.6, 0.0, 0.0)
		await get_tree().physics_frame
		if t_rel < 0.0 and absf(_yaw_rate(car)) < steady * 0.1:
			t_rel = float(i + 1) / 60.0
	print("TM response %s steady_yaw=%.2f rad/s t90=%.3fs release=%.3fs" % [id, steady, t90, t_rel])
	TestHooks.check(t90 > 0.0 and t90 <= 0.2, "tm_response_turn_in_%s" % id, "%.3f s" % t90)
	TestHooks.check(t_rel > 0.0 and t_rel <= 0.25, "tm_response_release_%s" % id, "%.3f s" % t_rel)
	await _done(car)


## Full lock for 2 s with throttle held: TM keeps its speed and doesn't slide.
func _grip_turn(id: String) -> void:
	for kmh in [120.0, 200.0, 280.0]:
		var car := await _spawn(id, kmh, Vector3(-300 + kmh, 0, -200))
		var v0 := car.linear_velocity.length()
		var max_slip := 0.0
		var lat_sum := 0.0
		for i in 120:
			_ctl(car, 1.0, 0.0, 1.0)
			await get_tree().physics_frame
			if i > 20:
				max_slip = maxf(max_slip, _slip_deg(car))
				lat_sum += absf(_yaw_rate(car)) * car.linear_velocity.length()
		var keep := car.linear_velocity.length() / maxf(v0, 0.1)
		var lat_g := lat_sum / 99.0 / 9.8
		print("TM turn %s %d km/h keep=%.1f%% max_slip=%.1f deg lat=%.2f g" % [id, int(kmh), keep * 100.0, max_slip, lat_g])
		TestHooks.check(keep >= 0.93, "tm_turn_keep_%d_%s" % [int(kmh), id], "%.1f%%" % (keep * 100.0))
		TestHooks.check(max_slip <= 8.0, "tm_turn_no_slide_%d_%s" % [int(kmh), id], "%.1f deg" % max_slip)
		TestHooks.check(lat_g >= 1.0, "tm_turn_grip_%d_%s" % [int(kmh), id], "%.2f g" % lat_g)
		await _done(car)


## Full lock and full throttle from 250 km/h for 4 s: never spins out.
func _no_spin(id: String) -> void:
	var car := await _spawn(id, 250.0, Vector3(400, 0, -200))
	var max_slip := 0.0
	for i in 240:
		_ctl(car, 1.0, 0.0, -1.0 if (i / 60) % 2 == 0 else 1.0)
		await get_tree().physics_frame
		max_slip = maxf(max_slip, _slip_deg(car))
	print("TM spin %s slalom max_slip=%.1f deg" % [id, max_slip])
	TestHooks.check(max_slip <= 15.0, "tm_no_spin_%s" % id, "%.1f deg" % max_slip)
	await _done(car)


## Brake tap + full steer at 200 km/h, then throttle + steer: a deliberate drift that turns tighter
## than grip, keeps most of the speed, and recovers when the wheel is centred.
func _drift(id: String) -> void:
	# grip reference: how far the car turns in 1.5 s on grip
	var g := await _spawn(id, 200.0, Vector3(800, 0, -200))
	var h0 := _heading(g)
	for i in 90:
		_ctl(g, 1.0, 0.0, 1.0)
		await get_tree().physics_frame
	var grip_turn := absf(angle_difference(h0, _heading(g)))
	await _done(g)
	var car := await _spawn(id, 200.0, Vector3(1000, 0, -200))
	var v0 := car.linear_velocity.length()
	h0 = _heading(car)
	var max_slip := 0.0
	for i in 90:
		var brake := 1.0 if i < 12 else 0.0
		_ctl(car, 0.0 if i < 12 else 1.0, brake, 1.0)
		await get_tree().physics_frame
		max_slip = maxf(max_slip, _slip_deg(car))
	var drift_turn := absf(angle_difference(h0, _heading(car)))
	var keep := car.linear_velocity.length() / v0
	for i in 60:
		_ctl(car, 1.0, 0.0, 0.0)
		await get_tree().physics_frame
	var slip_after := _slip_deg(car)
	print("TM drift %s max_slip=%.1f deg turn %.0f vs grip %.0f deg keep=%.1f%% slip_after=%.1f" % [id, max_slip, rad_to_deg(drift_turn), rad_to_deg(grip_turn), keep * 100.0, slip_after])
	TestHooks.check(max_slip >= 12.0, "tm_drift_slides_%s" % id, "%.1f deg" % max_slip)
	TestHooks.check(drift_turn >= grip_turn * 1.15, "tm_drift_tighter_%s" % id, "%.0f vs %.0f" % [rad_to_deg(drift_turn), rad_to_deg(grip_turn)])
	TestHooks.check(keep >= 0.8, "tm_drift_keeps_speed_%s" % id, "%.1f%%" % (keep * 100.0))
	TestHooks.check(slip_after <= 6.0, "tm_drift_recovers_%s" % id, "%.1f deg" % slip_after)
	await _done(car)


## Barrier hits along a wall: glancing hits glance off and keep going, nothing flips.
func _barriers(id: String) -> void:
	var specs := [[15.0, 250.0, 0.85, 12.0], [30.0, 250.0, 0.7, 15.0], [45.0, 200.0, 0.5, 18.0], [90.0, 150.0, 0.0, 25.0]]
	var k := 0
	for sp in specs:
		var ang: float = sp[0]
		var kmh: float = sp[1]
		var base := Vector3(-1200 - k * 60.0, 0, -100)
		k += 1
		var wall := PhysicsTestGround.wall(base + Vector3(6, 0, 200), base + Vector3(6, 0, -400), 2.6)
		add_child(wall)
		var car := await _spawn(id, kmh, base, ang)
		var hit := false
		var max_tilt := 0.0
		var max_pop := 0.0
		var y0 := car.global_position.y
		var t_hit := 0
		var keep := 0.0
		var align := 0.0
		var bounce := 0.0
		for i in 150:
			_ctl(car, 1.0, 0.0, 0.0)
			await get_tree().physics_frame
			if not hit and car.global_position.x > base.x + 3.0:
				hit = true
				t_hit = i
			max_tilt = maxf(max_tilt, _tilt_deg(car))
			max_pop = maxf(max_pop, car.global_position.y - y0)
			if hit and i == t_hit + 30:
				keep = car.linear_velocity.length() / (kmh / 3.6)
				var f := -car.global_transform.basis.z
				align = rad_to_deg(absf(atan2(f.x, -f.z)))
				bounce = maxf(-car.linear_velocity.x, 0.0)
		print("TM wall %s %d deg %d km/h keep=%.0f%% heading_off_wall=%.0f deg bounce=%.1f m/s tilt=%.0f pop=%.2f" % [id, int(ang), int(kmh), keep * 100.0, align, bounce, max_tilt, max_pop])
		TestHooks.check(hit, "tm_wall_hit_%d_%s" % [int(ang), id])
		TestHooks.check(keep >= float(sp[2]), "tm_wall_keep_%d_%s" % [int(ang), id], "%.0f%%" % (keep * 100.0))
		TestHooks.check(max_tilt <= float(sp[3]), "tm_wall_no_flip_%d_%s" % [int(ang), id], "tilt %.0f" % max_tilt)
		TestHooks.check(max_pop <= 0.4, "tm_wall_no_pop_%d_%s" % [int(ang), id], "%.2f m" % max_pop)
		if ang < 50.0:
			TestHooks.check(align <= 10.0, "tm_wall_aligns_%d_%s" % [int(ang), id], "%.0f deg" % align)
		else:
			TestHooks.check(bounce <= 3.0, "tm_wall_no_big_bounce_%d_%s" % [int(ang), id], "%.1f m/s" % bounce)
		await _done(car)
		wall.queue_free()


## Curved 80 deg wall ride (r 70 m): holds the line with grip, doesn't sink down the wall or lose
## more speed than drag.
func _wallride(id: String) -> void:
	for kmh in [150.0, 200.0]:
		var o := Vector3(2000 + kmh * 4.0, 0, 0)
		var path := PhysicsTestGround.wallride_path(70.0, 80.0, 90.0, 120.0, 220.0, 14.0, o)
		var road := PhysicsTestGround.road_from_path(path)
		add_child(road)
		var car := Car.create(PhysicsTestGround.test_config(id))
		add_child(car)
		var ai := AutoDriver.new()
		ai.path = path
		ai.target_speed_kmh = kmh
		car.add_child(ai)
		car.teleport(Transform3D(Basis.IDENTITY, o + Vector3(0, 0.6, -2)), Vector3(0, 0, -kmh / 3.6))
		var a: float = path.get_meta("wall_start")
		var b: float = path.get_meta("wall_end")
		var entry := -1.0
		var vmin := 1e9
		var max_lat := 0.0
		var air := 0
		var ticks := 0
		for i in 60 * 25:
			await get_tree().physics_frame
			var d := ai.get_distance()
			if d >= a and d <= b:
				if entry < 0.0:
					entry = car.get_speed_kmh()
					ai.target_speed_kmh = 0.0    # coast-free: hold throttle, let the wall decide
				var tr := path.sample_transform(d)
				max_lat = maxf(max_lat, absf((tr.affine_inverse() * car.global_position).x))
				vmin = minf(vmin, car.get_speed_kmh())
				ticks += 1
				if not car.is_grounded():
					air += 1
			if d > b + 20.0 or car.global_position.y < -30.0:
				break
		var keep := vmin / maxf(entry, 1.0)
		print("TM wallride %s %d km/h entry=%.0f min=%.0f keep=%.0f%% max_lat=%.2f m air=%d/%d" % [id, int(kmh), entry, vmin, keep * 100.0, max_lat, air, ticks])
		TestHooks.check(entry > 0.0 and ticks > 0, "tm_wallride_reached_%d_%s" % [int(kmh), id])
		TestHooks.check(max_lat <= 2.0, "tm_wallride_holds_line_%d_%s" % [int(kmh), id], "%.2f m" % max_lat)
		TestHooks.check(keep >= 0.95, "tm_wallride_keeps_speed_%d_%s" % [int(kmh), id], "%.0f%%" % (keep * 100.0))
		TestHooks.check(air <= 3, "tm_wallride_grounded_%d_%s" % [int(kmh), id], "%d" % air)
		await _done(car)
		road.queue_free()


## Loop r 18 at 140 km/h: completes, wheels on the road all the way round.
func _loop(id: String) -> void:
	var o := Vector3(4000, 0, 0)
	var path := PhysicsTestGround.loop_path(18.0, 220.0, 150.0, 12.0, o)
	var road := PhysicsTestGround.road_from_path(path)
	add_child(road)
	var car := Car.create(PhysicsTestGround.test_config(id))
	add_child(car)
	var ai := AutoDriver.new()
	ai.path = path
	ai.target_speed_kmh = 140.0
	car.add_child(ai)
	car.teleport(Transform3D(Basis.IDENTITY, o + Vector3(0, 0.6, -2)), Vector3(0, 0, -140.0 / 3.6))
	var air := 0
	var in_loop := 0
	var done := false
	var top_kmh := 0.0
	for i in 60 * 20:
		await get_tree().physics_frame
		var d := ai.get_distance()
		if path.in_zone(d, "loop"):
			in_loop += 1
			if not car.is_grounded():
				air += 1
			if car.global_transform.basis.y.y < -0.9:
				top_kmh = car.get_speed_kmh()
		if d > path.length - 20.0:
			done = true
			break
		if car.global_position.y < -30.0:
			break
	print("TM loop %s done=%s air=%d/%d top=%.0f km/h" % [id, done, air, in_loop, top_kmh])
	TestHooks.check(done, "tm_loop_completes_%s" % id)
	TestHooks.check(air <= 4, "tm_loop_grounded_%s" % id, "%d/%d" % [air, in_loop])
	await _done(car)
	road.queue_free()


## Off a 12 deg kicker at 200 km/h onto flat ground: lands on its wheels and keeps its speed.
func _landing(id: String) -> void:
	var o := Vector3(1200, 0, 0)
	var ramp := PhysicsTestGround.jump_ramp(12.0, 22.0, o + Vector3(0, 0, -150))
	add_child(ramp)
	var car := await _spawn(id, 200.0, o)
	var airborne := false
	var v_before := 0.0
	var v_after := 0.0
	var landed_tick := -1
	var max_tilt := 0.0
	for i in 60 * 8:
		_ctl(car, 0.0, 0.0, 0.0)
		await get_tree().physics_frame
		var hv := Vector2(car.linear_velocity.x, car.linear_velocity.z).length()
		if not airborne and not car.is_grounded() and car.global_position.y > 1.5:
			airborne = true
			v_before = hv
		elif airborne and landed_tick < 0 and car.is_grounded():
			landed_tick = i
		if landed_tick >= 0:
			max_tilt = maxf(max_tilt, _tilt_deg(car))
			if i == landed_tick + 20:
				v_after = hv
				break
	var keep := v_after / maxf(v_before, 0.1)
	print("TM landing %s airborne=%s keep=%.1f%% tilt_after=%.0f" % [id, airborne, keep * 100.0, max_tilt])
	TestHooks.check(airborne and landed_tick >= 0, "tm_landing_flew_and_landed_%s" % id)
	TestHooks.check(keep >= 0.95, "tm_landing_keeps_speed_%s" % id, "%.1f%%" % (keep * 100.0))
	TestHooks.check(max_tilt <= 15.0, "tm_landing_on_wheels_%s" % id, "%.0f" % max_tilt)
	await _done(car)
	ramp.queue_free()


## Fall from 30 m: effective gravity in the air (TM jumps are snappier than 1 g).
func _air(id: String) -> void:
	var car := await _spawn(id, 120.0, Vector3(6000, 30, 0))
	for i in 3:
		await get_tree().physics_frame
	var vy0 := car.linear_velocity.y
	for i in 30:
		_ctl(car, 0.0, 0.0, 0.0)
		await get_tree().physics_frame
	var g := -(car.linear_velocity.y - vy0) / 0.5
	print("TM air %s effective_gravity=%.1f m/s^2 (%.2f g)" % [id, g, g / 9.8])
	TestHooks.check(g >= 12.0 and g <= 18.0, "tm_air_gravity_%s" % id, "%.1f" % g)
	await _done(car)
