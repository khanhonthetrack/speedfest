extends Node3D
## Stunt test: AutoDriver through a vertical loop (r = 18 m) and over a kicker jump onto flat ground.
## Checks: loop completed upright and stuck to the road, jump lands upright without bouncing.
## Run headless:  tools/run_scene.sh res://tests/physics/test_stunts.tscn --headless -- --frames=2400
## Screenshot:    tools/run_scene.sh res://tests/physics/test_stunts.tscn -- --frames=2400 --shotdir=/abs/dir --car=veloce

var LOOP_R := 18.0

var car_id := "kaze"
var loop_path: TrackPath
var loop_car: Car
var loop_ai: AutoDriver
var loop_from := 0.0
var loop_to := 0.0
var loop_entry_kmh := -1.0
var loop_min_kmh := 1e9
var loop_ticks := 0
var loop_air_ticks := 0
var loop_done := false
var loop_top_shot := false

var jump_path: TrackPath
var jump_car: Car
var jump_ai: AutoDriver
var jump_ramp_z := -160.0
var jump_state := "approach"
var jump_max_air := 0.0
var jump_bounces := 0
var jump_min_up := 1.0
var jump_launch_kmh := 0.0
var jump_land_tick := -1
var jump_done := false
var jump_was_grounded := true
var jump_air_start := 0

var extra: Array = []   # [{name, car, ai, path, from, to, entry, min, air, ticks, done}]

var tick := 0
var cam: Camera3D
var shotdir := ""


func _ready() -> void:
	car_id = String(TestHooks.arg("car", "kaze"))
	shotdir = String(TestHooks.arg("shotdir", ""))
	LOOP_R = float(TestHooks.arg("r", 18.0))
	# loop at x = 0
	loop_path = PhysicsTestGround.loop_path(LOOP_R, 220.0, 160.0, 12.0)
	add_child(PhysicsTestGround.road_from_path(loop_path))
	loop_from = float(loop_path.zones[0]["from"])
	loop_to = float(loop_path.zones[0]["to"])
	loop_car = _spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, -2)))
	loop_ai = _driver(loop_car, loop_path)
	var specs := [["slow", -200.0, 143.0, false], ["fast", -400.0, 0.0, true]]
	if not bool(TestHooks.arg("fast", true)):
		specs.pop_back()   # r < 18 at 250+ km/h (> 30 g) is outside the supported envelope
	for spec in specs:
		var o := Vector3(spec[1], 0, 0)
		var lp := PhysicsTestGround.loop_path(LOOP_R, 260.0, 160.0, 12.0, o)
		add_child(PhysicsTestGround.road_from_path(lp))
		var ec := _spawn(Transform3D(Basis.IDENTITY, o + Vector3(0, 0.6, -2)))
		var eai := _driver(ec, lp)
		eai.target_speed_kmh = spec[2]
		eai.use_nitro = spec[3]
		extra.append({"name": spec[0], "car": ec, "ai": eai, "from": float(lp.zones[0]["from"]), "to": float(lp.zones[0]["to"]),
			"entry": -1.0, "min": 1e9, "air": 0, "ticks": 0, "done": false})
	# kicker jump at x = 400 on a flat pad
	var jo := Vector3(400, 0, 0)
	add_child(PhysicsTestGround.flat_pad(60, 800, jo + Vector3(0, 0, -380)))
	var ramp := PhysicsTestGround.jump_ramp(float(TestHooks.arg("jump_angle", 10.0)), 20.0, jo + Vector3(0, 0, jump_ramp_z))
	add_child(ramp)
	var c := Curve3D.new()
	c.add_point(jo + Vector3(0, 0, 0))
	c.add_point(jo + Vector3(0, 0, -750))
	jump_path = TrackPath.new(c, false, 14.0)
	jump_path.zones = [{"from": float(TestHooks.arg("jump_zone", 100.0)), "to": 260.0, "kind": "jump"}]
	jump_car = _spawn(Transform3D(Basis.IDENTITY, jo + Vector3(0, 0.6, -2)))
	jump_ai = _driver(jump_car, jump_path)
	jump_ai.use_nitro = bool(TestHooks.arg("jump_nitro", false))
	jump_ai.target_speed_kmh = float(TestHooks.arg("jump_cap", 0.0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.07, 0.15)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	cam = Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.current = true


func _spawn(xf: Transform3D) -> Car:
	var car := Car.create(PhysicsTestGround.test_config(car_id))
	add_child(car)
	car.teleport(xf)
	return car


func _driver(car: Car, path: TrackPath) -> AutoDriver:
	var ai := AutoDriver.new()
	ai.path = path
	ai.use_nitro = false
	car.add_child(ai)
	return ai


func _physics_process(_delta: float) -> void:
	tick += 1
	_check_loop()
	_check_jump()
	var extra_done := true
	for e in extra:
		_check_extra(e)
		extra_done = extra_done and e["done"]
	if loop_done and jump_done and extra_done:
		TestHooks.finish()
	elif tick > 60 * 40:
		TestHooks.fail("stunts_timeout", "loop_done=%s jump_done=%s" % [loop_done, jump_done])
		TestHooks.finish()


func _process(_delta: float) -> void:
	# side camera on the loop
	var target := loop_car.global_position
	cam.global_position = Vector3(target.x - 38.0, 14.0, clampf(target.z, -260, 0) + 4.0)
	cam.look_at(Vector3(target.x, maxf(target.y, 6.0), target.z), Vector3.UP)
	if shotdir != "" and not loop_top_shot and loop_car.global_position.y > LOOP_R * 1.6:
		loop_top_shot = true
		TestHooks.save_screenshot(shotdir.path_join("physics_loop_%s.png" % car_id))


func _check_loop() -> void:
	if loop_done:
		return
	if TestHooks.has_arg("lat") and tick % 6 == 0 and loop_ai.get_distance() > 205.0:
		var lt := loop_path.sample_transform(loop_ai.get_distance())
		var lc := lt.affine_inverse() * loop_car.global_position
		var cf := -loop_car.global_transform.basis.z
		var pf := -lt.basis.z
		var vd := loop_car.linear_velocity.normalized()
		print("  d=%.1f lat=%.2f h=%.2f v=%.0f st=%.2f wheel=%.1f gnd=%d head=%.1f vel=%.1f slip=%.1f load=%s" % [loop_ai.get_distance(), lc.x, lc.y, loop_car.get_speed_kmh(), loop_car.controls["steer"], rad_to_deg(loop_car.get_steer_angle()), int(loop_car.is_grounded()), rad_to_deg(atan2(cf.dot(lt.basis.x), cf.dot(pf))), rad_to_deg(atan2(vd.dot(lt.basis.x), vd.dot(pf))), rad_to_deg(loop_car.get_slip_angle()), loop_car._load])
	if TestHooks.has_arg("trace") and (tick % 20 == 0 or (TestHooks.has_arg("fine") and loop_ai.get_distance() > 200.0)):
		print("  t=%.2f d=%.1f pos=%s v=%.0f st=%.2f up=%s comp=%s load=%s av=%s" % [tick / 60.0, loop_ai.get_distance(), loop_car.global_position, loop_car.get_speed_kmh(), loop_car.controls["steer"], loop_car.global_transform.basis.y, loop_car._comp, loop_car._load, loop_car.angular_velocity])
	var d := loop_ai.get_distance()
	var prog := loop_ai.get_progress()
	if d >= loop_from and d <= loop_to:
		if loop_entry_kmh < 0.0:
			loop_entry_kmh = loop_car.get_speed_kmh()
		loop_ticks += 1
		loop_min_kmh = minf(loop_min_kmh, loop_car.get_speed_kmh())
		if not loop_car.is_grounded():
			loop_air_ticks += 1
			if TestHooks.has_arg("airtrace"):
				print("  air at d=%.1f y=%.1f comp=%s" % [d, loop_car.global_position.y, loop_car._comp])
	var up_y := loop_car.global_transform.basis.y.y
	if d > loop_to + 40.0:
		loop_done = true
		print("RESULT loop %s entry=%.0f km/h min=%.0f km/h air=%d/%d ticks up_y=%.2f" % [car_id, loop_entry_kmh, loop_min_kmh, loop_air_ticks, loop_ticks, up_y])
		TestHooks.check(loop_entry_kmh >= 140.0, "loop_entry_speed_%s" % car_id, "%.0f km/h" % loop_entry_kmh)
		TestHooks.check(loop_air_ticks < loop_ticks * 0.1, "loop_stays_grounded_%s" % car_id, "%d/%d air ticks" % [loop_air_ticks, loop_ticks])
		TestHooks.check(up_y > 0.9 and loop_car.is_grounded(), "loop_exit_upright_%s" % car_id, "up_y=%.2f" % up_y)
		TestHooks.check(absf(loop_ai.get_progress() - d) < 5.0, "loop_no_reset_%s" % car_id, "progress %.0f vs d %.0f" % [prog, d])
	elif tick > 60 * 35:
		loop_done = true
		TestHooks.fail("loop_complete_%s" % car_id, "d=%.0f (loop %.0f..%.0f) pos=%s" % [d, loop_from, loop_to, loop_car.global_position])


func _check_extra(e: Dictionary) -> void:
	if e["done"]:
		return
	var car: Car = e["car"]
	var ai: AutoDriver = e["ai"]
	var d := ai.get_distance()
	if d >= e["from"] and d <= e["to"]:
		if e["entry"] < 0.0:
			e["entry"] = car.get_speed_kmh()
			ai.target_speed_kmh = 0.0  # cap only for the entry
		e["ticks"] += 1
		e["min"] = minf(e["min"], car.get_speed_kmh())
		if not car.is_grounded():
			e["air"] += 1
	if d > float(e["to"]) + 40.0:
		e["done"] = true
		var n: String = e["name"]
		print("RESULT loop_%s %s entry=%.0f km/h min=%.0f km/h air=%d/%d up_y=%.2f" % [n, car_id, e["entry"], e["min"], e["air"], e["ticks"], car.global_transform.basis.y.y])
		TestHooks.check(e["air"] < e["ticks"] * 0.1 and car.global_transform.basis.y.y > 0.9, "loop_%s_%s" % [n, car_id], "air %d/%d" % [e["air"], e["ticks"]])
		if n == "slow":
			TestHooks.check(e["entry"] < 150.0, "loop_slow_entry_%s" % car_id, "%.0f km/h" % e["entry"])
	if TestHooks.has_arg("etrace") and e["name"] == "fast" and d > 250.0 and d < 400.0 and tick % 3 == 0:
		print("  E d=%.1f v=%.0f gnd=%d%d%d%d comp=%s load=%s up=%s" % [d, car.get_speed_kmh(), int(car.get_wheel_contact(0)), int(car.get_wheel_contact(1)), int(car.get_wheel_contact(2)), int(car.get_wheel_contact(3)), car._comp, car._load, car.global_transform.basis.y])
	elif tick > 60 * 35:
		e["done"] = true
		TestHooks.fail("loop_%s_complete_%s" % [e["name"], car_id], "d=%.0f pos=%s" % [d, car.global_position])


func _check_jump() -> void:
	if jump_done:
		return
	var z := jump_car.global_position.z
	var g := jump_car.is_grounded()
	var up_y := jump_car.global_transform.basis.y.y
	if TestHooks.has_arg("jtrace") and jump_state != "approach" and tick % 4 == 0:
		var bb := jump_car.global_transform.basis
		print("  t=%.2f %s y=%.2f vy=%.1f v=%.0f fwd.y=%.2f right.y=%.2f gnd=%d%d%d%d av=%s" % [tick / 60.0, jump_state, jump_car.global_position.y, jump_car.linear_velocity.y, jump_car.get_speed_kmh(), (-bb.z).y, bb.x.y, int(jump_car.get_wheel_contact(0)), int(jump_car.get_wheel_contact(1)), int(jump_car.get_wheel_contact(2)), int(jump_car.get_wheel_contact(3)), jump_car.angular_velocity])
	match jump_state:
		"approach":
			if z < jump_ramp_z + 2.0:
				jump_launch_kmh = jump_car.get_speed_kmh()
			if not g and z < jump_ramp_z - 15.0:
				jump_state = "air"
				jump_air_start = tick
		"air":
			jump_min_up = minf(jump_min_up, up_y)
			if g:
				jump_max_air = (tick - jump_air_start) / 60.0
				jump_state = "landed"
				jump_land_tick = tick
				jump_was_grounded = true
		"landed":
			jump_min_up = minf(jump_min_up, up_y)
			if jump_was_grounded and not g:
				jump_air_start = tick
			if not jump_was_grounded and g and tick - jump_air_start > 9:
				jump_bounces += 1
			jump_was_grounded = g
			if tick - jump_land_tick > 150:
				jump_done = true
				print("RESULT jump %s launch=%.0f km/h air=%.2fs bounces=%d min_up_y=%.2f speed_after=%.0f" % [car_id, jump_launch_kmh, jump_max_air, jump_bounces, jump_min_up, jump_car.get_speed_kmh()])
				TestHooks.check(jump_max_air > 0.6, "jump_airborne_%s" % car_id, "%.2f s" % jump_max_air)
				TestHooks.check(jump_min_up > 0.8, "jump_lands_upright_%s" % car_id, "min up_y %.2f" % jump_min_up)
				TestHooks.check(jump_bounces == 0, "jump_no_bounce_%s" % car_id, "%d bounces" % jump_bounces)
				TestHooks.check(jump_car.get_speed_kmh() > jump_launch_kmh * 0.7, "jump_keeps_speed_%s" % car_id, "%.0f" % jump_car.get_speed_kmh())
	if tick > 60 * 35 and not jump_done:
		jump_done = true
		TestHooks.fail("jump_complete_%s" % car_id, "state %s z=%.0f" % [jump_state, z])
